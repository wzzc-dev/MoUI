#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <moonbit.h>
#import <stdint.h>

static NSString *const MOUI_MACOS_SURFACE_LAYER_NAME = @"moui_macos_surface_layer";

static inline CGSize moui_macos_surface_layer_size(NSView *view, int32_t width,
                                                   int32_t height, double scale) {
  double layer_scale = scale > 0.0 ? scale : view.window.backingScaleFactor;
  if (layer_scale <= 0.0) {
    layer_scale = 1.0;
  }
  double logical_width = width > 0 ? ((double)width) / layer_scale : view.bounds.size.width;
  double logical_height = height > 0 ? ((double)height) / layer_scale : view.bounds.size.height;
  if (logical_width <= 0.0) {
    logical_width = 1.0;
  }
  if (logical_height <= 0.0) {
    logical_height = 1.0;
  }
  return CGSizeMake(logical_width, logical_height);
}

MOONBIT_FFI_EXPORT
void *moui_macos_surface_host_layer_from_view(uint64_t raw_view_handle, int32_t width,
                                              int32_t height, double scale_factor) {
  if (raw_view_handle == 0) {
    return NULL;
  }

  NSView *view = (__bridge NSView *)(void *)raw_view_handle;
  if (view == nil) {
    return NULL;
  }

  view.wantsLayer = YES;

  CAMetalLayer *metal_layer = nil;
  CALayer *existing_layer = view.layer;
  if ([existing_layer isKindOfClass:[CAMetalLayer class]]) {
    metal_layer = (CAMetalLayer *)existing_layer;
  } else if ([existing_layer.name isEqualToString:MOUI_MACOS_SURFACE_LAYER_NAME]) {
    metal_layer = (CAMetalLayer *)existing_layer;
  }

  if (metal_layer == nil) {
    metal_layer = [CAMetalLayer layer];
    metal_layer.name = MOUI_MACOS_SURFACE_LAYER_NAME;
    view.layer = metal_layer;
    view.wantsLayer = YES;
  }

  double layer_scale = scale_factor > 0.0 ? scale_factor : view.window.backingScaleFactor;
  if (layer_scale <= 0.0) {
    layer_scale = 1.0;
  }
  CGSize logical_size = moui_macos_surface_layer_size(view, width, height, layer_scale);
  CGRect bounds = CGRectMake(0.0, 0.0, logical_size.width, logical_size.height);
  metal_layer.frame = bounds;
  metal_layer.bounds = bounds;
  metal_layer.contentsScale = layer_scale;
  metal_layer.drawableSize = CGSizeMake(logical_size.width * layer_scale,
                                        logical_size.height * layer_scale);
  metal_layer.opaque = YES;

  return (void *)metal_layer;
}
