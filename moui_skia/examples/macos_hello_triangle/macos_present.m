#import <AppKit/AppKit.h>
#import <moonbit.h>
#import <stdint.h>
#import <string.h>

static const int32_t MOUI_SKIA_PRESENT_OK = 0;
static const int32_t MOUI_SKIA_PRESENT_BAD_VIEW = 1;
static const int32_t MOUI_SKIA_PRESENT_BAD_DIMENSIONS = 2;
static const int32_t MOUI_SKIA_PRESENT_BAD_PIXELS = 3;
static const int32_t MOUI_SKIA_PRESENT_ALLOC_FAILED = 4;

static NSString *const MOUI_SKIA_PRESENT_IMAGE_VIEW_ID = @"moui_skia_hello_present_image_view";

static int64_t moui_skia_expected_pixel_bytes(int32_t width, int32_t height) {
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
int32_t moui_skia_macos_present_rgba_to_window(uint64_t raw_view_handle,
                                              int32_t width, int32_t height,
                                              int32_t row_bytes,
                                              const uint8_t *pixels,
                                              int32_t pixels_len) {
  if (raw_view_handle == 0) {
    return MOUI_SKIA_PRESENT_BAD_VIEW;
  }
  NSView *view = (__bridge NSView *)(void *)raw_view_handle;
  if (view == nil) {
    return MOUI_SKIA_PRESENT_BAD_VIEW;
  }

  int64_t expected_len = moui_skia_expected_pixel_bytes(width, height);
  int64_t packed_row_bytes = expected_len > 0 ? (int64_t)width * 4 : 0;
  if (expected_len <= 0 || row_bytes < packed_row_bytes) {
    return MOUI_SKIA_PRESENT_BAD_DIMENSIONS;
  }
  int64_t required_len = (int64_t)row_bytes * height;
  if (required_len <= 0 || required_len > INT32_MAX || pixels == NULL ||
      pixels_len < required_len) {
    return MOUI_SKIA_PRESENT_BAD_PIXELS;
  }

  NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)expected_len];
  if (data == nil || data.mutableBytes == NULL) {
    return MOUI_SKIA_PRESENT_ALLOC_FAILED;
  }
  uint8_t *dst = (uint8_t *)data.mutableBytes;
  for (int32_t y = 0; y < height; y++) {
    memcpy(dst + (size_t)y * (size_t)packed_row_bytes,
           pixels + (size_t)y * (size_t)row_bytes,
           (size_t)packed_row_bytes);
  }

  CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
  if (color_space == NULL) {
    return MOUI_SKIA_PRESENT_ALLOC_FAILED;
  }
  CGDataProviderRef provider =
      CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  if (provider == NULL) {
    CGColorSpaceRelease(color_space);
    return MOUI_SKIA_PRESENT_ALLOC_FAILED;
  }
  CGBitmapInfo bitmap_info =
      kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
  CGImageRef image = CGImageCreate((size_t)width, (size_t)height, 8, 32,
                                   (size_t)packed_row_bytes, color_space,
                                   bitmap_info, provider, NULL, false,
                                   kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(color_space);
  if (image == NULL) {
    return MOUI_SKIA_PRESENT_ALLOC_FAILED;
  }

  NSImageView *image_view = nil;
  for (NSView *subview in view.subviews) {
    if ([subview isKindOfClass:[NSImageView class]] &&
        [subview.identifier isEqualToString:MOUI_SKIA_PRESENT_IMAGE_VIEW_ID]) {
      image_view = (NSImageView *)subview;
      break;
    }
  }
  if (image_view == nil) {
    image_view = [[NSImageView alloc] initWithFrame:view.bounds];
    image_view.identifier = MOUI_SKIA_PRESENT_IMAGE_VIEW_ID;
    image_view.imageScaling = NSImageScaleAxesIndependently;
    image_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [view addSubview:image_view];
    [image_view release];
  }

  NSImage *ns_image =
      [[NSImage alloc] initWithCGImage:image
                                  size:NSMakeSize((CGFloat)width,
                                                  (CGFloat)height)];
  if (ns_image == nil) {
    CGImageRelease(image);
    return MOUI_SKIA_PRESENT_ALLOC_FAILED;
  }
  image_view.frame = view.bounds;
  image_view.image = ns_image;
  [image_view setNeedsDisplay:YES];

  [ns_image release];
  CGImageRelease(image);
  return MOUI_SKIA_PRESENT_OK;
}
