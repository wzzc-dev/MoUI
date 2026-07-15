#include "moui_mobile_runtime_v1.h"

#include <stddef.h>

_Static_assert(
    MOUI_MOBILE_RUNTIME_ABI_VERSION_V1 == 1,
    "ABI v1 version changed");
_Static_assert(
    offsetof(moui_mobile_runtime_api_v1, abi_version) == 0,
    "abi_version must lead the table");
_Static_assert(
    offsetof(moui_mobile_runtime_api_v1, struct_size) == sizeof(uint32_t),
    "struct_size must follow abi_version");
_Static_assert(
    offsetof(moui_mobile_runtime_api_v1, capabilities) ==
        sizeof(uint32_t) * 2,
    "capabilities offset changed");
_Static_assert(
    sizeof(moui_mobile_runtime_api_v1) ==
        offsetof(moui_mobile_runtime_api_v1, complete_clipboard) +
            sizeof(((moui_mobile_runtime_api_v1 *)0)->complete_clipboard),
    "v1 table must not contain unreported trailing storage");
_Static_assert(
    MOUI_MOBILE_RUNTIME_API_V1_REQUIRED_SIZE ==
        sizeof(moui_mobile_runtime_api_v1),
    "current v1 table must satisfy its exact required-size floor");
_Static_assert(
    offsetof(moui_mobile_utf8_buffer_v1, status) == 0,
    "owned UTF-8 status must lead the buffer");

int moui_mobile_runtime_v1_header_c_audit(void) {
  const moui_mobile_runtime_api_v1 *api = moui_mobile_get_runtime_api_v1();
  return moui_mobile_runtime_api_v1_is_compatible(api) &&
         api->struct_size == (uint32_t)sizeof(moui_mobile_runtime_api_v1);
}
