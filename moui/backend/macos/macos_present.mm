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

@interface NSView (MOUIDragRegionKey)
- (NSValue *)mouiDragRegion;
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

// The window-drag region is stored on the presenter's parent (the window
// content view) as a rect in that parent's top-left ("MoUI logical") space,
// exactly like `mouiOverlayRect`.  `local_point` is supplied in the presenter's
// own bottom-left AppKit coordinate system, which is what both `mouseDown:`
// (`convertPoint:fromView:nil`) and `hitTest:` (`convertPoint:fromView:`) hand
// us once normalized through the parent.  Routing through the parent keeps the
// two callers on one code path: AppKit documents `hitTest:` points as living in
// the *superview's* space, while mouse events arrive in *window* space, and the
// parent content view converts either into its own space.  An unset, empty, or
// non-positive region reports NO so the presenter behaves exactly as before.
static BOOL moui_host_presenter_drag_region_contains(NSView *view,
                                                     NSPoint local_point) {
  NSView *parent = view.superview;
  if (parent == nil) {
    return NO;
  }
  NSValue *value = objc_getAssociatedObject(parent, @selector(mouiDragRegion));
  if (value == nil) {
    return NO;
  }
  NSRect region = value.rectValue;
  if (region.size.width <= 0.0 || region.size.height <= 0.0) {
    return NO;
  }
  // Presenter-local (bottom-left) -> parent content-view space.
  NSPoint parent_point = [view convertPoint:local_point toView:parent];
  // MoUI logical coordinates are top-left; AppKit's default content view is
  // bottom-left.  `MBWContentView` is flipped (top-left), so only flip when the
  // parent is not, keeping this correct for either host content view.
  if (!parent.isFlipped) {
    parent_point.y = NSHeight(parent.bounds) - parent_point.y;
  }
  return NSPointInRect(parent_point, region);
}

// Presenters decline every hit unless a drag region claims the point, so a
// click inside the region must be routed back to the presenter for
// `mouseDown:` to fire at all.
static NSView *moui_host_presenter_hit_test(NSView *view, NSPoint point) {
  NSPoint local_point = [view convertPoint:point fromView:view.superview];
  if (moui_host_presenter_drag_region_contains(view, local_point)) {
    return view;
  }
  return moui_host_presenter_overlay_contains(view, point) ? view.superview : nil;
}

// The CPU presenter used to be an NSImageView whose `image` property was
// replaced for every frame.  AppKit invalidates the old image layer before it
// has displayed the new one; a sidebar/editor scroll can therefore expose the
// clear window background for one or more compositing transactions.  Keep this
// as a plain layer-backed view and replace the layer contents atomically.
@interface MOUIHostPixelImageView : NSView {
  CGImageRef _presentedImage;
}
- (CGImageRef)presentedImage;
- (void)setPresentedImage:(CGImageRef)image;
@end

@implementation MOUIHostPixelImageView

- (CGImageRef)presentedImage {
  return _presentedImage;
}

- (void)setPresentedImage:(CGImageRef)image {
  // Keep an explicit CF retain; this view can outlive the present call while
  // Core Animation performs its next display transaction.
  if (_presentedImage == image) {
    return;
  }
  if (_presentedImage != NULL) {
    CGImageRelease(_presentedImage);
  }
  _presentedImage = image == NULL ? NULL : CGImageRetain(image);
}

- (void)dealloc {
  if (_presentedImage != NULL) {
    CGImageRelease(_presentedImage);
  }
  [super dealloc];
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (void)updateLayer {
  // AppKit may call this after a neighboring view invalidates the window.
  // Re-assert the last frame instead of letting the backing-store display
  // path clear the layer before the next renderer present.
  if (self.presentedImage != NULL) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.contents = (__bridge id)self.presentedImage;
    [CATransaction commit];
  }
}

- (NSView *)hitTest:(NSPoint)point {
  return moui_host_presenter_hit_test(self, point);
}

// Only a click inside the declared drag region reaches this override (the
// `hitTest:` above returns `self` solely for those points); every other click
// is routed elsewhere by hit testing and normal interaction is unaffected.
// `performWindowDragWithEvent:` needs the live AppKit event, which is exactly
// why this decode lives here and not behind a `WindowRequest` variant.
- (void)mouseDown:(NSEvent *)event {
  NSPoint local_point = [self convertPoint:event.locationInWindow fromView:nil];
  if (moui_host_presenter_drag_region_contains(self, local_point) &&
      self.window != nil) {
    [self.window performWindowDragWithEvent:event];
    return;
  }
  [super mouseDown:event];
}
@end

