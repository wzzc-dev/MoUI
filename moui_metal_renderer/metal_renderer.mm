// Direct Metal renderer stubs — the no-Skia, no-wgpu presentation path
// (ADR 0044 L1, ADR 0045). Only Apple system frameworks are referenced here.
//
// Object ownership follows the repo's existing Metal convention
// (moui_skia/native/skia_stub_surface_image_data.cpp:99-129): the reference
// MTLCreateSystemDefaultDevice() returns is owned by the caller, is stored in
// MOUIMetalContext, and is released exactly once with the context. MoonBit
// holds the context handle and returns it through moui_metal_context_release.

#include <moonbit.h>
#include <stdint.h>
#include "metal_present_smoke.h"
#include <stdio.h>
#include <stdlib.h>

#if defined(__APPLE__)

#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#import "metal_shaders.h"

// Wire layout, mirroring `metal_geometry.mbt`: one vertex stream, an item row of
// 9 int32 (first, count, scissor rect, pipeline role, texture key, pass owner) —
// the texture key names an image record, a pass slot, or a glyph atlas page,
// depending on the role — one 36-float parameter blob per item, and one 11-word
// record per offscreen pass (device frame, child item range, blend code, then the
// pass transform).
static const NSUInteger kMouiMetalVertexStride = 76;
static const NSUInteger kMouiMetalItemInts = 9;
static const NSUInteger kMouiMetalShapeFloats = 36;
static const NSUInteger kMouiMetalLayerRecordInts = 11;
static const NSUInteger kMouiMetalAtlasSize = 1024;
// The ceiling on coverage pages, matching `METAL_ATLAS_MAX_PAGES` in
// `metal_text.mbt`. A text item's texture key is a page index, so this is also
// the largest key the host will bind.
static const int32_t kMouiMetalMaxAtlasPages = 4;

// Pipeline roles, matching the `metal_pipeline_*` constants in `metal_geometry.mbt`.
static const int32_t kMouiMetalRoleVisual = 0;
static const int32_t kMouiMetalRoleText = 1;
static const int32_t kMouiMetalRoleImage = 2;
static const int32_t kMouiMetalRoleComposite = 3;

// Blend code, matching `metal_blend_source_over`. Only a composite carries a
// blend mode; every other role draws source-over.
static const int32_t kMouiMetalBlendSourceOver = 0;

// The stream one render encoder draws: the presentation pass (`owner` -1, the
// whole surface) or one offscreen layer slot.
struct MOUIMetalPass {
  int32_t owner;
  int32_t origin_x;
  int32_t origin_y;
  int32_t width;
  int32_t height;
  int32_t first;
  int32_t count;
  float transform[4];
};

// The buffers `metal_geometry.mbt` handed over for this frame, already counted
// into items and pass records.
struct MOUIMetalPayload {
  const uint8_t *vertices;
  int32_t vertex_bytes;
  const int32_t *items;
  int32_t item_count;
  const float *shapes;
  int32_t shape_bytes;
  const int32_t *layers;
  int32_t layer_count;
};

// A fixed-size record array is counted from its byte length here, at the boundary
// the MoonBit caller controls.
static int32_t moui_metal_count(int32_t bytes, NSUInteger words) {
  if (bytes <= 0) {
    return 0;
  }
  return (int32_t)((NSUInteger)bytes / (words * sizeof(int32_t)));
}

// One offscreen layer target, kept between frames and reused while its size
// still matches the pass it serves.
@interface MOUIMetalPassTarget : NSObject {
 @public
  id<MTLTexture> texture;
  int32_t width;
  int32_t height;
}
@end

@implementation MOUIMetalPassTarget
- (void)dealloc {
  if (texture != nil) {
    [texture release];
    texture = nil;
  }
  [super dealloc];
}
@end

@interface MOUIMetalContext : NSObject {
 @public
  id<MTLDevice> device;
  id<MTLCommandQueue> queue;
  id<MTLLibrary> library;
  NSMutableArray *atlas_pages;
  id<MTLSamplerState> sampler;
  id<MTLSamplerState> image_sampler;
  NSMutableDictionary *images;
  // Keyed by "role-format[-blend]" because a layer target is RGBA8 while the
  // window is BGRA8, and a pipeline may only render to the format it was built
  // for.
  NSMutableDictionary *pipelines;
  NSMutableArray *pass_targets;
}
@end

@implementation MOUIMetalContext
- (void)dealloc {
  if (pass_targets != nil) {
    [pass_targets release];
    pass_targets = nil;
  }
  if (pipelines != nil) {
    [pipelines release];
    pipelines = nil;
  }
  if (images != nil) {
    [images release];
    images = nil;
  }
  if (image_sampler != nil) {
    [image_sampler release];
    image_sampler = nil;
  }
  if (library != nil) {
    [library release];
    library = nil;
  }
  if (atlas_pages != nil) {
    [atlas_pages release];
    atlas_pages = nil;
  }
  if (sampler != nil) {
    [sampler release];
    sampler = nil;
  }
  if (queue != nil) {
    [queue release];
    queue = nil;
  }
  if (device != nil) {
    [device release];
    device = nil;
  }
  [super dealloc];
}
@end

