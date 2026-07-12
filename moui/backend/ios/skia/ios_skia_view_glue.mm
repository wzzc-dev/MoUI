#include <moonbit.h>
#include <stdint.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

/// `UIView` subclass whose backing layer is a `CAMetalLayer` instead of the
/// default `CALayer`. Host apps that want the Skia Metal direct-present path
/// should create this view (via `moui_ios_skia_create_metal_view`) and pass
/// its raw handle to `IosViewHandle::new`. The existing CPU raster path
/// continues to work with a plain `UIView`; `ios_skia_metal_layer_for_view`
/// returns 0 for a non-Metal view, causing the provider to fall back to
/// raster automatically.
@interface MouiSkiaMetalView : UIView
@end

@implementation MouiSkiaMetalView

+ (Class)layerClass {
  return [CAMetalLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self != nil) {
    CAMetalLayer *metal_layer = (CAMetalLayer *)self.layer;
    // Bind the default system device. Skia's GrDirectContext will re-query
    // the device from the layer's CAMetalDrawable; this just ensures the
    // layer is usable before the first frame.
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device != nil) {
      metal_layer.device = device;
    }
    // Skia renders premultiplied RGBA; opaque is off to support compositing.
    metal_layer.opaque = NO;
    metal_layer.framebufferOnly = YES;
    metal_layer.contentsScale = [UIScreen mainScreen].scale;
  }
  return self;
}

@end

/// Create a `MouiSkiaMetalView` with the given frame and return its raw
/// `UIView*` handle as a `uint64_t`. Ownership is transferred to the caller
/// via `CFBridgingRetain`; the caller must eventually call
/// `moui_ios_skia_release_metal_view` (or add the view to a superview and
/// release, per standard ObjC ownership). Returns 0 on non-iOS builds or when
/// allocation fails. Must be called on the main thread.
extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_ios_skia_create_metal_view(double x, double y,
                                         double width, double height) {
  if (![NSThread isMainThread]) {
    return 0;
  }
  CGRect frame = CGRectMake((CGFloat)x, (CGFloat)y, (CGFloat)width,
                            (CGFloat)height);
  MouiSkiaMetalView *view = [[MouiSkiaMetalView alloc] initWithFrame:frame];
  if (view == nil) {
    return 0;
  }
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(
    CFBridgingRetain(view)
  ));
}

/// Release a Metal view previously created by `moui_ios_skia_create_metal_view`.
/// Safe to call with handle=0. Must be called on the main thread.
extern "C" MOONBIT_FFI_EXPORT
void moui_ios_skia_release_metal_view(uint64_t raw_view_handle) {
  if (raw_view_handle == 0 || ![NSThread isMainThread]) {
    return;
  }
  CFRelease((CFTypeRef)(void *)(uintptr_t)raw_view_handle);
}
#else
extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_ios_skia_create_metal_view(double x, double y,
                                         double width, double height) {
  (void)x;
  (void)y;
  (void)width;
  (void)height;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
void moui_ios_skia_release_metal_view(uint64_t raw_view_handle) {
  (void)raw_view_handle;
}
#endif
