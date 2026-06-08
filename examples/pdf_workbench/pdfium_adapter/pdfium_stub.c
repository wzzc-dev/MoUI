#include <moonbit.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef MOUI_PDFIUM_HAS_PDFIUM
#include <errno.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <direct.h>
#include <windows.h>
#else
#include <pthread.h>
#endif
#include "fpdfview.h"
#endif

static moonbit_bytes_t moui_pdfium_response1(const char *tag, const char *message) {
  size_t tag_len = strlen(tag);
  size_t msg_len = message ? strlen(message) : 0;
  size_t len = tag_len + 1 + msg_len;
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  memcpy(out, tag, tag_len);
  ((char *)out)[tag_len] = '\n';
  if (msg_len > 0) {
    memcpy((char *)out + tag_len + 1, message, msg_len);
  }
  return out;
}

static char *moui_pdfium_strdup(const char *text) {
  if (text == NULL) {
    text = "";
  }
  size_t len = strlen(text);
  char *out = (char *)malloc(len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, text, len);
  out[len] = '\0';
  return out;
}

static char *moui_pdfium_bytes_to_c_string(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len <= 0) {
    return moui_pdfium_strdup("");
  }
  char *out = (char *)malloc((size_t)len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static uint16_t moui_pdfium_read_le16(const uint8_t *bytes) {
  return (uint16_t)bytes[0] | ((uint16_t)bytes[1] << 8);
}

static uint32_t moui_pdfium_read_le32(const uint8_t *bytes) {
  return (uint32_t)bytes[0] |
         ((uint32_t)bytes[1] << 8) |
         ((uint32_t)bytes[2] << 16) |
         ((uint32_t)bytes[3] << 24);
}

MOONBIT_FFI_EXPORT
int32_t moui_pdf_workbench_pdfium_available(void) {
#ifdef MOUI_PDFIUM_HAS_PDFIUM
  return 1;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
int32_t moui_pdf_workbench_bmp_header_ok(moonbit_bytes_t path) {
  char *path_text = moui_pdfium_bytes_to_c_string(path);
  if (!path_text) {
    return 0;
  }
  FILE *file = fopen(path_text, "rb");
  free(path_text);
  if (!file) {
    return 0;
  }
  int b0 = fgetc(file);
  int b1 = fgetc(file);
  fclose(file);
  return b0 == 'B' && b1 == 'M' ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_pdf_workbench_bmp_metadata_ok(
    moonbit_bytes_t path,
    int32_t expected_width,
    int32_t expected_height) {
  if (expected_width <= 0 || expected_height <= 0) {
    return 0;
  }
  char *path_text = moui_pdfium_bytes_to_c_string(path);
  if (!path_text) {
    return 0;
  }
  FILE *file = fopen(path_text, "rb");
  free(path_text);
  if (!file) {
    return 0;
  }

  uint8_t header[54];
  size_t read = fread(header, 1, sizeof(header), file);
  if (read != sizeof(header)) {
    fclose(file);
    return 0;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return 0;
  }
  long actual_file_size = ftell(file);
  fclose(file);
  if (actual_file_size < 54) {
    return 0;
  }

  uint32_t declared_file_size = moui_pdfium_read_le32(header + 2);
  uint32_t pixel_offset = moui_pdfium_read_le32(header + 10);
  uint32_t dib_header_size = moui_pdfium_read_le32(header + 14);
  int32_t width = (int32_t)moui_pdfium_read_le32(header + 18);
  int32_t height = (int32_t)moui_pdfium_read_le32(header + 22);
  uint16_t planes = moui_pdfium_read_le16(header + 26);
  uint16_t bits_per_pixel = moui_pdfium_read_le16(header + 28);
  uint32_t compression = moui_pdfium_read_le32(header + 30);
  uint32_t image_size = moui_pdfium_read_le32(header + 34);
  int32_t absolute_height = height < 0 ? -height : height;
  uint32_t expected_pixel_bytes = (uint32_t)(expected_width * 4 * expected_height);
  uint32_t expected_file_size = 54u + expected_pixel_bytes;

  return header[0] == 'B' &&
         header[1] == 'M' &&
         declared_file_size == (uint32_t)actual_file_size &&
         declared_file_size == expected_file_size &&
         pixel_offset == 54u &&
         dib_header_size == 40u &&
         width == expected_width &&
         absolute_height == expected_height &&
         planes == 1u &&
         bits_per_pixel == 32u &&
         compression == 0u &&
         image_size == expected_pixel_bytes
             ? 1
             : 0;
}

#ifndef MOUI_PDFIUM_HAS_PDFIUM

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_pdf_workbench_pdfium_render_page(
    moonbit_bytes_t path,
    moonbit_bytes_t pdf_bytes,
    int32_t page_number,
    double zoom,
    int32_t dpi,
    int32_t max_pixel_edge,
    moonbit_bytes_t cache_key) {
  (void)path;
  (void)pdf_bytes;
  (void)page_number;
  (void)zoom;
  (void)dpi;
  (void)max_pixel_edge;
  (void)cache_key;
  return moui_pdfium_response1(
      "UNAVAILABLE",
      "PDFium raster service unavailable; set MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=0 or provide MOUI_PDFIUM_INCLUDE/MOUI_PDFIUM_LIB_DIR");
}

#else

#ifdef _WIN32
static INIT_ONCE moui_pdfium_init_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION moui_pdfium_lock;

static BOOL CALLBACK moui_pdfium_init_lock_once(PINIT_ONCE init_once, PVOID parameter, PVOID *context) {
  (void)init_once;
  (void)parameter;
  (void)context;
  InitializeCriticalSection(&moui_pdfium_lock);
  return TRUE;
}

static void moui_pdfium_lock_enter(void) {
  InitOnceExecuteOnce(&moui_pdfium_init_once, moui_pdfium_init_lock_once, NULL, NULL);
  EnterCriticalSection(&moui_pdfium_lock);
}

static void moui_pdfium_lock_leave(void) {
  LeaveCriticalSection(&moui_pdfium_lock);
}
#else
static pthread_mutex_t moui_pdfium_lock = PTHREAD_MUTEX_INITIALIZER;

static void moui_pdfium_lock_enter(void) {
  pthread_mutex_lock(&moui_pdfium_lock);
}

static void moui_pdfium_lock_leave(void) {
  pthread_mutex_unlock(&moui_pdfium_lock);
}
#endif

static int moui_pdfium_library_initialized = 0;

static void moui_pdfium_ensure_library(void) {
  if (moui_pdfium_library_initialized) {
    return;
  }
  FPDF_LIBRARY_CONFIG config;
  memset(&config, 0, sizeof(config));
  config.version = 2;
  FPDF_InitLibraryWithConfig(&config);
  moui_pdfium_library_initialized = 1;
}

static char *moui_pdfium_copy_bytes(moonbit_bytes_t bytes, const char *fallback) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len <= 0) {
    len = fallback ? (int32_t)strlen(fallback) : 0;
    char *out = (char *)calloc((size_t)len + 1, 1);
    if (out && len > 0) {
      memcpy(out, fallback, (size_t)len);
    }
    return out;
  }
  char *out = (char *)malloc((size_t)len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static const char *moui_pdfium_temp_root(void) {
#ifdef _WIN32
  const char *temp = getenv("TEMP");
  if (temp && temp[0]) {
    return temp;
  }
  temp = getenv("TMP");
  if (temp && temp[0]) {
    return temp;
  }
  return ".";
#else
  const char *temp = getenv("TMPDIR");
  if (temp && temp[0]) {
    return temp;
  }
  return "/tmp";
#endif
}

static int moui_pdfium_mkdir(const char *path) {
#ifdef _WIN32
  if (_mkdir(path) == 0 || errno == EEXIST) {
    return 1;
  }
#else
  if (mkdir(path, 0700) == 0 || errno == EEXIST) {
    return 1;
  }
#endif
  return 0;
}

static void moui_pdfium_sanitize(char *text) {
  if (!text || !text[0]) {
    return;
  }
  for (char *cursor = text; *cursor; cursor++) {
    char ch = *cursor;
    int ok = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
             (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' || ch == '.';
    if (!ok) {
      *cursor = '_';
    }
  }
}

static int moui_pdfium_zoom_bucket(double zoom) {
  int bucket = (int)(zoom * 100.0 + 0.5);
  return bucket < 1 ? 1 : bucket;
}

static int32_t moui_pdfium_ceil_to_int(double value) {
  if (value <= 0.0) {
    return 0;
  }
  if (value > 2147483000.0) {
    return 2147483000;
  }
  int32_t truncated = (int32_t)value;
  return ((double)truncated == value) ? truncated : truncated + 1;
}

static char *moui_pdfium_output_path(
    moonbit_bytes_t cache_key,
    int32_t page_number,
    double zoom,
    int32_t width,
    int32_t height,
    char *error,
    size_t error_len) {
  char *doc_key = moui_pdfium_copy_bytes(cache_key, "document");
  if (!doc_key) {
    snprintf(error, error_len, "out of memory while preparing PDFium cache path");
    return NULL;
  }
  char *page_marker = strstr(doc_key, ":page=");
  if (page_marker) {
    *page_marker = '\0';
  }
  if (doc_key[0] == '\0') {
    free(doc_key);
    doc_key = moui_pdfium_strdup("document");
    if (!doc_key) {
      snprintf(error, error_len, "out of memory while preparing PDFium cache key");
      return NULL;
    }
  }
  moui_pdfium_sanitize(doc_key);

  const char *root_temp = moui_pdfium_temp_root();
  const char *sep =
#ifdef _WIN32
      "\\";
#else
      "/";
#endif
  size_t root_len = strlen(root_temp) + strlen(sep) + strlen("moui-pdf-workbench") + 1;
  char *root = (char *)malloc(root_len);
  if (!root) {
    free(doc_key);
    snprintf(error, error_len, "out of memory while preparing PDFium cache root");
    return NULL;
  }
  snprintf(root, root_len, "%s%s%s", root_temp, sep, "moui-pdf-workbench");
  if (!moui_pdfium_mkdir(root)) {
    snprintf(error, error_len, "failed to create PDFium cache root: %s", root);
    free(root);
    free(doc_key);
    return NULL;
  }

  size_t dir_len = strlen(root) + strlen(sep) + strlen(doc_key) + 1;
  char *dir = (char *)malloc(dir_len);
  if (!dir) {
    snprintf(error, error_len, "out of memory while preparing PDFium cache directory");
    free(root);
    free(doc_key);
    return NULL;
  }
  snprintf(dir, dir_len, "%s%s%s", root, sep, doc_key);
  if (!moui_pdfium_mkdir(dir)) {
    snprintf(error, error_len, "failed to create PDFium cache directory: %s", dir);
    free(dir);
    free(root);
    free(doc_key);
    return NULL;
  }

  char filename[128];
  snprintf(
      filename,
      sizeof(filename),
      "page-%d-zoom-%d-%dx%d.bmp",
      page_number,
      moui_pdfium_zoom_bucket(zoom),
      width,
      height);
  size_t path_len = strlen(dir) + strlen(sep) + strlen(filename) + 1;
  char *out = (char *)malloc(path_len);
  if (!out) {
    snprintf(error, error_len, "out of memory while preparing PDFium BMP path");
  } else {
    snprintf(out, path_len, "%s%s%s", dir, sep, filename);
  }
  free(dir);
  free(root);
  free(doc_key);
  return out;
}

static void moui_pdfium_write_le16(FILE *file, uint16_t value) {
  fputc((int)(value & 0xff), file);
  fputc((int)((value >> 8) & 0xff), file);
}

static void moui_pdfium_write_le32(FILE *file, uint32_t value) {
  fputc((int)(value & 0xff), file);
  fputc((int)((value >> 8) & 0xff), file);
  fputc((int)((value >> 16) & 0xff), file);
  fputc((int)((value >> 24) & 0xff), file);
}

static int moui_pdfium_write_bmp(
    const char *path,
    const uint8_t *pixels,
    int32_t width,
    int32_t height,
    int32_t stride) {
  FILE *file = fopen(path, "wb");
  if (!file) {
    return 0;
  }
  uint32_t pixel_bytes = (uint32_t)(stride * height);
  uint32_t file_size = 54u + pixel_bytes;
  fputc('B', file);
  fputc('M', file);
  moui_pdfium_write_le32(file, file_size);
  moui_pdfium_write_le16(file, 0);
  moui_pdfium_write_le16(file, 0);
  moui_pdfium_write_le32(file, 54);
  moui_pdfium_write_le32(file, 40);
  moui_pdfium_write_le32(file, (uint32_t)width);
  moui_pdfium_write_le32(file, (uint32_t)(-height));
  moui_pdfium_write_le16(file, 1);
  moui_pdfium_write_le16(file, 32);
  moui_pdfium_write_le32(file, 0);
  moui_pdfium_write_le32(file, pixel_bytes);
  moui_pdfium_write_le32(file, 2835);
  moui_pdfium_write_le32(file, 2835);
  moui_pdfium_write_le32(file, 0);
  moui_pdfium_write_le32(file, 0);
  size_t written = fwrite(pixels, 1, pixel_bytes, file);
  int close_ok = fclose(file) == 0;
  return written == pixel_bytes && close_ok;
}

static moonbit_bytes_t moui_pdfium_ready_response(
    const char *path,
    int32_t width,
    int32_t height,
    int32_t page_count,
    const char *diagnostic) {
  int needed = snprintf(NULL, 0, "READY\n%s\n%d\n%d\n%d\n%s", path, width, height, page_count, diagnostic);
  if (needed <= 0) {
    return moui_pdfium_response1("FAILED", "failed to format PDFium ready response");
  }
  moonbit_bytes_t out = moonbit_make_bytes(needed, 0);
  snprintf((char *)out, (size_t)needed + 1, "READY\n%s\n%d\n%d\n%d\n%s", path, width, height, page_count, diagnostic);
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_pdf_workbench_pdfium_render_page(
    moonbit_bytes_t path,
    moonbit_bytes_t pdf_bytes,
    int32_t page_number,
    double zoom,
    int32_t dpi,
    int32_t max_pixel_edge,
    moonbit_bytes_t cache_key) {
  (void)path;
  char error[512];
  error[0] = '\0';
  moonbit_bytes_t response = NULL;
  FPDF_DOCUMENT document = NULL;
  FPDF_PAGE page = NULL;
  FPDF_BITMAP bitmap = NULL;
  uint8_t *pixels = NULL;
  char *output_path = NULL;

  if (page_number < 1) {
    return moui_pdfium_response1("FAILED", "page number out of bounds");
  }
  if (zoom <= 0.0) {
    return moui_pdfium_response1("FAILED", "zoom must be positive");
  }
  if (dpi <= 0) {
    dpi = 144;
  }
  if (max_pixel_edge <= 0) {
    max_pixel_edge = 4096;
  }

  int32_t pdf_len = (int32_t)Moonbit_array_length(pdf_bytes);
  if (pdf_len <= 0) {
    return moui_pdfium_response1("FAILED", "empty PDF bytes");
  }

  moui_pdfium_lock_enter();
  moui_pdfium_ensure_library();

  document = FPDF_LoadMemDocument64((const void *)pdf_bytes, (size_t)pdf_len, NULL);
  if (!document) {
    response = moui_pdfium_response1("FAILED", "PDFium failed to load or parse PDF bytes");
    goto cleanup;
  }
  int page_count = FPDF_GetPageCount(document);
  if (page_number > page_count) {
    snprintf(error, sizeof(error), "page number out of range: %d > %d", page_number, page_count);
    response = moui_pdfium_response1("FAILED", error);
    goto cleanup;
  }

  FS_SIZEF page_size;
  if (!FPDF_GetPageSizeByIndexF(document, page_number - 1, &page_size)) {
    response = moui_pdfium_response1("FAILED", "PDFium failed to read page size");
    goto cleanup;
  }
  double scale = ((double)dpi * zoom) / 72.0;
  int32_t width = moui_pdfium_ceil_to_int((double)page_size.width * scale);
  int32_t height = moui_pdfium_ceil_to_int((double)page_size.height * scale);
  int32_t edge = width > height ? width : height;
  if (edge > max_pixel_edge) {
    double factor = (double)max_pixel_edge / (double)edge;
    width = moui_pdfium_ceil_to_int((double)width * factor);
    height = moui_pdfium_ceil_to_int((double)height * factor);
  }
  if (width <= 0 || height <= 0) {
    response = moui_pdfium_response1("FAILED", "PDFium page size produced an empty bitmap");
    goto cleanup;
  }

  int32_t stride = width * 4;
  pixels = (uint8_t *)malloc((size_t)stride * (size_t)height);
  if (!pixels) {
    response = moui_pdfium_response1("FAILED", "out of memory while allocating PDFium bitmap");
    goto cleanup;
  }
  memset(pixels, 0xff, (size_t)stride * (size_t)height);

  bitmap = FPDFBitmap_CreateEx(width, height, FPDFBitmap_BGRA, pixels, stride);
  if (!bitmap) {
    response = moui_pdfium_response1("FAILED", "PDFium failed to create bitmap");
    goto cleanup;
  }
  FPDFBitmap_FillRect(bitmap, 0, 0, width, height, 0xffffffff);

  page = FPDF_LoadPage(document, page_number - 1);
  if (!page) {
    response = moui_pdfium_response1("FAILED", "PDFium failed to load page");
    goto cleanup;
  }
  FPDF_RenderPageBitmap(bitmap, page, 0, 0, width, height, 0, FPDF_ANNOT | FPDF_LCD_TEXT);

  output_path = moui_pdfium_output_path(cache_key, page_number, zoom, width, height, error, sizeof(error));
  if (!output_path) {
    response = moui_pdfium_response1("FAILED", error);
    goto cleanup;
  }
  if (!moui_pdfium_write_bmp(output_path, pixels, width, height, stride)) {
    snprintf(error, sizeof(error), "failed to write PDFium BMP: %s", output_path);
    response = moui_pdfium_response1("FAILED", error);
    goto cleanup;
  }

  char diagnostic[192];
  snprintf(
      diagnostic,
      sizeof(diagnostic),
      "PDFium rendered page %d at %d DPI, zoom bucket %d",
      page_number,
      dpi,
      moui_pdfium_zoom_bucket(zoom));
  response = moui_pdfium_ready_response(output_path, width, height, page_count, diagnostic);

cleanup:
  if (page) {
    FPDF_ClosePage(page);
  }
  if (bitmap) {
    FPDFBitmap_Destroy(bitmap);
  }
  if (document) {
    FPDF_CloseDocument(document);
  }
  moui_pdfium_lock_leave();
  free(output_path);
  free(pixels);
  if (response) {
    return response;
  }
  return moui_pdfium_response1("FAILED", "unknown PDFium raster failure");
}

#endif