static MOUIMetalContext *moui_metal_context_from_handle(uint64_t handle) {
  return handle == 0 ? nil : (MOUIMetalContext *)(uintptr_t)handle;
}

static CAMetalLayer *moui_metal_layer_from_handle(uint64_t handle) {
  return handle == 0 ? nil : (CAMetalLayer *)(uintptr_t)handle;
}

// The blend state a layer composite needs. Metal's fixed-function factors are
// exact for these five over an opaque destination; over an empty one a
// backdrop-sampling renderer falls back to source-over while these pull toward
// black, which is why the CPU side counts every non-source-over composite as
// `blend_modes_approximated`. `@core.Overlay` needs the destination as an input
// to the colour, so no factor pair expresses it at all and the CPU side drops it
// into `blend_modes_unsupported` instead of drawing a guess here.
static void moui_metal_apply_blend(
    MTLRenderPipelineColorAttachmentDescriptor *attachment,
    int32_t blend) {
  attachment.blendingEnabled = YES;
  attachment.rgbBlendOperation = MTLBlendOperationAdd;
  attachment.alphaBlendOperation = MTLBlendOperationAdd;
  attachment.sourceRGBBlendFactor = MTLBlendFactorOne;
  attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  attachment.sourceAlphaBlendFactor = MTLBlendFactorOne;
  attachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
  switch (blend) {
  case 1: // Multiply
    attachment.sourceRGBBlendFactor = MTLBlendFactorDestinationColor;
    attachment.destinationRGBBlendFactor = MTLBlendFactorZero;
    attachment.sourceAlphaBlendFactor = MTLBlendFactorZero;
    attachment.destinationAlphaBlendFactor = MTLBlendFactorOne;
    break;
  case 2: // Screen
    attachment.sourceRGBBlendFactor = MTLBlendFactorOneMinusDestinationColor;
    attachment.destinationRGBBlendFactor = MTLBlendFactorOne;
    attachment.sourceAlphaBlendFactor = MTLBlendFactorZero;
    attachment.destinationAlphaBlendFactor = MTLBlendFactorOne;
    break;
  case 4: // Darken
  case 5: // Lighten
    // Min/Max ignore the factors and compare the two premultiplied colours, which
    // is the definition of these two modes; the alpha channel stays source-over.
    attachment.rgbBlendOperation =
        blend == 4 ? MTLBlendOperationMin : MTLBlendOperationMax;
    attachment.sourceRGBBlendFactor = MTLBlendFactorOne;
    attachment.destinationRGBBlendFactor = MTLBlendFactorOne;
    break;
  default:
    break;
  }
}

static id<MTLLibrary> moui_metal_library(MOUIMetalContext *context) {
  if (context->library != nil) {
    return context->library;
  }
  NSError *error = nil;
  NSString *source = [NSString stringWithUTF8String:kMouiMetalShaderSource];
  context->library = [context->device newLibraryWithSource:source
                                                  options:nil
                                                    error:&error];
  if (context->library == nil) {
    fprintf(stderr, "[moui_metal] metal shader compile failed: %s\n",
            error == nil ? "unknown" : [[error localizedDescription] UTF8String]);
  }
  return context->library;
}

static id<MTLRenderPipelineState> moui_metal_make_pipeline(
    MOUIMetalContext *context,
    MTLPixelFormat format,
    NSString *fragment_name,
    int32_t blend) {
  NSError *error = nil;
  id<MTLLibrary> library = moui_metal_library(context);
  if (library == nil) {
    return nil;
  }
  id<MTLFunction> vertex = [library newFunctionWithName:@"moui_metal_vertex"];
  id<MTLFunction> fragment = [library newFunctionWithName:fragment_name];
  if (vertex == nil || fragment == nil) {
    [vertex release];
    [fragment release];
    return nil;
  }
  MTLRenderPipelineDescriptor *descriptor =
      [[[MTLRenderPipelineDescriptor alloc] init] autorelease];
  descriptor.vertexFunction = vertex;
  descriptor.fragmentFunction = fragment;
  descriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
  // Culling stays at the pipeline default (none): the shared tessellator emits
  // triangle lists whose winding is not a contract this renderer may rely on.
  [vertex release];
  [fragment release];

  MTLVertexDescriptor *vertices = [MTLVertexDescriptor vertexDescriptor];
  // Layout: position, local, uv, start, end (float2), colour pair (float4),
  // brush kind (float). Colours ride per vertex because the shared path mesh
  // mixes a fill brush and a stroke brush inside one item.
  vertices.attributes[0].format = MTLVertexFormatFloat2;
  vertices.attributes[0].offset = 0;
  vertices.attributes[0].bufferIndex = 0;
  vertices.attributes[1].format = MTLVertexFormatFloat2;
  vertices.attributes[1].offset = 8;
  vertices.attributes[1].bufferIndex = 0;
  vertices.attributes[2].format = MTLVertexFormatFloat2;
  vertices.attributes[2].offset = 16;
  vertices.attributes[2].bufferIndex = 0;
  vertices.attributes[3].format = MTLVertexFormatFloat2;
  vertices.attributes[3].offset = 24;
  vertices.attributes[3].bufferIndex = 0;
  vertices.attributes[4].format = MTLVertexFormatFloat2;
  vertices.attributes[4].offset = 32;
  vertices.attributes[4].bufferIndex = 0;
  vertices.attributes[5].format = MTLVertexFormatFloat4;
  vertices.attributes[5].offset = 40;
  vertices.attributes[5].bufferIndex = 0;
  vertices.attributes[6].format = MTLVertexFormatFloat4;
  vertices.attributes[6].offset = 56;
  vertices.attributes[6].bufferIndex = 0;
  vertices.attributes[7].format = MTLVertexFormatFloat;
  vertices.attributes[7].offset = 72;
  vertices.attributes[7].bufferIndex = 0;
  vertices.layouts[0].stride = kMouiMetalVertexStride;
  vertices.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
  descriptor.vertexDescriptor = vertices;

  MTLRenderPipelineColorAttachmentDescriptor *attachment =
      descriptor.colorAttachments[0];
  attachment.pixelFormat = format;
  moui_metal_apply_blend(attachment, blend);

  id<MTLRenderPipelineState> pipeline =
      [context->device newRenderPipelineStateWithDescriptor:descriptor
                                                      error:&error];
  if (pipeline == nil) {
    fprintf(stderr, "[moui_metal] metal render pipeline failed: %s\n",
            error == nil ? "unknown" : [[error localizedDescription] UTF8String]);
  }
  return pipeline;
}

