#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <moonbit.h>
#import <stdint.h>

static NSString *const MOUI_MACOS_SURFACE_LAYER_NAME = @"moui_macos_surface_layer";

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
  CGRect bounds = view.bounds;
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
    bounds = CGRectMake(0.0, 0.0, width / layer_scale, height / layer_scale);
  }
  if (bounds.size.width <= 0.0) {
    bounds.size.width = 1.0;
  }
  if (bounds.size.height <= 0.0) {
    bounds.size.height = 1.0;
  }
  metal_layer.frame = bounds;
  metal_layer.bounds = CGRectMake(0.0, 0.0, bounds.size.width, bounds.size.height);
  metal_layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
  metal_layer.contentsScale = layer_scale;
  metal_layer.drawableSize = CGSizeMake(width > 0 ? width : bounds.size.width * layer_scale,
                                        height > 0 ? height : bounds.size.height * layer_scale);
  metal_layer.opaque = YES;

  return (void *)metal_layer;
}
