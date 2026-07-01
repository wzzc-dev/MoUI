// Windows async image I/O: background file reading via CreateThread, results
// drained on the main thread. The background thread only uses C stdlib
// (fopen/fread) and malloc — it never touches MoonBit GC objects. The
// main-thread drain copies malloc'd buffers into moonbit_bytes_t and frees
// the originals.

#include <moonbit.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <windows.h>

typedef struct moui_async_image_result {
  int64_t window_id;
  char *source; // malloc'd, null-terminated
  int32_t source_len;
  uint8_t *bytes; // malloc'd, NULL if failed
  int32_t bytes_len;
  int32_t status; // 0=ok, non-zero=error
  int32_t background_io;
  struct moui_async_image_result *next;
} moui_async_image_result_t;

typedef struct moui_async_image_request {
  int64_t window_id;
  char *source; // malloc'd, null-terminated
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
  result->bytes = NULL;
  result->bytes_len = 0;
  result->status = 1;
  result->background_io = req->is_background;
  result->next = NULL;

  FILE *f = fopen(req->source, "rb");
  if (f != NULL) {
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size > 0) {
      uint8_t *buf = (uint8_t *)malloc((size_t)size);
      if (buf != NULL) {
        size_t nread = fread(buf, 1, (size_t)size, f);
        fclose(f);
        if ((long)nread == size) {
          result->bytes = buf;
          result->bytes_len = (int32_t)size;
          result->status = 0;
        } else {
          free(buf);
          result->status = 4;
        }
      } else {
        fclose(f);
        result->status = 3;
      }
    } else {
      fclose(f);
      result->status = 2;
    }
  }

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

  free(req);
  return 0;
}

MOONBIT_FFI_EXPORT
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
    // Fallback: run synchronously on the calling thread.
    moui_async_image_read_file(req);
  } else {
    CloseHandle(h);
  }
}

// Returns a combined Bytes: [window_id(8)][status(4)][source_len(4)][bytes_len(4)][source][bytes]
// Empty Bytes (length 0) means queue is empty.
MOONBIT_FFI_EXPORT
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

  int32_t header = 24; // 8 + 4 + 4 + 4 + 4
  int32_t total = header + result->source_len + result->bytes_len;
  moonbit_bytes_t out = moonbit_make_bytes(total, 0);
  memcpy(out + 0, &result->window_id, 8);
  memcpy(out + 8, &result->status, 4);
  memcpy(out + 12, &result->source_len, 4);
  memcpy(out + 16, &result->bytes_len, 4);
  memcpy(out + 20, &result->background_io, 4);
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

MOONBIT_FFI_EXPORT
void moui_windows_async_image_spawn_sync(int64_t window_id,
                                         moonbit_bytes_t source_bytes,
                                         int32_t source_len) {
  if (source_bytes == NULL || source_len <= 0) { return; }
  moui_async_image_request_t *req =
    (moui_async_image_request_t *)calloc(1, sizeof(moui_async_image_request_t));
  if (req == NULL) { return; }
  req->window_id = window_id;
  req->source = (char *)malloc((size_t)source_len + 1);
  if (req->source == NULL) { free(req); return; }
  memcpy(req->source, source_bytes, (size_t)source_len);
  req->source[source_len] = '\0';
  req->source_len = source_len;
  req->is_background = 1;
  moui_async_image_read_file(req);
}
