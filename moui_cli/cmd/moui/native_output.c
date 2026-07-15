#include <moonbit.h>

#include <stdint.h>
#include <stdio.h>

MOONBIT_FFI_EXPORT void moui_cli_write_output(
    int32_t stream,
    moonbit_bytes_t text) {
  FILE *target = stream == 0 ? stdout : stderr;
  fputs((const char *)text, target);
  fflush(target);
}
