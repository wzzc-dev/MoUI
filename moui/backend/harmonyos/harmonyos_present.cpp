#include <algorithm>
#include <cstdint>
#include <cstring>

#if defined(__has_include)
#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define MOUI_HARMONYOS_HAS_HILOG 1
#endif
#endif

#if defined(MOUI_HARMONYOS_USE_NATIVE_WINDOW) && defined(__has_include)
#if __has_include(<native_window/external_window.h>)
#include <native_buffer/native_buffer.h>
#include <native_window/external_window.h>
#define MOUI_HARMONYOS_HAS_NATIVE_WINDOW 1
#endif
#endif

namespace {

static const unsigned int k_log_domain = 0x4D4F;
static const char *k_log_tag = "MoUIHarmony";

void log_present_result(const char *message, int width, int height, int result) {
#if defined(MOUI_HARMONYOS_HAS_HILOG)
  OH_LOG_Print(
    LOG_APP,
    result != 0 ? LOG_INFO : LOG_WARN,
    k_log_domain,
    k_log_tag,
    "%{public}s width=%{public}d height=%{public}d result=%{public}d",
    message,
    width,
    height,
    result
  );
#else
  (void)message;
  (void)width;
  (void)height;
  (void)result;
#endif
}

}  // namespace

extern "C" int moui_harmonyos_present_pixels_to_surface(
  uint64_t surface_handle,
  int width,
  int height,
  int row_bytes,
  const uint8_t *pixels,
  int pixels_len
) {
  if (surface_handle == 0 || width <= 0 || height <= 0 || row_bytes <= 0 ||
      pixels == nullptr || pixels_len <= 0) {
    log_present_result("present rejected invalid input", width, height, 0);
    return 0;
  }

#if defined(MOUI_HARMONYOS_HAS_NATIVE_WINDOW)
  OHNativeWindow *window = reinterpret_cast<OHNativeWindow *>(surface_handle);
  OHNativeWindowBuffer *native_buffer = nullptr;
  int fence_fd = -1;

  OH_NativeWindow_NativeWindowHandleOpt(window, SET_BUFFER_GEOMETRY, width, height);
  OH_NativeWindow_NativeWindowHandleOpt(window, SET_FORMAT, NATIVEBUFFER_PIXEL_FMT_RGBA_8888);
  OH_NativeWindow_NativeWindowHandleOpt(
    window,
    SET_USAGE,
    static_cast<uint64_t>(NATIVEBUFFER_USAGE_CPU_WRITE | NATIVEBUFFER_USAGE_MEM_DMA)
  );

  if (OH_NativeWindow_NativeWindowRequestBuffer(window, &native_buffer, &fence_fd) != 0 ||
      native_buffer == nullptr) {
    log_present_result("present request buffer failed", width, height, 0);
    return 0;
  }

  BufferHandle *buffer_handle = OH_NativeWindow_GetBufferHandleFromNative(native_buffer);
  OH_NativeBuffer *mapped_buffer = nullptr;
  void *mapped_addr = nullptr;
  if (buffer_handle == nullptr ||
      OH_NativeBuffer_FromNativeWindowBuffer(native_buffer, &mapped_buffer) != 0 ||
      mapped_buffer == nullptr ||
      OH_NativeBuffer_Map(mapped_buffer, &mapped_addr) != 0 ||
      mapped_addr == nullptr) {
    OH_NativeWindow_NativeWindowAbortBuffer(window, native_buffer);
    log_present_result("present buffer handle failed", width, height, 0);
    return 0;
  }

  const int buffer_width = buffer_handle->width > 0 ? buffer_handle->width : width;
  const int buffer_height = buffer_handle->height > 0 ? buffer_handle->height : height;
  const int buffer_row_bytes = buffer_handle->stride > 0 ? buffer_handle->stride : buffer_width * 4;
  const int copy_width = std::min(width, buffer_width);
  const int copy_height = std::min(height, buffer_height);
  const int bytes_per_row = copy_width * 4;
  const int max_src_rows = pixels_len / row_bytes;
  const int max_dst_rows = buffer_handle->size > 0 ? buffer_handle->size / buffer_row_bytes : copy_height;
  const int rows = std::min({copy_height, max_src_rows, max_dst_rows});
  uint8_t *dst = static_cast<uint8_t *>(mapped_addr);

  if (buffer_row_bytes < bytes_per_row || rows <= 0) {
    OH_NativeBuffer_Unmap(mapped_buffer);
    OH_NativeWindow_NativeWindowAbortBuffer(window, native_buffer);
    log_present_result("present mapped buffer too small", width, height, 0);
    return 0;
  }

  for (int y = 0; y < rows; ++y) {
    std::memcpy(
      dst + static_cast<size_t>(y) * static_cast<size_t>(buffer_row_bytes),
      pixels + static_cast<size_t>(y) * static_cast<size_t>(row_bytes),
      static_cast<size_t>(bytes_per_row)
    );
  }
  OH_NativeBuffer_Unmap(mapped_buffer);

  Region region;
  Region::Rect rect;
  rect.x = 0;
  rect.y = 0;
  rect.w = copy_width;
  rect.h = rows;
  region.rects = &rect;
  region.rectNumber = 1;
  const int result = OH_NativeWindow_NativeWindowFlushBuffer(window, native_buffer, fence_fd, region) == 0
    ? 1
    : 0;
  log_present_result("present flushed native window", width, height, result);
  return result;
#else
  (void)width;
  (void)height;
  (void)row_bytes;
  (void)pixels;
  (void)pixels_len;
  log_present_result("present stub path without native window", width, height, 0);
  return 0;
#endif
}
