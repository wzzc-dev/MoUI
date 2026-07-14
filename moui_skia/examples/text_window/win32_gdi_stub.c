// Weak GDI symbols so Windows-only examples can link under `moon test` on
// non-Windows hosts. Real Windows builds resolve these from system libraries.

#include <stdint.h>

#if !defined(_WIN32)

__attribute__((weak)) int IsWindow(uint64_t hwnd) {
  (void)hwnd;
  return 0;
}

__attribute__((weak)) uint64_t GetDC(uint64_t hwnd) {
  (void)hwnd;
  return 0;
}

__attribute__((weak)) int ReleaseDC(uint64_t hwnd, uint64_t dc) {
  (void)hwnd;
  (void)dc;
  return 0;
}

__attribute__((weak)) int StretchDIBits(
  uint64_t dc,
  int x_dest,
  int y_dest,
  int dest_width,
  int dest_height,
  int x_src,
  int y_src,
  int src_width,
  int src_height,
  const void *bits,
  const void *bitmap_info,
  unsigned int usage,
  unsigned int raster_op
) {
  (void)dc;
  (void)x_dest;
  (void)y_dest;
  (void)dest_width;
  (void)dest_height;
  (void)x_src;
  (void)y_src;
  (void)src_width;
  (void)src_height;
  (void)bits;
  (void)bitmap_info;
  (void)usage;
  (void)raster_op;
  return 0;
}

#endif
