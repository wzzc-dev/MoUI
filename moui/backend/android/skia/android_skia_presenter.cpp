#include <algorithm>
#include <cstdint>
#include <cstring>

#if defined(__ANDROID__)
#include <android/native_window.h>
#endif

extern "C" int moui_android_present_skia_pixels_to_surface(
  uint64_t surface_handle,
  int width,
  int height,
  int row_bytes,
  const uint8_t *pixels,
  int pixels_len
) {
  if (surface_handle == 0 || width <= 0 || height <= 0 || row_bytes <= 0 ||
      pixels == nullptr || pixels_len <= 0) {
    return 0;
  }

#if defined(__ANDROID__)
  ANativeWindow *window = reinterpret_cast<ANativeWindow *>(surface_handle);
  if (ANativeWindow_setBuffersGeometry(
        window,
        width,
        height,
        WINDOW_FORMAT_RGBA_8888
      ) != 0) {
    return 0;
  }

  ANativeWindow_Buffer buffer;
  if (ANativeWindow_lock(window, &buffer, nullptr) != 0) {
    return 0;
  }

  const int copy_width = std::min(width, buffer.width);
  const int copy_height = std::min(height, buffer.height);
  const int src_row_bytes = row_bytes;
  const int dst_row_bytes = buffer.stride * 4;
  const int bytes_per_row = copy_width * 4;
  const int max_src_rows = pixels_len / src_row_bytes;
  const int rows = std::min(copy_height, max_src_rows);
  auto *dst = static_cast<uint8_t *>(buffer.bits);
  for (int y = 0; y < rows; ++y) {
    std::memcpy(
      dst + static_cast<size_t>(y) * dst_row_bytes,
      pixels + static_cast<size_t>(y) * src_row_bytes,
      static_cast<size_t>(bytes_per_row)
    );
  }

  ANativeWindow_unlockAndPost(window);
  return 1;
#else
  (void)width;
  (void)height;
  (void)row_bytes;
  (void)pixels;
  (void)pixels_len;
  return 0;
#endif
}
