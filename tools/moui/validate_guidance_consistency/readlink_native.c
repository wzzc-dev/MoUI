#include <moonbit.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_WIN32)
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_tools_guidance_readlink(const uint8_t *path,
                                             int32_t path_len) {
#if defined(_WIN32)
  (void)path;
  (void)path_len;
  return moonbit_make_bytes(0, 0);
#else
  if (!path || path_len <= 0) {
    return moonbit_make_bytes(0, 0);
  }
  char *path_text = (char *)malloc((size_t)path_len + 1);
  if (!path_text) {
    return moonbit_make_bytes(0, 0);
  }
  memcpy(path_text, path, (size_t)path_len);
  path_text[path_len] = '\0';
  char buffer[4096];
  ssize_t len = readlink(path_text, buffer, sizeof(buffer));
  free(path_text);
  if (len <= 0) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  memcpy(out, buffer, (size_t)len);
  return out;
#endif
}
