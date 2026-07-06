#include <moonbit.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifndef _WIN32
#include <sys/stat.h>
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_tools_guidance_readlink(moonbit_bytes_t path, int32_t path_len) {
#ifdef _WIN32
  (void)path;
  (void)path_len;
  return moonbit_make_bytes(0, 0);
#else
  if (path == NULL || path_len <= 0) {
    return moonbit_make_bytes(0, 0);
  }

  char *path_c = (char *)malloc((size_t)path_len + 1);
  if (path_c == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  memcpy(path_c, path, (size_t)path_len);
  path_c[path_len] = '\0';

  struct stat info;
  size_t capacity = 4096;
  if (lstat(path_c, &info) == 0 && info.st_size > 0) {
    capacity = (size_t)info.st_size + 1;
  }

  char *target = (char *)malloc(capacity);
  if (target == NULL) {
    free(path_c);
    return moonbit_make_bytes(0, 0);
  }

  ssize_t length = readlink(path_c, target, capacity);
  free(path_c);
  if (length < 0) {
    free(target);
    return moonbit_make_bytes(0, 0);
  }

  moonbit_bytes_t result = moonbit_make_bytes((int32_t)length, 0);
  memcpy(result, target, (size_t)length);
  free(target);
  return result;
#endif
}