// The glyph samplers and the atlas page array. The atlas format is independent of
// the colour attachment format, so an offscreen proof pass and a BGRA8 window
// share one upload. The page textures are created by `moui_metal_texture_write`:
// a page only exists once the MoonBit side has packed glyphs into it, and an
// app that never renders a dense frame never allocates the second one.
static void moui_metal_ensure_samplers(MOUIMetalContext *context) {
  if (context->atlas_pages == nil) {
    context->atlas_pages = [[NSMutableArray alloc] init];
  }
  if (context->sampler == nil) {
    MTLSamplerDescriptor *sample = [[[MTLSamplerDescriptor alloc] init] autorelease];
    sample.minFilter = MTLSamplerMinMagFilterNearest;
    sample.magFilter = MTLSamplerMinMagFilterNearest;
    sample.sAddressMode = MTLSamplerAddressModeClampToEdge;
    sample.tAddressMode = MTLSamplerAddressModeClampToEdge;
    context->sampler = [context->device newSamplerStateWithDescriptor:sample];
  }
  if (context->image_sampler == nil) {
    MTLSamplerDescriptor *smooth = [[[MTLSamplerDescriptor alloc] init] autorelease];
    smooth.minFilter = MTLSamplerMinMagFilterLinear;
    smooth.magFilter = MTLSamplerMinMagFilterLinear;
    smooth.sAddressMode = MTLSamplerAddressModeClampToEdge;
    smooth.tAddressMode = MTLSamplerAddressModeClampToEdge;
    context->image_sampler = [context->device newSamplerStateWithDescriptor:smooth];
  }
}

// The coverage page a text item names, or nil when the index is outside the
// pages this context has uploaded. A key past `kMouiMetalMaxAtlasPages` is a wire
// bug, and skipping the draw is what keeps it a missing glyph rather than a
// sample of whatever texture happened to sit at that index.
static id<MTLTexture> moui_metal_atlas_page(MOUIMetalContext *context,
                                            int32_t page) {
  if (context->atlas_pages == nil || page < 0 ||
      (NSUInteger)page >= [context->atlas_pages count]) {
    return nil;
  }
  return [context->atlas_pages objectAtIndex:(NSUInteger)page];
}

// A pipeline for one (role, destination format, blend) triple, built on first use
// and owned by the context from then on. `NSNull` records a creation failure so a
// format the device will not build is not retried every frame.
static id<MTLRenderPipelineState> moui_metal_pipeline(MOUIMetalContext *context,
                                                      MTLPixelFormat format,
                                                      int32_t role,
                                                      int32_t blend) {
  if (context->pipelines == nil) {
    context->pipelines = [[NSMutableDictionary alloc] init];
  }
  NSString *key = role == kMouiMetalRoleComposite &&
          blend != kMouiMetalBlendSourceOver
      ? [NSString stringWithFormat:@"%d-%d-%lu", (int)role, (int)blend,
                                     (unsigned long)format]
      : [NSString stringWithFormat:@"%d-%lu", (int)role, (unsigned long)format];
  id cached = [context->pipelines objectForKey:key];
  if (cached != nil) {
    return cached == [NSNull null] ? nil : cached;
  }
  NSString *fragment = @"moui_metal_visual_fragment";
  if (role == kMouiMetalRoleText) {
    fragment = @"moui_metal_text_fragment";
  } else if (role == kMouiMetalRoleImage) {
    fragment = @"moui_metal_image_fragment";
  } else if (role == kMouiMetalRoleComposite) {
    fragment = @"moui_metal_composite_fragment";
  }
  id<MTLRenderPipelineState> pipeline =
      moui_metal_make_pipeline(context, format, fragment, blend);
  [context->pipelines
      setObject:pipeline == nil ? (id)[NSNull null] : (id)pipeline
         forKey:key];
  if (pipeline != nil) {
    [pipeline release];
  }
  return pipeline;
}

