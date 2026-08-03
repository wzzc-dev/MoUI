#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <moonbit.h>
#include <stdint.h>

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_windows_present_pixels_to_hwnd(uint64_t raw_hwnd,
                                            int32_t width,
                                            int32_t height,
                                            int32_t row_bytes,
                                            const uint8_t *pixels,
                                            int32_t pixels_len) {
  HWND hwnd = (HWND)(uintptr_t)raw_hwnd;
  if (hwnd == NULL || !IsWindow(hwnd) || width <= 0 || height <= 0 ||
      row_bytes < width * 4 || pixels == NULL || pixels_len < row_bytes * height) {
    return 1;
  }
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  HDC dc = GetDC(hwnd);
  if (dc == NULL) return 1;
  RECT rect = {};
  GetClientRect(hwnd, &rect);
  int result = StretchDIBits(dc, 0, 0, rect.right - rect.left, rect.bottom - rect.top,
                             0, 0, width, height, pixels, &info, DIB_RGB_COLORS,
                             SRCCOPY);
  ReleaseDC(hwnd, dc);
  return result == GDI_ERROR ? 1 : 0;
}
#else
#include <moonbit.h>
#include <stdint.h>
extern "C" MOONBIT_FFI_EXPORT
int32_t moui_windows_present_pixels_to_hwnd(uint64_t, int32_t, int32_t, int32_t,
                                             const uint8_t *, int32_t) {
  return 1;
}
#endif
