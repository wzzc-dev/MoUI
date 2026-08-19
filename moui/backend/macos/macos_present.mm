#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <moonbit.h>
#import <objc/runtime.h>
#import <stdint.h>

@interface NSView (MOUIOverlayStateKey)
- (BOOL)mouiOverlayActive;
- (NSValue *)mouiOverlayRect;
@end

static BOOL moui_host_presenter_overlay_contains(NSView *view, NSPoint point) {
  NSView *parent = view.superview;
  NSNumber *active = objc_getAssociatedObject(view, @selector(mouiOverlayActive));
  NSValue *value = objc_getAssociatedObject(parent, @selector(mouiOverlayRect));
  if (!active.boolValue || value == nil || parent == nil) {
    return NO;
  }
  // `hitTest:` supplies presenter-local coordinates, while the runtime stores
  // overlay bounds in the parent content-view coordinate space.
  NSPoint parent_point = [view convertPoint:point toView:parent];
  return NSPointInRect(parent_point, value.rectValue);
}

@interface MOUIHostPixelImageView : NSImageView
@end

@implementation MOUIHostPixelImageView
- (NSView *)hitTest:(NSPoint)point {
  return moui_host_presenter_overlay_contains(self, point) ? self.superview : nil;
}
@end

@interface MOUIHostGpuSurfaceView : NSView
@end

@implementation MOUIHostGpuSurfaceView
- (NSView *)hitTest:(NSPoint)point {
  return moui_host_presenter_overlay_contains(self, point) ? self.superview : nil;
}
@end

static NSString *const kMouiHostPixelImageViewIdentifier =
    @"moui_host_pixel_image_view";
static NSString *const kMouiHostGpuSurfaceViewIdentifier =
    @"moui_host_gpu_surface_view";

@interface MOUITestFlippedView : NSView
@end

