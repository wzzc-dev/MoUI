#include <moonbit.h>

#include <stdio.h>
#include <stdlib.h>
MOONBIT_FFI_EXPORT
void skia_mbt_native_smoke_mark(moonbit_bytes_t message) {
  const char* enabled = getenv("SKIA_MBT_NATIVE_SMOKE_TRACE");
  if (enabled == NULL || enabled[0] == '\0') {
    return;
  }
  if (message == NULL) {
    return;
  }
  int length = Moonbit_array_length(message);
  fputs("native smoke mark: ", stderr);
  fwrite(message, 1, length, stderr);
  fputc('\n', stderr);
  fflush(stderr);
}