// The three roles every frame can reach. Composite pipelines are built per blend
// code on demand because an app that never sets a layer blend mode should not pay
// for five of them.
static void moui_metal_ensure_pipelines(MOUIMetalContext *context,
                                        MTLPixelFormat format) {
  moui_metal_ensure_samplers(context);
  moui_metal_pipeline(context, format, kMouiMetalRoleVisual,
                      kMouiMetalBlendSourceOver);
  moui_metal_pipeline(context, format, kMouiMetalRoleText,
                      kMouiMetalBlendSourceOver);
  moui_metal_pipeline(context, format, kMouiMetalRoleImage,
                      kMouiMetalBlendSourceOver);
}

// One offscreen target for a pass slot, reused across frames while its size still
// matches the pass it serves.
static MOUIMetalPassTarget *moui_metal_pass_target(MOUIMetalContext *context,
                                                   int32_t slot,
                                                   int32_t width,
                                                   int32_t height) {
  if (slot < 0 || width <= 0 || height <= 0) {
    return nil;
  }
  if (context->pass_targets == nil) {
    context->pass_targets = [[NSMutableArray alloc] init];
  }
  while ((NSInteger)context->pass_targets.count <= (NSInteger)slot) {
    [context->pass_targets
        addObject:[[[MOUIMetalPassTarget alloc] init] autorelease]];
  }
  MOUIMetalPassTarget *target = [context->pass_targets objectAtIndex:slot];
  if (target->texture != nil && target->width == width &&
      target->height == height) {
    return target;
  }
  if (target->texture != nil) {
    [target->texture release];
    target->texture = nil;
  }
  target->width = width;
  target->height = height;
  MTLTextureDescriptor *descriptor =
      [MTLTextureDescriptor
          texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                       width:(NSUInteger)width
                                      height:(NSUInteger)height
                                   mipmapped:NO];
  // The pass writes this texture and the composite that draws it back reads it,
  // so one texture has to serve both roles.
  descriptor.usage =
      MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
  target->texture = [context->device newTextureWithDescriptor:descriptor];
  if (target->texture == nil) {
    target->width = 0;
    target->height = 0;
    return nil;
  }
  return target;
}

// The target a composite samples, looked up by the pass slot its item carries.
static MOUIMetalPassTarget *moui_metal_layer_target(MOUIMetalContext *context,
                                                    int32_t slot,
                                                    MOUIMetalPayload payload) {
  if (payload.layers == NULL || slot < 0 || slot >= payload.layer_count) {
    return nil;
  }
  const int32_t *record = payload.layers + slot * (int32_t)kMouiMetalLayerRecordInts;
  return moui_metal_pass_target(context, slot, record[2], record[3]);
}

static MTLRenderPassDescriptor *moui_metal_pass(id<MTLTexture> texture,
                                                double red,
                                                double green,
                                                double blue,
                                                double alpha) {
  MTLRenderPassDescriptor *pass =
      [MTLRenderPassDescriptor renderPassDescriptor];
  pass.colorAttachments[0].texture = texture;
  pass.colorAttachments[0].loadAction = MTLLoadActionClear;
  pass.colorAttachments[0].storeAction = MTLStoreActionStore;
  pass.colorAttachments[0].clearColor =
      MTLClearColorMake(red, green, blue, alpha);
  return pass;
}

// One offscreen pass from its record: the target's own pixel frame, the item
// range built for it, and the transform that maps the surface's NDC into it.
// Children keep the coordinates they were built with, which is what lets a single
// vertex stream serve every pass.
static MOUIMetalPass moui_metal_slot_pass(int32_t slot,
                                          const int32_t *record) {
  const float *transform = (const float *)(record + 7);
  MOUIMetalPass pass;
  pass.owner = slot;
  pass.origin_x = record[0];
  pass.origin_y = record[1];
  pass.width = record[2];
  pass.height = record[3];
  pass.first = record[4];
  pass.count = record[5];
  pass.transform[0] = transform[0];
  pass.transform[1] = transform[1];
  pass.transform[2] = transform[2];
  pass.transform[3] = transform[3];
  return pass;
}

