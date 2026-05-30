#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <moonbit.h>
#import <stdint.h>
#import <string.h>

static NSString *const MOUI_MACOS_SKIA_IMAGE_VIEW_ID = @"moui_macos_skia_pixel_image_view";

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

MOONBIT_FFI_EXPORT
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

  NSImageView *image_view = nil;
  for (NSView *subview in view.subviews) {
    if ([subview isKindOfClass:[NSImageView class]] &&
        [subview.identifier isEqualToString:MOUI_MACOS_SKIA_IMAGE_VIEW_ID]) {
      image_view = (NSImageView *)subview;
      break;
    }
  }
  if (image_view == nil) {
    image_view = [[NSImageView alloc] initWithFrame:bounds];
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
