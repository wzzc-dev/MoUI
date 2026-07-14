#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum {
  MOUI_WINDOWS_SKIA_PRESENT_OK = 0,
  MOUI_WINDOWS_SKIA_PRESENT_BAD_WINDOW = 1,
  MOUI_WINDOWS_SKIA_PRESENT_BAD_DIMENSIONS = 2,
  MOUI_WINDOWS_SKIA_PRESENT_BAD_PIXELS = 3,
  MOUI_WINDOWS_SKIA_PRESENT_NO_DC = 4,
  MOUI_WINDOWS_SKIA_PRESENT_GDI_ERROR = 5,
  MOUI_WINDOWS_SKIA_PRESENT_ALLOC_FAILED = 6,
};

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_windows_present_skia_pixels_to_hwnd(uint64_t raw_hwnd,
                                                 int32_t width, int32_t height,
                                                 int32_t row_bytes,
                                                 const uint8_t *pixels,
                                                 int32_t pixels_len) {
  HWND hwnd = (HWND)(uintptr_t)raw_hwnd;
  if (hwnd == NULL || !IsWindow(hwnd)) {
    return MOUI_WINDOWS_SKIA_PRESENT_BAD_WINDOW;
  }
  if (width <= 0 || height <= 0 || width > INT32_MAX / 4) {
    return MOUI_WINDOWS_SKIA_PRESENT_BAD_DIMENSIONS;
  }
  int32_t min_row_bytes = width * 4;
  if (row_bytes < min_row_bytes || row_bytes <= 0) {
    return MOUI_WINDOWS_SKIA_PRESENT_BAD_DIMENSIONS;
  }
  int64_t required_len = (int64_t)row_bytes * height;
  if (required_len <= 0 || required_len > INT32_MAX || pixels == NULL || pixels_len < required_len) {
    return MOUI_WINDOWS_SKIA_PRESENT_BAD_PIXELS;
  }
  if (height > INT32_MAX / min_row_bytes) {
    return MOUI_WINDOWS_SKIA_PRESENT_BAD_DIMENSIONS;
  }

  size_t packed_len = (size_t)min_row_bytes * (size_t)height;
  uint8_t *dib_pixels = (uint8_t *)malloc(packed_len);
  if (dib_pixels == NULL) {
    return MOUI_WINDOWS_SKIA_PRESENT_ALLOC_FAILED;
  }
  for (int32_t y = 0; y < height; y++) {
    const uint8_t *src_row = pixels + (size_t)y * (size_t)row_bytes;
    uint8_t *dst_row = dib_pixels + (size_t)y * (size_t)min_row_bytes;
    for (int32_t x = 0; x < width; x++) {
      const uint8_t *src = src_row + (size_t)x * 4;
      uint8_t *dst = dst_row + (size_t)x * 4;
      dst[0] = src[2];
      dst[1] = src[1];
      dst[2] = src[0];
      dst[3] = src[3];
    }
  }

  BITMAPINFO bitmap_info;
  memset(&bitmap_info, 0, sizeof(bitmap_info));
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;

  HDC dc = GetDC(hwnd);
  if (dc == NULL) {
    free(dib_pixels);
    return MOUI_WINDOWS_SKIA_PRESENT_NO_DC;
  }
  RECT client_rect;
  int32_t dest_width = width;
  int32_t dest_height = height;
  if (GetClientRect(hwnd, &client_rect)) {
    int32_t client_width = (int32_t)(client_rect.right - client_rect.left);
    int32_t client_height = (int32_t)(client_rect.bottom - client_rect.top);
    if (client_width > 0 && client_height > 0) {
      dest_width = client_width;
      dest_height = client_height;
    }
  }
  int result = StretchDIBits(dc, 0, 0, dest_width, dest_height, 0, 0, width, height,
                             dib_pixels, &bitmap_info, DIB_RGB_COLORS, SRCCOPY);
  ReleaseDC(hwnd, dc);
  free(dib_pixels);
  if (result == GDI_ERROR) {
    return MOUI_WINDOWS_SKIA_PRESENT_GDI_ERROR;
  }
  return MOUI_WINDOWS_SKIA_PRESENT_OK;
}

#else

#include <moonbit.h>
#include <stdint.h>

enum {
  MOUI_WINDOWS_SKIA_PRESENT_BAD_WINDOW = 1,
};

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_windows_present_skia_pixels_to_hwnd(uint64_t raw_hwnd,
                                                 int32_t width, int32_t height,
                                                 int32_t row_bytes,
                                                 const uint8_t *pixels,
                                                 int32_t pixels_len) {
  (void)raw_hwnd;
  (void)width;
  (void)height;
  (void)row_bytes;
  (void)pixels;
  (void)pixels_len;
  return MOUI_WINDOWS_SKIA_PRESENT_BAD_WINDOW;
}

#endif
