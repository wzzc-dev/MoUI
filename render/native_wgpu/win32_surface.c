#ifndef _WIN32
#error "win32_surface.c is only for Windows"
#endif

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <moonbit.h>
#include <stdint.h>
#include <windows.h>

MOONBIT_FFI_EXPORT
void *moui_win32_hinstance(void) {
  return (void *)GetModuleHandleW(NULL);
}

MOONBIT_FFI_EXPORT
void *moui_win32_hwnd_from_u64(uint64_t hwnd) {
  return (void *)(uintptr_t)hwnd;
}
