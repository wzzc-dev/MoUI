#include <moonbit.h>
#include <stdint.h>
#include <string.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

static const NSInteger MOUI_IOS_SKIA_IMAGE_VIEW_TAG = 0x4D4F5549;

static int64_t moui_ios_skia_expected_pixel_bytes(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0 || width > INT32_MAX / 4) {
    return -1;
  }
  int64_t packed_row_bytes = (int64_t)width * 4;
  if (height > INT32_MAX / packed_row_bytes) {
    return -1;
  }
  return packed_row_bytes * height;
}

static UIImageView *moui_ios_skia_image_view(UIView *view, CGRect frame) {
  UIImageView *image_view = nil;
  for (UIView *subview in view.subviews) {
    if (subview.tag == MOUI_IOS_SKIA_IMAGE_VIEW_TAG) {
      if ([subview isKindOfClass:[UIImageView class]]) {
        image_view = (UIImageView *)subview;
        break;
      }
      [subview removeFromSuperview];
    }
  }
  if (image_view == nil) {
    image_view = [[UIImageView alloc] initWithFrame:frame];
    if (image_view == nil) {
      return nil;
    }
    image_view.tag = MOUI_IOS_SKIA_IMAGE_VIEW_TAG;
    image_view.contentMode = UIViewContentModeScaleToFill;
    image_view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    image_view.userInteractionEnabled = NO;
    [view addSubview:image_view];
  }
  return image_view;
}

// Apply a packed RGBA frame to the host UIView on the main thread.
// The window-hosted EventLoop runs on a background pthread
// (mbw_ios_start_event_loop); UIKit presentation must hop to main.
static int32_t moui_ios_present_skia_pixels_to_view_main(
    uint64_t raw_view_handle, int32_t width, int32_t height,
    NSData *packed_data) {
  UIView *view = (__bridge UIView *)(void *)(uintptr_t)raw_view_handle;
  if (view == nil || packed_data == nil) {
    return 0;
  }

  int64_t packed_row_bytes = (int64_t)width * 4;
  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  if (color_space == NULL) {
    return 0;
  }
  CGDataProviderRef provider =
      CGDataProviderCreateWithCFData((__bridge CFDataRef)packed_data);
  if (provider == NULL) {
    CGColorSpaceRelease(color_space);
    return 0;
  }
  CGBitmapInfo bitmap_info =
      kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
  CGImageRef image =
      CGImageCreate((size_t)width, (size_t)height, 8, 32,
                    (size_t)packed_row_bytes, color_space, bitmap_info, provider,
                    NULL, false, kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(color_space);
  if (image == NULL) {
    return 0;
  }

  CGFloat scale = view.window.screen.scale > 0.0 ? view.window.screen.scale
                                                 : UIScreen.mainScreen.scale;
  if (scale <= 0.0) {
    scale = 1.0;
  }
  CGRect bounds = view.bounds;
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
    bounds = CGRectMake(0.0, 0.0, (CGFloat)width / scale,
                        (CGFloat)height / scale);
  }
  if (bounds.size.width <= 0.0) {
    bounds.size.width = 1.0;
  }
  if (bounds.size.height <= 0.0) {
    bounds.size.height = 1.0;
  }

  UIImageView *image_view = moui_ios_skia_image_view(view, bounds);
  if (image_view == nil) {
    CGImageRelease(image);
    return 0;
  }

  UIImage *ui_image = [UIImage imageWithCGImage:image
                                          scale:scale
                                    orientation:UIImageOrientationUp];
  image_view.frame = bounds;
  image_view.image = ui_image;
  [image_view setNeedsDisplay];

  CGImageRelease(image);
  return 1;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_ios_present_skia_pixels_to_view(uint64_t raw_view_handle,
                                             int32_t width, int32_t height,
                                             int32_t row_bytes,
                                             const uint8_t *pixels,
                                             int32_t pixels_len) {
  if (raw_view_handle == 0) {
    return 0;
  }

  int64_t expected_len = moui_ios_skia_expected_pixel_bytes(width, height);
  int64_t packed_row_bytes = expected_len > 0 ? (int64_t)width * 4 : 0;
  if (expected_len <= 0 || row_bytes < packed_row_bytes) {
    return 0;
  }
  int64_t required_len = (int64_t)row_bytes * height;
  if (required_len <= 0 || required_len > INT32_MAX || pixels == NULL ||
      pixels_len < required_len) {
    return 0;
  }

  // Own a tightly packed copy so the source buffer can be reused/freed while
  // UIKit applies the frame on the main queue.
  NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)expected_len];
  if (data == nil || data.mutableBytes == NULL) {
    return 0;
  }
  uint8_t *dst = (uint8_t *)data.mutableBytes;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * (size_t)packed_row_bytes,
           pixels + (size_t)y * (size_t)row_bytes, (size_t)packed_row_bytes);
  }

  if ([NSThread isMainThread]) {
    return moui_ios_present_skia_pixels_to_view_main(raw_view_handle, width,
                                                     height, data);
  }

  // EventLoop thread: hop UIKit present. Use async to avoid deadlocking if the
  // main thread ever waits on this worker; soft-present in native_ios_host.c
  // uses the same pattern.
  dispatch_async(dispatch_get_main_queue(), ^{
    (void)moui_ios_present_skia_pixels_to_view_main(raw_view_handle, width,
                                                    height, data);
  });
  return 1;
}

/// Return the raw `CAMetalLayer*` handle for `view`, or 0 when the view's
/// backing layer is not a `CAMetalLayer`. The host view must be configured
/// with `+[CAMetalLayer class]` as its `+layerClass` before this returns a
/// non-zero handle. The caller retains the layer; Skia borrows per-frame
/// drawables from it without taking ownership.
extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_ios_skia_metal_layer_for_view(uint64_t raw_view_handle) {
  if (raw_view_handle == 0) {
    return 0;
  }
  __block uint64_t result = 0;
  void (^query)(void) = ^{
    UIView *view = (__bridge UIView *)(void *)(uintptr_t)raw_view_handle;
    if (view == nil) {
      result = 0;
      return;
    }
    CALayer *layer = view.layer;
    if (![layer isKindOfClass:[CAMetalLayer class]]) {
      result = 0;
      return;
    }
    CAMetalLayer *metal_layer = static_cast<CAMetalLayer *>(layer);
    result = static_cast<uint64_t>(reinterpret_cast<uintptr_t>(metal_layer));
  };
  if ([NSThread isMainThread]) {
    query();
  } else {
    // attach_session runs on the EventLoop pthread; layer queries must hit main.
    dispatch_sync(dispatch_get_main_queue(), query);
  }
  return result;
}
#else
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_ios_present_skia_pixels_to_view(uint64_t raw_view_handle,
                                             int32_t width, int32_t height,
                                             int32_t row_bytes,
                                             const uint8_t *pixels,
                                             int32_t pixels_len) {
  (void)raw_view_handle;
  (void)width;
  (void)height;
  (void)row_bytes;
  (void)pixels;
  (void)pixels_len;
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
uint64_t moui_ios_skia_metal_layer_for_view(uint64_t raw_view_handle) {
  (void)raw_view_handle;
  return 0;
}
#endif
