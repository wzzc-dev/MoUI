#ifdef _WIN32

// Windows async image loading: background file read plus Skia decode via
// CreateThread. The worker uses C/C++ allocations only and never touches
// MoonBit GC objects. The main-thread drain copies decoded pixels into
// moonbit_bytes_t.

#include <moonbit.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <windows.h>

#if defined(MOUI_SKIA_HAS_SKIA)
#include "include/codec/SkCodec.h"
#include "include/core/SkBitmap.h"
#include "include/core/SkColorType.h"
#include "include/core/SkData.h"
#include "include/core/SkImageInfo.h"
#include <memory>
#endif

typedef struct moui_async_image_result {
  int64_t window_id;
  char *source;
  int32_t source_len;
  uint8_t *bytes;
  int32_t bytes_len;
  int32_t status;
  int32_t background_io;
  int32_t decoded_width;
  int32_t decoded_height;
  int32_t decoded_row_bytes;
  int32_t background_decode;
  struct moui_async_image_result *next;
} moui_async_image_result_t;

typedef struct moui_async_image_request {
  int64_t window_id;
  char *source;
  int32_t source_len;
  int32_t is_background;
} moui_async_image_request_t;

static moui_async_image_result_t *g_results_head = NULL;
static moui_async_image_result_t *g_results_tail = NULL;
static CRITICAL_SECTION g_mutex;
static int g_mutex_initialized = 0;

static void moui_ensure_mutex(void) {
  if (!g_mutex_initialized) {
    InitializeCriticalSection(&g_mutex);
    g_mutex_initialized = 1;
  }
}

static int moui_async_image_decode_bytes(const uint8_t *encoded,
                                         int32_t encoded_len,
                                         moui_async_image_result_t *result) {
  if (encoded == NULL || encoded_len <= 0 || result == NULL) {
    return 0;
  }
#if defined(MOUI_SKIA_HAS_SKIA)
  sk_sp<SkData> data = SkData::MakeWithCopy(encoded, (size_t)encoded_len);
  if (data == nullptr) {
    return 0;
  }
  std::unique_ptr<SkCodec> codec = SkCodec::MakeFromData(data);
  if (codec == nullptr) {
    return 0;
  }
  const SkImageInfo source_info = codec->getInfo();
  const int32_t width = source_info.width();
  const int32_t height = source_info.height();
  if (width <= 0 || height <= 0) {
    return 0;
  }
  SkBitmap bitmap;
  SkImageInfo target_info =
      SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
                        kPremul_SkAlphaType);
  if (!bitmap.tryAllocPixels(target_info)) {
    return 0;
  }
  SkCodec::Result decode_result =
      codec->getPixels(target_info, bitmap.getPixels(), bitmap.rowBytes());
  if (decode_result != SkCodec::kSuccess) {
    return 0;
  }
  const size_t row_bytes = bitmap.rowBytes();
  const size_t pixel_len = row_bytes * (size_t)height;
  if (row_bytes > INT32_MAX || pixel_len > INT32_MAX) {
    return 0;
  }
  uint8_t *pixels = (uint8_t *)malloc(pixel_len);
  if (pixels == NULL) {
    return 0;
  }
  memcpy(pixels, bitmap.getPixels(), pixel_len);
  result->bytes = pixels;
  result->bytes_len = (int32_t)pixel_len;
  result->decoded_width = width;
  result->decoded_height = height;
  result->decoded_row_bytes = (int32_t)row_bytes;
  result->background_decode = result->background_io;
  return 1;
#else
  (void)encoded;
  (void)encoded_len;
  (void)result;
  return 0;
#endif
}

static void moui_async_image_enqueue_result(moui_async_image_result_t *result) {
  moui_ensure_mutex();
  EnterCriticalSection(&g_mutex);
  if (g_results_tail == NULL) {
    g_results_head = result;
    g_results_tail = result;
  } else {
    g_results_tail->next = result;
    g_results_tail = result;
  }
  LeaveCriticalSection(&g_mutex);
}