@implementation MOUITestFlippedView
- (BOOL)isFlipped {
  return YES;
}
@end

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_present_pixels_to_view(uint64_t raw_view,
                                          int32_t width,
                                          int32_t height,
                                          int32_t row_bytes,
                                          const uint8_t *pixels,
                                          int32_t pixels_len) {
  if (raw_view == 0 || width <= 0 || height <= 0 || row_bytes < width * 4 ||
      pixels == NULL || pixels_len < row_bytes * height) {
    return 1;
  }
  NSView *view = (__bridge NSView *)(void *)raw_view;
  if (view == nil) {
    return 1;
  }
  NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)width * height * 4];
  if (data == nil) {
    return 1;
  }
  uint8_t *dst = (uint8_t *)data.mutableBytes;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * width * 4,
           pixels + (size_t)y * row_bytes,
           (size_t)width * 4);
  }
  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4,
                                   color_space,
                                   kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst,
                                   provider, NULL, false,
                                   kCGRenderingIntentDefault);
  if (provider != NULL) CGDataProviderRelease(provider);
  if (color_space != NULL) CGColorSpaceRelease(color_space);
  if (image == NULL) return 1;

  MOUIHostPixelImageView *image_view = nil;
  for (NSView *subview in view.subviews) {
    if ([subview.identifier isEqualToString:kMouiHostPixelImageViewIdentifier] &&
        [subview isKindOfClass:[MOUIHostPixelImageView class]]) {
      image_view = (MOUIHostPixelImageView *)subview;
      break;
    }
  }
  if (image_view == nil) {
    image_view = [[MOUIHostPixelImageView alloc] initWithFrame:view.bounds];
    image_view.identifier = kMouiHostPixelImageViewIdentifier;
    image_view.imageScaling = NSImageScaleAxesIndependently;
    image_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    image_view.wantsLayer = YES;
    image_view.layer.opaque = NO;
    image_view.layer.backgroundColor = NSColor.clearColor.CGColor;
    [view addSubview:image_view positioned:NSWindowAbove relativeTo:nil];
    [image_view release];
  }
  NSImage *ns_image = [[NSImage alloc] initWithCGImage:image size:view.bounds.size];
  image_view.frame = view.bounds;
  image_view.image = ns_image;
  [ns_image release];
  CGImageRelease(image);
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_macos_surface_layer_from_view(uint64_t raw_view,
                                            int32_t width,
                                            int32_t height,
                                            double scale_factor) {
  if (raw_view == 0) return 0;
  NSView *view = (__bridge NSView *)(void *)raw_view;
  if (view == nil) return 0;

  MOUIHostGpuSurfaceView *surface_view = nil;
  for (NSView *subview in view.subviews) {
    if ([subview.identifier isEqualToString:kMouiHostGpuSurfaceViewIdentifier] &&
        [subview isKindOfClass:[MOUIHostGpuSurfaceView class]]) {
      surface_view = (MOUIHostGpuSurfaceView *)subview;
      break;
    }
  }
  if (surface_view == nil) {
    surface_view = [[MOUIHostGpuSurfaceView alloc] initWithFrame:view.bounds];
    surface_view.identifier = kMouiHostGpuSurfaceViewIdentifier;
    surface_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    surface_view.wantsLayer = YES;
    [view addSubview:surface_view positioned:NSWindowAbove relativeTo:nil];
    [surface_view release];
  }
  surface_view.frame = view.bounds;
  surface_view.wantsLayer = YES;
  CAMetalLayer *layer = nil;
  if ([surface_view.layer isKindOfClass:[CAMetalLayer class]]) {
    layer = (CAMetalLayer *)surface_view.layer;
  }
  if (layer == nil) {
    layer = [CAMetalLayer layer];
    layer.name = @"moui_host_surface_layer";
    surface_view.layer = layer;
    surface_view.wantsLayer = YES;
  }

  double resolved_scale = scale_factor > 0.0
      ? scale_factor
      : view.window.backingScaleFactor;
  if (resolved_scale <= 0.0) resolved_scale = 1.0;
  CGRect bounds = surface_view.bounds;
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
    bounds = CGRectMake(0.0, 0.0,
                        width > 0 ? width / resolved_scale : 1.0,
                        height > 0 ? height / resolved_scale : 1.0);
  }
  layer.frame = bounds;
  layer.bounds = CGRectMake(0.0, 0.0, bounds.size.width, bounds.size.height);
  layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
  layer.contentsScale = resolved_scale;
  layer.drawableSize = CGSizeMake(
      width > 0 ? width : bounds.size.width * resolved_scale,
      height > 0 ? height : bounds.size.height * resolved_scale);
  // Full-surface platform-view frames keep this presenter transparent, while
  // modal frames add translucent overlay pixels above the native view.
  layer.opaque = NO;
  layer.backgroundColor = NSColor.clearColor.CGColor;
  return (uint64_t)(uintptr_t)(__bridge void *)layer;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_gpu_surface_presenter_test(void) {
  @autoreleasepool {
    NSView *parent = [[[NSView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 32.0, 24.0)] autorelease];
    uint64_t raw_parent =
        (uint64_t)(uintptr_t)(__bridge void *)parent;
    uint64_t raw_layer =
        moui_macos_surface_layer_from_view(raw_parent, 64, 48, 2.0);
    NSView *presenter = nil;
    for (NSView *subview in parent.subviews) {
      if ([subview.identifier
              isEqualToString:kMouiHostGpuSurfaceViewIdentifier]) {
        presenter = subview;
        break;
      }
    }
    if (raw_layer == 0 || presenter == nil ||
        ![presenter isKindOfClass:[MOUIHostGpuSurfaceView class]] ||
        ![presenter.layer isKindOfClass:[CAMetalLayer class]] ||
        presenter.layer.opaque ||
        CGColorGetAlpha(presenter.layer.backgroundColor) != 0.0 ||
        [presenter hitTest:NSMakePoint(1.0, 1.0)] != nil) {
      return 0;
    }
    return raw_layer ==
                   (uint64_t)(uintptr_t)(__bridge void *)presenter.layer
               ? 1
               : 0;
  }
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_gpu_surface_partial_overlay_hit_test(void) {
  @autoreleasepool {
    NSView *parent = [[[MOUITestFlippedView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 80.0)] autorelease];
    MOUIHostGpuSurfaceView *presenter =
        [[[MOUIHostGpuSurfaceView alloc]
            initWithFrame:NSMakeRect(10.0, 10.0, 80.0, 60.0)] autorelease];
    [parent addSubview:presenter];
    objc_setAssociatedObject(
        presenter, @selector(mouiOverlayActive), @YES,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(
        parent, @selector(mouiOverlayRect),
        [NSValue valueWithRect:NSMakeRect(12.0, 12.0, 20.0, 20.0)],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // The presenter intentionally keeps AppKit's default (bottom-left)
    // coordinate system while its flipped parent uses top-left coordinates.
    // A top-left parent point (12,12) therefore arrives at presenter-local
    // y=58, and convertPoint: must map it back before the bounds check.
    BOOL inside = [presenter hitTest:NSMakePoint(2.0, 58.0)] == parent;
    BOOL outside = [presenter hitTest:NSMakePoint(0.0, 60.0)] == nil;
    BOOL parent_inside = [parent hitTest:NSMakePoint(12.0, 12.0)] == parent;
    return inside && outside && parent_inside ? 1 : 0;
  }
}
