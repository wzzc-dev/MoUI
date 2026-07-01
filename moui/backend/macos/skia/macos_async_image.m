// macOS async image I/O: background file reading via GCD, results drained on
// the main thread. The background thread only uses C stdlib (fopen/fread) and
// malloc — it never touches MoonBit GC objects. The main-thread drain copies
// malloc'd buffers into moonbit_bytes_t and frees the originals.

#include <moonbit.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

typedef struct moui_async_image_result {
  int64_t window_id;
  char *source;
  int32_t source_len;
  uint8_t *bytes;
  int32_t bytes_len;
  int32_t status;
  struct moui_async_image_result *next;
} moui_async_image_result_t;

typedef struct moui_async_image_request {
  int64_t window_id;
  char *source;
  int32_t source_len;
} moui_async_image_request_t;

static moui_async_image_result_t *g_results_head = NULL;
static moui_async_image_result_t *g_results_tail = NULL;
static pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;

static void moui_async_image_read_file(moui_async_image_request_t *req) {
  if (req == NULL) {
    return;
  }
  moui_async_image_result_t *result =
    (moui_async_image_result_t *)calloc(1, sizeof(moui_async_image_result_t));
  if (result == NULL) {
    free(req->source);
    free(req);
    return;
  }
  result->window_id = req->window_id;
  result->source = req->source;
  result->source_len = req->source_len;
  result->bytes = NULL;
  result->bytes_len = 0;
  result->status = 1;
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

  pthread_mutex_lock(&g_mutex);
  if (g_results_tail == NULL) {
    g_results_head = result;
    g_results_tail = result;
  } else {
    g_results_tail->next = result;
    g_results_tail = result;
  }
  pthread_mutex_unlock(&g_mutex);

  free(req);
}

MOONBIT_FFI_EXPORT
void moui_macos_async_image_spawn(int64_t window_id,
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

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    moui_async_image_read_file(req);
  });
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_async_image_take_result(void) {
  pthread_mutex_lock(&g_mutex);
  moui_async_image_result_t *result = g_results_head;
  if (result == NULL) {
    pthread_mutex_unlock(&g_mutex);
    return moonbit_make_bytes(0, 0);
  }
  g_results_head = result->next;
  if (g_results_head == NULL) {
    g_results_tail = NULL;
  }
  pthread_mutex_unlock(&g_mutex);

  int32_t header = 20;
  int32_t total = header + result->source_len + result->bytes_len;
  moonbit_bytes_t out = moonbit_make_bytes(total, 0);
  memcpy(out + 0, &result->window_id, 8);
  memcpy(out + 8, &result->status, 4);
  memcpy(out + 12, &result->source_len, 4);
  memcpy(out + 16, &result->bytes_len, 4);
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
