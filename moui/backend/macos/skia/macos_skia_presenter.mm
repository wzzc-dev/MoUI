#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <moonbit.h>
#import <stdio.h>
#import <stdlib.h>
#import <stdint.h>
#import <string.h>

static NSString *const MOUI_MACOS_SKIA_IMAGE_VIEW_ID = @"moui_macos_skia_pixel_image_view";

@interface MOUIMacosSkiaPassthroughImageView : NSImageView
@end

@implementation MOUIMacosSkiaPassthroughImageView
- (NSView *)hitTest:(NSPoint)point {
  return nil;
}
@end

enum {
  MOUI_MACOS_SKIA_PRESENT_OK = 0,
  MOUI_MACOS_SKIA_PRESENT_BAD_VIEW = 1,
  MOUI_MACOS_SKIA_PRESENT_BAD_DIMENSIONS = 2,
  MOUI_MACOS_SKIA_PRESENT_BAD_PIXELS = 3,
  MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED = 4,
};

static int64_t moui_macos_skia_expected_pixel_bytes(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0 || width > INT32_MAX / 4) {
    return -1;
  }
  int64_t packed_row_bytes = (int64_t)width * 4;
  if (height > INT32_MAX / packed_row_bytes) {
    return -1;
  }
  return packed_row_bytes * height;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_present_skia_pixels_to_view(uint64_t raw_content_view_handle,
                                               int32_t width, int32_t height,
                                               int32_t row_bytes,
                                               const uint8_t *pixels,
                                               int32_t pixels_len) {
  if (raw_content_view_handle == 0) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_VIEW;
  }
  NSView *view = (__bridge NSView *)(void *)raw_content_view_handle;
  if (view == nil) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_VIEW;
  }

  int64_t expected_len = moui_macos_skia_expected_pixel_bytes(width, height);
  int64_t packed_row_bytes = expected_len > 0 ? (int64_t)width * 4 : 0;
  if (expected_len <= 0 || row_bytes < packed_row_bytes) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_DIMENSIONS;
  }
  int64_t required_len = (int64_t)row_bytes * height;
  if (required_len <= 0 || required_len > INT32_MAX || pixels == NULL || pixels_len < required_len) {
    return MOUI_MACOS_SKIA_PRESENT_BAD_PIXELS;
  }

  NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)expected_len];
  if (data == nil || data.mutableBytes == NULL) {
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  uint8_t *dst = (uint8_t *)data.mutableBytes;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * (size_t)packed_row_bytes,
           pixels + (size_t)y * (size_t)row_bytes,
           (size_t)packed_row_bytes);
  }

  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  if (color_space == NULL) {
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  if (provider == NULL) {
    CGColorSpaceRelease(color_space);
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  CGBitmapInfo bitmap_info = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
  CGImageRef image = CGImageCreate((size_t)width, (size_t)height, 8, 32,
                                   (size_t)packed_row_bytes, color_space,
                                   bitmap_info, provider, NULL, false,
                                   kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(color_space);
  if (image == NULL) {
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }

  CGFloat scale = view.window.backingScaleFactor > 0.0 ? view.window.backingScaleFactor : 1.0;
  CGRect bounds = view.bounds;
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
    bounds = CGRectMake(0.0, 0.0, width / scale, height / scale);
  }
  if (bounds.size.width <= 0.0) {
    bounds.size.width = 1.0;
  }
  if (bounds.size.height <= 0.0) {
    bounds.size.height = 1.0;
  }

  MOUIMacosSkiaPassthroughImageView *image_view = nil;
  for (NSView *subview in view.subviews) {
    if ([subview.identifier isEqualToString:MOUI_MACOS_SKIA_IMAGE_VIEW_ID]) {
      if ([subview isKindOfClass:[MOUIMacosSkiaPassthroughImageView class]]) {
        image_view = (MOUIMacosSkiaPassthroughImageView *)subview;
        break;
      }
      [subview removeFromSuperview];
    }
  }
  if (image_view == nil) {
    image_view = [[MOUIMacosSkiaPassthroughImageView alloc] initWithFrame:bounds];
    if (image_view == nil) {
      CGImageRelease(image);
      return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
    }
    image_view.identifier = MOUI_MACOS_SKIA_IMAGE_VIEW_ID;
    image_view.imageScaling = NSImageScaleAxesIndependently;
    image_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [view addSubview:image_view positioned:NSWindowAbove relativeTo:nil];
    [image_view release];
  }

  NSImage *ns_image = [[NSImage alloc] initWithCGImage:image
                                                 size:NSMakeSize(bounds.size.width,
                                                                 bounds.size.height)];
  if (ns_image == nil) {
    CGImageRelease(image);
    return MOUI_MACOS_SKIA_PRESENT_ALLOC_FAILED;
  }
  image_view.frame = bounds;
  image_view.image = ns_image;
  [image_view setNeedsDisplay:YES];

  [ns_image release];
  CGImageRelease(image);
  return MOUI_MACOS_SKIA_PRESENT_OK;
}

/// Return the raw `CAMetalLayer*` handle for the content view, or 0 when the
/// view's backing layer is not a `CAMetalLayer`. Use
/// `moui_macos_skia_install_metal_layer` first to install a `CAMetalLayer`
/// as the view's backing layer; this probe then returns that layer.
extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_macos_skia_metal_layer_for_view(uint64_t raw_view_handle) {
  if (raw_view_handle == 0) {
    return 0;
  }
  NSView *view = (__bridge NSView *)(void *)raw_view_handle;
  if (view == nil) {
    return 0;
  }
  CALayer *layer = view.layer;
  if (![layer isKindOfClass:[CAMetalLayer class]]) {
    return 0;
  }
  CAMetalLayer *metal_layer = static_cast<CAMetalLayer *>(layer);
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(metal_layer));
}