// Encode one pass: every item this pass owns, each as its own scissored range.
// The whole vertex stream rides in one buffer and the per-item parameters in one
// more, so an item is (first, count, rect, role, texture key, owner) plus
// shapes[item].
static void moui_metal_encode(MOUIMetalContext *context,
                              id<MTLRenderCommandEncoder> encoder,
                              MTLPixelFormat format,
                              MOUIMetalPass pass,
                              MOUIMetalPayload payload) {
  if (payload.vertices == NULL || payload.vertex_bytes <= 0 ||
      payload.items == NULL || payload.item_count <= 0) {
    return;
  }
  const NSUInteger shape_stride = kMouiMetalShapeFloats * sizeof(float);
  if (payload.shapes == NULL || (NSUInteger)payload.shape_bytes <
                                    (NSUInteger)payload.item_count * shape_stride) {
    return;
  }
  id<MTLBuffer> buffer = [context->device
      newBufferWithBytes:payload.vertices
                  length:(NSUInteger)payload.vertex_bytes
                 options:MTLResourceStorageModeShared];
  if (buffer == nil) {
    return;
  }
  [encoder setVertexBuffer:buffer offset:0 atIndex:0];
  [encoder setVertexBytes:pass.transform
                   length:sizeof(pass.transform)
                  atIndex:1];
  int32_t last = pass.first + pass.count;
  if (last > payload.item_count) {
    last = payload.item_count;
  }
  id<MTLRenderPipelineState> bound = nil;
  for (int32_t index = pass.first; index < last; index++) {
    const int32_t *item = payload.items + (index * (int32_t)kMouiMetalItemInts);
    // Items of nested passes and of passes this route dropped are interleaved
    // here, so ownership -- not position -- is what decides whether this pass
    // draws an item.
    if (item[8] != pass.owner || item[1] <= 0) {
      continue;
    }
    const int32_t role = item[6];
    int32_t blend = kMouiMetalBlendSourceOver;
    id<MTLTexture> texture = nil;
    id<MTLSamplerState> sampler = nil;
    if (role == kMouiMetalRoleText) {
      texture = moui_metal_atlas_page(context, item[7]);
      sampler = context->sampler;
    } else if (role == kMouiMetalRoleImage) {
      texture = [context->images objectForKey:[NSNumber numberWithInt:item[7]]];
      sampler = context->image_sampler;
    } else if (role == kMouiMetalRoleComposite) {
      MOUIMetalPassTarget *target =
          moui_metal_layer_target(context, item[7], payload);
      if (target == nil) {
        continue;
      }
      texture = target->texture;
      sampler = context->image_sampler;
      blend = payload.layers[item[7] * (int32_t)kMouiMetalLayerRecordInts + 6];
    }
    if (role != kMouiMetalRoleVisual && texture == nil) {
      continue;
    }
    id<MTLRenderPipelineState> pipeline =
        moui_metal_pipeline(context, format, role, blend);
    if (pipeline == nil) {
      continue;
    }
    if (pipeline != bound) {
      [encoder setRenderPipelineState:pipeline];
      bound = pipeline;
    }
    [encoder setFragmentBytes:payload.shapes +
                              (index * (int32_t)kMouiMetalShapeFloats)
                       length:shape_stride
                      atIndex:0];
    if (texture != nil) {
      [encoder setFragmentTexture:texture atIndex:0];
      [encoder setFragmentSamplerState:sampler atIndex:0];
    }
    // Scissors arrive in surface device pixels. A layer pass works in its own
    // target, so shift by its origin and clip away whatever leaves it.
    int32_t x = item[2] - pass.origin_x;
    int32_t y = item[3] - pass.origin_y;
    int32_t width = item[4];
    int32_t height = item[5];
    if (x < 0) {
      width += x;
      x = 0;
    }
    if (y < 0) {
      height += y;
      y = 0;
    }
    if (width > pass.width - x) {
      width = pass.width - x;
    }
    if (height > pass.height - y) {
      height = pass.height - y;
    }
    if (width <= 0 || height <= 0) {
      continue;
    }
    MTLScissorRect scissor = {(NSUInteger)x, (NSUInteger)y,
                              (NSUInteger)width, (NSUInteger)height};
    [encoder setScissorRect:scissor];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle
                vertexStart:(NSInteger)item[0]
                vertexCount:(NSInteger)item[1]
              instanceCount:1];
  }
  [buffer release];
}

// Render the offscreen passes before the pass that samples them. Slots are claimed
// parent-after-child, so walking them in descending order means a composite always
// reads a target its own pass has already drawn, and one command buffer keeps the
// single active render encoder Metal requires.
static void moui_metal_render_slots(MOUIMetalContext *context,
                                    id<MTLCommandBuffer> buffer,
                                    MOUIMetalPayload payload) {
  for (int32_t slot = payload.layer_count - 1; slot >= 0; slot--) {
    const int32_t *record =
        payload.layers + (slot * (int32_t)kMouiMetalLayerRecordInts);
    // A record with no children is a cached repaint boundary. The pool still
    // holds the texture the previous frame painted into this slot, and opening an
    // encoder here would clear exactly the pixels the composite is about to
    // sample. An empty group never reaches this branch: the CPU side releases the
    // slot when its children produce nothing, so a childless record is only ever
    // the cache.
    if (record[5] == 0) {
      continue;
    }
    MOUIMetalPassTarget *target =
        moui_metal_pass_target(context, slot, record[2], record[3]);
    if (target == nil) {
      continue;
    }
    // A layer group starts from empty; the frame's clear colour stays out of it,
    // because the composite blends against what is in the group.
    id<MTLRenderCommandEncoder> encoder =
        [buffer renderCommandEncoderWithDescriptor:
                    moui_metal_pass(target->texture, 0.0, 0.0, 0.0, 0.0)];
    if (encoder == nil) {
      continue;
    }
    moui_metal_encode(context, encoder, MTLPixelFormatRGBA8Unorm,
                      moui_metal_slot_pass(slot, record), payload);
    [encoder endEncoding];
  }
}

extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_metal_context_create(void) {
  @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
      return 0;
    }
    id<MTLCommandQueue> queue = [device newCommandQueue];
    if (queue == nil) {
      [device release];
      return 0;
    }
    MOUIMetalContext *context = [[MOUIMetalContext alloc] init];
    context->device = device;
    context->queue = queue;
    return (uint64_t)(uintptr_t)context;
  }
}

