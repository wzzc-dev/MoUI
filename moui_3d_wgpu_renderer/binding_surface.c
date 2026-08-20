#include <moonbit.h>
#include <stdint.h>

#if defined(_WIN32)
#include <windows.h>
#endif

MOONBIT_FFI_EXPORT void *moui_wgpu_ptr_from_u64(uint64_t value) {
  return (void *)(uintptr_t)value;
}

MOONBIT_FFI_EXPORT void *moui_wgpu_windows_hinstance(void) {
#if defined(_WIN32)
  return (void *)GetModuleHandleW(NULL);
#else
  return NULL;
#endif
}
