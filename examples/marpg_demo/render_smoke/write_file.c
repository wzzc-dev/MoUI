#include <moonbit.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Writes the smoke's BMP payload. The smoke runs on native macOS only and this
// package declares native as its sole target, so no _WIN32 branch is needed.
MOONBIT_FFI_EXPORT
int32_t marpg_smoke_write_file(moonbit_bytes_t path, int32_t path_len,
                               moonbit_bytes_t data, int32_t data_len) {
  if (path == NULL || path_len <= 0 || data == NULL || data_len < 0) {
    return 1;
  }
  char *path_c = (char *)malloc((size_t)path_len + 1);
  if (path_c == NULL) {
    return 2;
  }
  memcpy(path_c, path, (size_t)path_len);
  path_c[path_len] = '\0';

  FILE *file = fopen(path_c, "wb");
  free(path_c);
  if (file == NULL) {
    return 3;
  }
  size_t written = fwrite(data, 1, (size_t)data_len, file);
  int closed = fclose(file);
  if (written != (size_t)data_len || closed != 0) {
    return 4;
  }
  return 0;
}
