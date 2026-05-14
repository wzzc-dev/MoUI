#ifndef _WIN32
#error "win32_surface_host.c is only for Windows"
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>

void *moui_windows_surface_host_hinstance(void) {
  return (void *)GetModuleHandleW(NULL);
}

void *moui_windows_surface_host_hwnd_from_u64(uint64_t hwnd) {
  return (void *)(uintptr_t)hwnd;
}