// Claim the presentation configuration of the host layer and build the
// pipelines for its pixel format. The host owns the layer and its drawable size.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_context_prepare(uint64_t context_handle,
                                   uint64_t layer_handle) {
  @autoreleasepool {
    MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
    CAMetalLayer *layer = moui_metal_layer_from_handle(layer_handle);
    if (context == nil || layer == nil || context->queue == nil) {
      return 0;
    }
    layer.device = context->device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    // Reading a presented drawable back requires a non-framebuffer-only layer, which
    // costs bandwidth on every frame, so the layer is built that way only while the
    // presentation smoke asks for it.
    layer.framebufferOnly = moui_metal_present_smoke_enabled() ? NO : YES;
    if (layer.device != context->device) {
      return 0;
    }
    moui_metal_ensure_pipelines(context, layer.pixelFormat);
    return moui_metal_pipeline(context, layer.pixelFormat, kMouiMetalRoleVisual,
                               kMouiMetalBlendSourceOver) != nil &&
                   moui_metal_pipeline(context, layer.pixelFormat,
                                       kMouiMetalRoleText,
                                       kMouiMetalBlendSourceOver) != nil
               ? 1
               : 0;
  }
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_texture_write(uint64_t context_handle,
                                 int32_t page,
                                 const uint8_t *pixels,
                                 int32_t pixel_bytes) {
  @autoreleasepool {
    MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
    if (context == nil || pixels == NULL || page < 0 ||
        page >= kMouiMetalMaxAtlasPages) {
      return 0;
    }
    moui_metal_ensure_samplers(context);
    // Exact match, not a floor: the MoonBit page buffer and this texture are
    // sized by two constants in two languages, and a caller that is *larger*
    // than the texture would otherwise upload the prefix of its buffer and
    // sample the rest as garbage. A drift now fails the text smoke's ink
    // assertion instead of mis-rendering quietly.
    if ((NSUInteger)pixel_bytes !=
        kMouiMetalAtlasSize * kMouiMetalAtlasSize * 4) {
      return 0;
    }
    // Pages are created in index order and kept for the life of the context: a
    // cleared MoonBit atlas drops its staging buffer but not this texture, so a
    // document that keeps crossing the cap does not rebuild 4 MB every frame.
    while ((int32_t)[context->atlas_pages count] <= page) {
      MTLTextureDescriptor *descriptor = [MTLTextureDescriptor
          texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                       width:kMouiMetalAtlasSize
                                      height:kMouiMetalAtlasSize
                                   mipmapped:NO];
      descriptor.usage = MTLTextureUsageShaderRead;
      id<MTLTexture> texture = [context->device newTextureWithDescriptor:descriptor];
      if (texture == nil) {
        return 0;
      }
      [context->atlas_pages addObject:texture];
      [texture release];
    }
    id<MTLTexture> target = [context->atlas_pages objectAtIndex:(NSUInteger)page];
    MTLRegion region =
        MTLRegionMake2D(0, 0, kMouiMetalAtlasSize, kMouiMetalAtlasSize);
    [target replaceRegion:region
              mipmapLevel:0
                withBytes:pixels
              bytesPerRow:kMouiMetalAtlasSize * 4];
    return 1;
  }
}

// Decode an encoded image (PNG/JPEG/whatever ImageIO accepts) with Apple's own
// stack and hand back premultiplied RGBA8. No third-party codec: the boundary
// ADR 0044 drew keeps ImageIO on the allowed side.
//
// Returns 1 on success, 2 when `out_pixels` is too small (the caller retries
// with the exact size reported through `out_size`), 0 when the bytes do not
// decode. `out_size` receives width then height as two int32.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_image_decode(const uint8_t *bytes,
                                int32_t byte_len,
                                uint8_t *out_pixels,
                                int32_t out_capacity,
                                int32_t *out_size) {
  @autoreleasepool {
    if (bytes == NULL || byte_len <= 0 || out_size == NULL) {
      return 0;
    }
    NSData *data = [NSData dataWithBytes:bytes length:(NSUInteger)byte_len];
    CGImageSourceRef source =
        CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (source == NULL) {
      return 0;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (image == NULL) {
      return 0;
    }
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    if (width == 0 || height == 0) {
      CGImageRelease(image);
      return 0;
    }
    out_size[0] = (int32_t)width;
    out_size[1] = (int32_t)height;
    size_t needed = width * height * 4;
    if (out_pixels == NULL || (size_t)out_capacity < needed) {
      CGImageRelease(image);
      return 2;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(
        out_pixels, width, height, 8, width * 4, space,
        // ByteOrder32Big forces memory order R,G,B,A. Without it, a
        // little-endian bitmap is BGRA and would read swapped through
        // MTLPixelFormatRGBA8Unorm.
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (bitmap == NULL) {
      CGImageRelease(image);
      return 0;
    }
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image);
    CGContextRelease(bitmap);
    CGImageRelease(image);
    return 1;
  }
}

// Install decoded RGBA8 as the texture an `ImageRun` samples, keyed by the id
// MoonBit assigned to its source string.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_image_write_rgba(uint64_t context_handle,
                                    int32_t key,
                                    int32_t width,
                                    int32_t height,
                                    int32_t row_bytes,
                                    const uint8_t *pixels,
                                    int32_t pixel_bytes) {
  @autoreleasepool {
    MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
    if (context == nil || pixels == NULL || width <= 0 || height <= 0 ||
        row_bytes < width * 4 ||
        (NSUInteger)pixel_bytes <
            (NSUInteger)row_bytes * (NSUInteger)height) {
      return 0;
    }
    if (context->images == nil) {
      context->images = [[NSMutableDictionary alloc] init];
    }
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                          width:(NSUInteger)width
                                                         height:(NSUInteger)height
                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> texture = [context->device newTextureWithDescriptor:descriptor];
    if (texture == nil) {
      return 0;
    }
    [texture replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)width,
                                                    (NSUInteger)height)
               mipmapLevel:0
                 withBytes:pixels
               bytesPerRow:(NSUInteger)row_bytes];
    NSNumber *lookup = [NSNumber numberWithInt:key];
    [context->images setObject:texture forKey:lookup];
    [texture release];
    return 1;
  }
}

