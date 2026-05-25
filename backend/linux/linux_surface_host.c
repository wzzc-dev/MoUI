#include <stdint.h>

void *moui_linux_surface_host_ptr_from_u64(uint64_t handle) {
  return (void *)(uintptr_t)handle;
}
