#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
void *moui_windows_surface_host_hinstance(void) {
  return (void *)GetModuleHandleW(NULL);
}

MOONBIT_FFI_EXPORT
void *moui_windows_surface_host_hwnd_from_u64(uint64_t hwnd) {
  return (void *)(uintptr_t)hwnd;
}

#else

#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
void *moui_windows_surface_host_hinstance(void) {
  return NULL;
}

MOONBIT_FFI_EXPORT
void *moui_windows_surface_host_hwnd_from_u64(uint64_t hwnd) {
  (void)hwnd;
  return NULL;
}

#endif