@interface MOUIHostGpuSurfaceView : NSView
@end

@implementation MOUIHostGpuSurfaceView
- (NSView *)hitTest:(NSPoint)point {
  return moui_host_presenter_hit_test(self, point);
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint local_point = [self convertPoint:event.locationInWindow fromView:nil];
  if (moui_host_presenter_drag_region_contains(self, local_point) &&
      self.window != nil) {
    [self.window performWindowDragWithEvent:event];
    return;
  }
  [super mouseDown:event];
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
  // The raster surface stores RGBA8888 premul bytes (see
  // `ImageInfo::n32_premul` = RGBA8888 in the raster renderer binding).
  // Interpret the buffer as R,G,B,A memory order; reading it as BGRA would
  // swap red and blue in every presented frame (images rendered with the
  // wrong hue on the raster route).
  CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4,
                                   color_space,
                                   kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
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
    image_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    image_view.wantsLayer = YES;
    image_view.layer.opaque = NO;
    image_view.layer.backgroundColor = NSColor.clearColor.CGColor;
    image_view.layer.contentsGravity = kCAGravityResize;
    image_view.layer.needsDisplayOnBoundsChange = NO;
    [view addSubview:image_view positioned:NSWindowAbove relativeTo:nil];
    [image_view release];
  }
  // The renderer calls this on the AppKit thread. Disable implicit frame and
  // contents animations so Core Animation never presents an intermediate
  // transparent frame while the sidebar/editor is scrolling.
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  if (!NSEqualRects(image_view.frame, view.bounds)) {
    image_view.frame = view.bounds;
  }
  CGFloat scale = view.window.backingScaleFactor > 0.0
      ? view.window.backingScaleFactor
      : 1.0;
  image_view.layer.contentsScale = scale;
  image_view.presentedImage = image;
  image_view.layer.contents = (__bridge id)image_view.presentedImage;
  [CATransaction commit];
  CGImageRelease(image);
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_cpu_presenter_stable_layer_test(void) {
  @autoreleasepool {
    NSView *parent = [[[NSView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 8.0, 8.0)] autorelease];
    uint8_t pixels_a[8 * 8 * 4];
    uint8_t pixels_b[8 * 8 * 4];
    memset(pixels_a, 0xff, sizeof(pixels_a));
    memset(pixels_b, 0x7f, sizeof(pixels_b));
    uint64_t raw_parent =
        (uint64_t)(uintptr_t)(__bridge void *)parent;
    if (moui_macos_present_pixels_to_view(
            raw_parent, 8, 8, 8 * 4, pixels_a, sizeof(pixels_a)) != 0 ||
        moui_macos_present_pixels_to_view(
            raw_parent, 8, 8, 8 * 4, pixels_b, sizeof(pixels_b)) != 0) {
      return 0;
    }
    MOUIHostPixelImageView *presenter = nil;
    for (NSView *subview in parent.subviews) {
      if ([subview.identifier
              isEqualToString:kMouiHostPixelImageViewIdentifier]) {
        presenter = [subview isKindOfClass:[MOUIHostPixelImageView class]]
            ? (MOUIHostPixelImageView *)subview
            : nil;
        break;
      }
    }
    id latest_contents = presenter.layer.contents;
    // A neighboring scroll view can invalidate the presenter while AppKit is
    // in the middle of a display pass.  Exercise that path explicitly: the
    // layer contents must survive an NSView display/updateLayer callback.
    [presenter setNeedsDisplay:YES];
    [presenter displayIfNeeded];
    // The view must retain the latest CGImage directly; an NSImageView image
    // swap would reintroduce the transient clear that this test guards.
    return presenter != nil && presenter.layer != nil &&
                   presenter.layer.contents != nil &&
                   presenter.presentedImage != NULL &&
                   presenter.layer.contents == latest_contents &&
                   ![presenter isKindOfClass:[NSImageView class]]
               ? 1
               : 0;
  }
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
void moui_macos_set_drag_region(uint64_t raw_view, double x, double y, double width,
                                double height) {
  @autoreleasepool {
    if (raw_view == 0) return;
    NSView *view = (__bridge NSView *)(void *)raw_view;
    if (view == nil) return;
    // Stored in the content view's top-left logical space, matching the
    // runtime's `Rect`; the presenter helpers convert into it on demand.  An
    // empty or negative rect clears the region so the presenters fall back to
    // their unmodified hit-testing behavior.
    BOOL empty = width <= 0.0 || height <= 0.0;
    objc_setAssociatedObject(
        view, @selector(mouiDragRegion),
        empty ? nil : [NSValue valueWithRect:NSMakeRect(x, y, width, height)],
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
}

extern "C" MOONBIT_FFI_EXPORT
void moui_macos_clear_drag_region(uint64_t raw_view) {
  @autoreleasepool {
    if (raw_view == 0) return;
    NSView *view = (__bridge NSView *)(void *)raw_view;
    if (view == nil) return;
    objc_setAssociatedObject(view, @selector(mouiDragRegion), nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_drag_region_test(void) {
  @autoreleasepool {
    // A flipped parent mirrors `MBWContentView`; the presenter spans it fully.
    NSView *parent = [[[MOUITestFlippedView alloc]
        initWithFrame:NSMakeRect(0.0, 0.0, 200.0, 120.0)] autorelease];
    MOUIHostGpuSurfaceView *gpu =
        [[[MOUIHostGpuSurfaceView alloc]
            initWithFrame:NSMakeRect(0.0, 0.0, 200.0, 120.0)] autorelease];
    MOUIHostPixelImageView *cpu =
        [[[MOUIHostPixelImageView alloc]
            initWithFrame:NSMakeRect(0.0, 0.0, 200.0, 120.0)] autorelease];
    [parent addSubview:gpu];
    [parent addSubview:cpu];
    uint64_t raw_parent = (uint64_t)(uintptr_t)(__bridge void *)parent;
    NSRect strip = NSMakeRect(0.0, 0.0, 200.0, 40.0);

    // No region configured: presenters must keep declining every hit.
    if ([gpu hitTest:NSMakePoint(100.0, 100.0)] != nil ||
        [cpu hitTest:NSMakePoint(100.0, 100.0)] != nil) {
      return 0;
    }
    moui_macos_set_drag_region(raw_parent, strip.origin.x, strip.origin.y,
                               strip.size.width, strip.size.height);
    // Inside the top strip: the presenter itself must claim the hit so that
    // `mouseDown:` can run.  Direct `hitTest:` input is in the parent's space.
    if ([gpu hitTest:NSMakePoint(100.0, 10.0)] != gpu ||
        [cpu hitTest:NSMakePoint(100.0, 10.0)] != cpu) {
      return 0;
    }
    // Outside the strip (and below the presenter's own frame): still declined.
    if ([gpu hitTest:NSMakePoint(100.0, 80.0)] != nil ||
        [cpu hitTest:NSMakePoint(100.0, 80.0)] != nil) {
      return 0;
    }
    // A zero-sized region is treated as unset.
    moui_macos_set_drag_region(raw_parent, 0.0, 0.0, 0.0, 0.0);
    if ([gpu hitTest:NSMakePoint(100.0, 10.0)] != nil ||
        [cpu hitTest:NSMakePoint(100.0, 10.0)] != nil) {
      return 0;
    }
    // Clearing restores the original behavior.
    moui_macos_set_drag_region(raw_parent, strip.origin.x, strip.origin.y,
                               strip.size.width, strip.size.height);
    moui_macos_clear_drag_region(raw_parent);
    if ([gpu hitTest:NSMakePoint(100.0, 10.0)] != nil ||
        [cpu hitTest:NSMakePoint(100.0, 10.0)] != nil) {
      return 0;
    }
    // A null handle must be a safe no-op.
    moui_macos_set_drag_region(0, 0.0, 0.0, 10.0, 10.0);
    moui_macos_clear_drag_region(0);
    return 1;
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

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_macos_present_modal_sheet(double x, double y, double width,
                                       double height) {
  @autoreleasepool {
    // Matching-host GUI smoke (`macos.host-modal` in smoke/gates.json)
    // evidences real NSWindow sheet ordering on the key window. Headless
    // unit runs have no NSApplication/host window, so the presenter reports
    // rejection and the presentation falls back to the view-level surface.
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    NSApplication *application = [NSApplication sharedApplication];
    if (application == nil || [application keyWindow] == nil) {
      return 0;
    }
    // TODO(host-smoke): order a bordered NSWindow sheet sized to the request
    // bounds on [application keyWindow] and drive its completion through the
    // window event host; landed with the matching-host smoke evidence run.
    return 0;
  }
}

extern "C" MOONBIT_FFI_EXPORT
void moui_macos_close_modal_sheet(void) {
  @autoreleasepool {
    // Paired with moui_macos_present_modal_sheet; no-op while no sheet is
    // open (see the matching-host smoke note above).
  }
}
