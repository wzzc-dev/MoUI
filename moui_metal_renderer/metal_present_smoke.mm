// The windowed presentation smoke's surface readback. See
// `metal_present_smoke.h` for why this is its own translation unit.

#include <stdlib.h>
#include <stdio.h>

#import "metal_present_smoke.h"

static BOOL moui_metal_present_smoke_reported = NO;

BOOL moui_metal_present_smoke_enabled(void) {
  const char *value = getenv("MOUI_MACOS_METAL_PRESENT_SMOKE");
  return value != NULL && value[0] != '\0' && value[0] != '0';
}

static NSUInteger moui_metal_present_smoke_ink(id<MTLTexture> staged,
                                               double red,
                                               double green,
                                               double blue,
                                               double alpha) {
  NSUInteger bytes_per_row = staged.width * 4;
  NSUInteger pitch = bytes_per_row * staged.height;
  uint8_t *pixels = (uint8_t *)calloc(pitch, 1);
  [staged getBytes:pixels
       bytesPerRow:bytes_per_row
        fromRegion:MTLRegionMake2D(0, 0, (NSInteger)staged.width,
                                   (NSInteger)staged.height)
       mipmapLevel:0];
  // BGRA8Unorm on the window; comparing all four channels means the order does not
  // have to be assumed, only that the clear colour is the one the pass used.
  uint8_t clear[4] = {(uint8_t)(blue * 255.0), (uint8_t)(green * 255.0),
                      (uint8_t)(red * 255.0), (uint8_t)(alpha * 255.0)};
  NSUInteger inked = 0;
  for (NSUInteger row = 0; row < staged.height; row++) {
    const uint8_t *line = pixels + row * bytes_per_row;
    for (NSUInteger column = 0; column < staged.width; column++) {
      const uint8_t *pixel = line + column * 4;
      if (pixel[0] != clear[0] || pixel[1] != clear[1] ||
          pixel[2] != clear[2] || pixel[3] != clear[3]) {
        inked++;
      }
    }
  }
  free(pixels);
  return inked;
}

void moui_metal_present_smoke_draw(id<MTLCommandBuffer> buffer,
                                   id<CAMetalDrawable> drawable,
                                   id<MTLDevice> device,
                                   double red,
                                   double green,
                                   double blue,
                                   double alpha) {
  id<MTLTexture> surface = drawable.texture;
  id<MTLTexture> staged = nil;
  BOOL report = moui_metal_present_smoke_enabled() &&
                !moui_metal_present_smoke_reported;
  if (report) {
    MTLTextureDescriptor *stage = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:surface.pixelFormat
                                     width:surface.width
                                    height:surface.height
                                 mipmapped:NO];
    stage.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    staged = [device newTextureWithDescriptor:stage];
    id<MTLBlitCommandEncoder> blit = [buffer blitCommandEncoder];
    if (staged == nil || blit == nil) {
      report = NO;
    } else {
      [blit copyFromTexture:surface
                sourceSlice:0
                sourceLevel:0
               sourceOrigin:MTLOriginMake(0, 0, 0)
                 sourceSize:MTLSizeMake(surface.width, surface.height, 1)
                toTexture:staged
         destinationSlice:0
         destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
      [blit endEncoding];
    }
  }
  [buffer presentDrawable:drawable];
  [buffer commit];
  if (!report) {
    return;
  }
  moui_metal_present_smoke_reported = YES;
  [buffer waitUntilCompleted];
  NSUInteger inked = moui_metal_present_smoke_ink(staged, red, green, blue, alpha);
  printf("MOUI-METAL-PRESENT width=%zu height=%zu ink=%zu\n",
         (size_t)staged.width, (size_t)staged.height, (size_t)inked);
  fflush(stdout);
  [staged release];
}