// Drop one installed image texture. The renderer budgets its own decoded-image
// residency and calls this when a source it installed earlier has to leave; the
// next frame no longer finds a key for it, re-requests the source through the
// shared lifecycle, and installs a fresh texture under a new key.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_image_release(uint64_t context_handle, int32_t key) {
  @autoreleasepool {
    MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
    if (context == nil || context->images == nil) {
      return 0;
    }
    NSNumber *lookup = [NSNumber numberWithInt:key];
    if ([context->images objectForKey:lookup] == nil) {
      return 0;
    }
    [context->images removeObjectForKey:lookup];
    return 1;
  }
}

// Presentation pass: the layer passes first, then the main pass that composites
// them onto the drawable. One command buffer holds all of them because Metal
// allows only one active render encoder at a time.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_draw_frame(uint64_t context_handle,
                              uint64_t layer_handle,
                              double red,
                              double green,
                              double blue,
                              double alpha,
                              const uint8_t *vertices,
                              int32_t vertex_bytes,
                              const int32_t *items,
                              int32_t item_bytes,
                              const float *shapes,
                              int32_t shape_bytes,
                              const int32_t *layers,
                              int32_t layer_bytes) {
  @autoreleasepool {
    MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
    CAMetalLayer *layer = moui_metal_layer_from_handle(layer_handle);
    if (context == nil || layer == nil || context->queue == nil) {
      return 0;
    }
    moui_metal_ensure_pipelines(context, layer.pixelFormat);
    if (moui_metal_pipeline(context, layer.pixelFormat, kMouiMetalRoleVisual,
                            kMouiMetalBlendSourceOver) == nil) {
      return 0;
    }
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    if (drawable == nil) {
      return 0;
    }
    id<MTLCommandBuffer> buffer = [context->queue commandBuffer];
    if (buffer == nil) {
      return 0;
    }
    MOUIMetalPayload payload = {
        vertices,
        vertex_bytes,
        items,
        moui_metal_count(item_bytes, kMouiMetalItemInts),
        shapes,
        shape_bytes,
        layers,
        moui_metal_count(layer_bytes, kMouiMetalLayerRecordInts)};
    moui_metal_render_slots(context, buffer, payload);
    MOUIMetalPass main = {
        -1, 0, 0, (int32_t)drawable.texture.width,
        (int32_t)drawable.texture.height, 0, payload.item_count,
        {1.0f, 1.0f, 0.0f, 0.0f}};
    id<MTLRenderCommandEncoder> encoder = [buffer
        renderCommandEncoderWithDescriptor:
            moui_metal_pass(drawable.texture, red, green, blue, alpha)];
    if (encoder == nil) {
      return 0;
    }
    moui_metal_encode(context, encoder, layer.pixelFormat, main, payload);
    [encoder endEncoding];
    moui_metal_present_smoke_draw(buffer, drawable, context->device, red, green,
                                  blue, alpha);
    return 1;
  }
}