static DWORD WINAPI moui_async_image_read_file(LPVOID arg) {
  moui_async_image_request_t *req = (moui_async_image_request_t *)arg;
  if (req == NULL) {
    return 0;
  }
  moui_async_image_result_t *result =
      (moui_async_image_result_t *)calloc(1, sizeof(moui_async_image_result_t));
  if (result == NULL) {
    free(req->source);
    free(req);
    return 0;
  }
  result->window_id = req->window_id;
  result->source = req->source;
  result->source_len = req->source_len;
  result->status = 1;
  result->background_io = req->is_background;
  result->next = NULL;

  FILE *f = fopen(req->source, "rb");
  if (f != NULL) {
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size > 0) {
      uint8_t *encoded = (uint8_t *)malloc((size_t)size);
      if (encoded != NULL) {
        size_t nread = fread(encoded, 1, (size_t)size, f);
        fclose(f);
        if ((long)nread == size) {
          if (moui_async_image_decode_bytes(encoded, (int32_t)size, result)) {
            result->status = 0;
          } else {
            result->status = 5;
          }
        } else {
          result->status = 4;
        }
        free(encoded);
      } else {
        fclose(f);
        result->status = 3;
      }
    } else {
      fclose(f);
      result->status = 2;
    }
  }

  moui_async_image_enqueue_result(result);
  free(req);
  return 0;
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_async_image_spawn(int64_t window_id,
                                    moonbit_bytes_t source_bytes,
                                    int32_t source_len) {
  if (source_bytes == NULL || source_len <= 0) {
    return;
  }
  moui_async_image_request_t *req =
      (moui_async_image_request_t *)calloc(1, sizeof(moui_async_image_request_t));
  if (req == NULL) {
    return;
  }
  req->window_id = window_id;
  req->source = (char *)malloc((size_t)source_len + 1);
  if (req->source == NULL) {
    free(req);
    return;
  }
  memcpy(req->source, source_bytes, (size_t)source_len);
  req->source[source_len] = '\0';
  req->source_len = source_len;
  req->is_background = 1;

  HANDLE h = CreateThread(NULL, 0, moui_async_image_read_file, req, 0, NULL);
  if (h == NULL) {
    req->is_background = 0;
    moui_async_image_read_file(req);
  } else {
    CloseHandle(h);
  }
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_async_image_spawn_sync(int64_t window_id,
                                         moonbit_bytes_t source_bytes,
                                         int32_t source_len) {
  if (source_bytes == NULL || source_len <= 0) {
    return;
  }
  moui_async_image_request_t *req =
      (moui_async_image_request_t *)calloc(1, sizeof(moui_async_image_request_t));
  if (req == NULL) {
    return;
  }
  req->window_id = window_id;
  req->source = (char *)malloc((size_t)source_len + 1);
  if (req->source == NULL) {
    free(req);
    return;
  }
  memcpy(req->source, source_bytes, (size_t)source_len);
  req->source[source_len] = '\0';
  req->source_len = source_len;
  req->is_background = 1;
  moui_async_image_read_file(req);
}

extern "C" MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_async_image_take_result(void) {
  moui_ensure_mutex();
  EnterCriticalSection(&g_mutex);
  moui_async_image_result_t *result = g_results_head;
  if (result == NULL) {
    LeaveCriticalSection(&g_mutex);
    return moonbit_make_bytes(0, 0);
  }
  g_results_head = result->next;
  if (g_results_head == NULL) {
    g_results_tail = NULL;
  }
  LeaveCriticalSection(&g_mutex);

  int32_t header = 40;
  int32_t total = header + result->source_len + result->bytes_len;
  moonbit_bytes_t out = moonbit_make_bytes(total, 0);
  memcpy(out + 0, &result->window_id, 8);
  memcpy(out + 8, &result->status, 4);
  memcpy(out + 12, &result->source_len, 4);
  memcpy(out + 16, &result->bytes_len, 4);
  memcpy(out + 20, &result->background_io, 4);
  memcpy(out + 24, &result->decoded_width, 4);
  memcpy(out + 28, &result->decoded_height, 4);
  memcpy(out + 32, &result->decoded_row_bytes, 4);
  memcpy(out + 36, &result->background_decode, 4);
  if (result->source_len > 0) {
    memcpy(out + header, result->source, (size_t)result->source_len);
  }
  if (result->bytes_len > 0 && result->bytes != NULL) {
    memcpy(out + header + result->source_len, result->bytes,
           (size_t)result->bytes_len);
  }

  free(result->source);
  free(result->bytes);
  free(result);
  return out;
}

#else

#include <moonbit.h>
#include <stdint.h>

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_async_image_spawn(int64_t window_id,
                                    moonbit_bytes_t source_bytes,
                                    int32_t source_len) {
  (void)window_id;
  (void)source_bytes;
  (void)source_len;
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_async_image_spawn_sync(int64_t window_id,
                                         moonbit_bytes_t source_bytes,
                                         int32_t source_len) {
  (void)window_id;
  (void)source_bytes;
  (void)source_len;
}

extern "C" MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_async_image_take_result(void) {
  return moonbit_make_bytes(0, 0);
}

#endif
