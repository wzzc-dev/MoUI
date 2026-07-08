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

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_ios_present_skia_pixels_to_view(uint64_t raw_view_handle,
                                             int32_t width, int32_t height,
                                             int32_t row_bytes,
                                             const uint8_t *pixels,
                                             int32_t pixels_len) {
  if (raw_view_handle == 0 || ![NSThread isMainThread]) {
    return 0;
  }
  UIView *view = (__bridge UIView *)(void *)(uintptr_t)raw_view_handle;
  if (view == nil) {
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

  NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)expected_len];
  if (data == nil || data.mutableBytes == NULL) {
    return 0;
  }
  uint8_t *dst = (uint8_t *)data.mutableBytes;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * (size_t)packed_row_bytes,
           pixels + (size_t)y * (size_t)row_bytes,
           (size_t)packed_row_bytes);
  }

  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  if (color_space == NULL) {
    return 0;
  }
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  if (provider == NULL) {
    CGColorSpaceRelease(color_space);
    return 0;
  }
  CGBitmapInfo bitmap_info = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
  CGImageRef image = CGImageCreate((size_t)width, (size_t)height, 8, 32,
                                   (size_t)packed_row_bytes, color_space,
                                   bitmap_info, provider, NULL, false,
                                   kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(color_space);
  if (image == NULL) {
    return 0;
  }

  CGFloat scale = view.window.screen.scale > 0.0 ? view.window.screen.scale : UIScreen.mainScreen.scale;
  if (scale <= 0.0) {
    scale = 1.0;
  }
  CGRect bounds = view.bounds;
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
    bounds = CGRectMake(0.0, 0.0, (CGFloat)width / scale, (CGFloat)height / scale);
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
#endif