// Offscreen proof pass for tests and smoke gates: render into a host-readable
// texture and copy the pixels back. No presentation path calls it.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_draw_proof(uint64_t context_handle,
                              int32_t width,
                              int32_t height,
                              double red,
                              double green,
                              double blue,
                              double alpha,
                              const uint8_t *vertices,
                              int32_t vertex_bytes,
                              const int32_t *items,
                              int32_t item_bytes,
                              const float *shapes,
                              int32_t shape_bytes,
                              const int32_t *layers,
                              int32_t layer_bytes,
                              uint8_t *output,
                              int32_t output_bytes) {
  @autoreleasepool {
    MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
    if (context == nil || output == NULL || width <= 0 || height <= 0 ||
        (NSUInteger)output_bytes <
            (NSUInteger)width * (NSUInteger)height * (NSUInteger)4) {
      return 0;
    }
    // A proof pass runs without a host layer, so it builds its pipelines and
    // its atlas against the format it reads back from.
    moui_metal_ensure_pipelines(context, MTLPixelFormatRGBA8Unorm);
    if (moui_metal_pipeline(context, MTLPixelFormatRGBA8Unorm,
                            kMouiMetalRoleVisual,
                            kMouiMetalBlendSourceOver) == nil) {
      return 0;
    }
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                         width:(NSUInteger)width
                                        height:(NSUInteger)height
                                     mipmapped:NO];
    // Metal textures are host-readable without an explicit usage flag; see
    // MTLTextureUsage in MTLTexture.h.
    descriptor.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> texture = [context->device newTextureWithDescriptor:descriptor];
    if (texture == nil) {
      return 0;
    }
    id<MTLCommandBuffer> buffer = [context->queue commandBuffer];
    if (buffer == nil) {
      [texture release];
      return 0;
    }
    MOUIMetalPayload payload = {
        vertices,
        vertex_bytes,
        items,
        moui_metal_count(item_bytes, kMouiMetalItemInts),
        shapes,
        shape_bytes,
        layers,
        moui_metal_count(layer_bytes, kMouiMetalLayerRecordInts)};
    moui_metal_render_slots(context, buffer, payload);
    MOUIMetalPass main = {
        -1, 0, 0, width, height, 0, payload.item_count,
        {1.0f, 1.0f, 0.0f, 0.0f}};
    id<MTLRenderCommandEncoder> encoder = [buffer
        renderCommandEncoderWithDescriptor:
            moui_metal_pass(texture, red, green, blue, alpha)];
    if (encoder == nil) {
      [texture release];
      return 0;
    }
    moui_metal_encode(context, encoder, MTLPixelFormatRGBA8Unorm, main, payload);
    [encoder endEncoding];
    [buffer commit];
    [buffer waitUntilCompleted];
    [texture getBytes:output
           bytesPerRow:(NSUInteger)width * 4
             fromRegion:MTLRegionMake2D(0, 0, (NSUInteger)width,
                                        (NSUInteger)height)
            mipmapLevel:0];
    [texture release];
    return 1;
  }
}
extern "C" MOONBIT_FFI_EXPORT
void moui_metal_context_release(uint64_t context_handle) {
  MOUIMetalContext *context = moui_metal_context_from_handle(context_handle);
  if (context != nil) {
    [context release];
  }
}

#else

// Metal is Apple-only. These exports exist so the package still links on a
// non-Apple host; the provider sees the device as unavailable and rejects the
// surface instead of drawing.
extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_metal_context_create(void) {
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_context_prepare(uint64_t context_handle,
                                   uint64_t layer_handle) {
  (void)context_handle;
  (void)layer_handle;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_texture_write(uint64_t context_handle,
                                 int32_t page,
                                 const uint8_t *pixels,
                                 int32_t pixel_bytes) {
  (void)context_handle;
  (void)page;
  (void)pixels;
  (void)pixel_bytes;
  return 0;
}

// Decode an encoded image (PNG/JPEG/whatever ImageIO accepts) with Apple's own
// stack and cache it as a texture under `key`. Returns (width << 32) | height,
// Non-Apple hosts: the Metal route has no device here, so both image entry
// points fail closed and the provider rejects the surface instead of drawing.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_image_decode(const uint8_t *bytes,
                                int32_t byte_len,
                                uint8_t *out_pixels,
                                int32_t out_capacity,
                                int32_t *out_size) {
  (void)bytes;
  (void)byte_len;
  (void)out_pixels;
  (void)out_capacity;
  (void)out_size;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_image_write_rgba(uint64_t context_handle,
                                    int32_t key,
                                    int32_t width,
                                    int32_t height,
                                    int32_t row_bytes,
                                    const uint8_t *pixels,
                                    int32_t pixel_bytes) {
  (void)context_handle;
  (void)key;
  (void)width;
  (void)height;
  (void)pixels;
  (void)pixel_bytes;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_draw_frame(uint64_t context_handle,
                              uint64_t layer_handle,
                              double red,
                              double green,
                              double blue,
                              double alpha,
                              const uint8_t *vertices,
                              int32_t vertex_bytes,
                              const int32_t *items,
                              int32_t item_bytes,
                              const float *shapes,
                              int32_t shape_bytes,
                              const int32_t *layers,
                              int32_t layer_bytes) {
  (void)context_handle;
  (void)layer_handle;
  (void)red;
  (void)green;
  (void)blue;
  (void)alpha;
  (void)vertices;
  (void)vertex_bytes;
  (void)items;
  (void)item_bytes;
  (void)shapes;
  (void)shape_bytes;
  (void)layers;
  (void)layer_bytes;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_metal_draw_proof(uint64_t context_handle,
                              int32_t width,
                              int32_t height,
                              double red,
                              double green,
                              double blue,
                              double alpha,
                              const uint8_t *vertices,
                              int32_t vertex_bytes,
                              const int32_t *items,
                              int32_t item_bytes,
                              const float *shapes,
                              int32_t shape_bytes,
                              const int32_t *layers,
                              int32_t layer_bytes,
                              uint8_t *output,
                              int32_t output_bytes) {
  (void)context_handle;
  (void)width;
  (void)height;
  (void)red;
  (void)green;
  (void)blue;
  (void)alpha;
  (void)vertices;
  (void)vertex_bytes;
  (void)items;
  (void)item_bytes;
  (void)shapes;
  (void)shape_bytes;
  (void)layers;
  (void)layer_bytes;
  (void)output;
  (void)output_bytes;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
void moui_metal_context_release(uint64_t context_handle) {
  (void)context_handle;
}

#endif