/// Install a `CAMetalLayer` as the content view's backing layer. The view is
/// configured `wantsLayer:YES` and its `layer` is replaced with a new
/// `CAMetalLayer` bound to the default system device. Returns the raw
/// `CAMetalLayer*` handle on success, or 0 on failure (non-macOS build, nil
/// view, or device unavailable). Must be called on the main thread.
extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_macos_skia_install_metal_layer(uint64_t raw_view_handle) {
  if (raw_view_handle == 0) {
    return 0;
  }
  NSView *view = (__bridge NSView *)(void *)raw_view_handle;
  if (view == nil) {
    return 0;
  }
  // Enable layer-backing; the view's existing layer (if any) is replaced.
  view.wantsLayer = YES;
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (device == nil) {
    return 0;
  }
  CAMetalLayer *metal_layer = [CAMetalLayer layer];
  if (metal_layer == nil) {
    return 0;
  }
  metal_layer.device = device;
  metal_layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  metal_layer.frame = view.bounds;
  // Skia renders premultiplied BGRA; opaque is off to support compositing.
  metal_layer.opaque = NO;
  metal_layer.framebufferOnly = NO;
  NSWindow *window = view.window;
  if (window != nil) {
    metal_layer.contentsScale = window.backingScaleFactor > 0.0
      ? window.backingScaleFactor
      : 1.0;
  } else {
    metal_layer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
  }
  CGFloat width = MAX(1.0, NSWidth(view.bounds) * metal_layer.contentsScale);
  CGFloat height = MAX(1.0, NSHeight(view.bounds) * metal_layer.contentsScale);
  metal_layer.drawableSize = CGSizeMake(width, height);
  view.layer = metal_layer;
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(metal_layer));
}

/// Synchronize a CAMetalLayer with the renderer's physical pixel size before
/// Skia asks the layer for a drawable. Must be called on the main thread.
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_skia_configure_metal_layer(uint64_t raw_view_handle,
                                              uint64_t raw_layer_handle,
                                              int32_t width,
                                              int32_t height) {
  if (raw_view_handle == 0 || raw_layer_handle == 0 || width <= 0 || height <= 0) {
    return 0;
  }
  NSView *view = (__bridge NSView *)(void *)raw_view_handle;
  CAMetalLayer *metal_layer = (__bridge CAMetalLayer *)(void *)raw_layer_handle;
  if (view == nil || metal_layer == nil ||
      ![metal_layer isKindOfClass:[CAMetalLayer class]] ||
      metal_layer.device == nil) {
    return 0;
  }
  CGFloat scale = view.window.backingScaleFactor > 0.0
    ? view.window.backingScaleFactor
    : MAX(1.0, metal_layer.contentsScale);
  metal_layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  metal_layer.frame = view.bounds;
  metal_layer.contentsScale = scale;
  metal_layer.drawableSize = CGSizeMake((CGFloat)width, (CGFloat)height);
  if (getenv("MOUI_SKIA_GPU_DIAGNOSTICS") != NULL) {
    fprintf(stderr,
            "MoUI macOS Metal layer diagnostics: window_visible=%s; "
            "layer_matches_view=%s; view_bounds=%.0fx%.0f; "
            "drawable_size=%.0fx%.0f; contents_scale=%.2f\n",
            view.window.isVisible ? "true" : "false",
            view.layer == metal_layer ? "true" : "false",
            NSWidth(view.bounds), NSHeight(view.bounds),
            metal_layer.drawableSize.width, metal_layer.drawableSize.height,
            metal_layer.contentsScale);
  }
  return 1;
}
