#ifndef _WIN32
#error "win32_surface_host.c is only for Windows"
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

MOONBIT_FFI_EXPORT
void *moui_windows_surface_host_hinstance(void) {
  return (void *)GetModuleHandleW(NULL);
}

MOONBIT_FFI_EXPORT
void *moui_windows_surface_host_hwnd_from_u64(uint64_t hwnd) {
  return (void *)(uintptr_t)hwnd;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_clipboard_has_text(void) {
  return IsClipboardFormatAvailable(CF_UNICODETEXT) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_clipboard_read_text(void) {
  if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    return moonbit_make_bytes(0, 0);
  }
  if (!OpenClipboard(NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  HANDLE handle = GetClipboardData(CF_UNICODETEXT);
  if (handle == NULL) {
    CloseClipboard();
    return moonbit_make_bytes(0, 0);
  }
  const wchar_t *wide = (const wchar_t *)GlobalLock(handle);
  if (wide == NULL) {
    CloseClipboard();
    return moonbit_make_bytes(0, 0);
  }
  int32_t utf8_len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
  if (utf8_len <= 0) {
    GlobalUnlock(handle);
    CloseClipboard();
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(utf8_len - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, (char *)bytes, utf8_len, NULL, NULL);
  GlobalUnlock(handle);
  CloseClipboard();
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_clipboard_write_text(moonbit_bytes_t text) {
  int32_t text_len = (int32_t)Moonbit_array_length(text);
  int32_t wide_len = MultiByteToWideChar(CP_UTF8, 0, (LPCCH)text, text_len, NULL, 0);
  if (wide_len < 0) {
    return 0;
  }
  HGLOBAL global = GlobalAlloc(GMEM_MOVEABLE, (wide_len + 1) * sizeof(wchar_t));
  if (global == NULL) {
    return 0;
  }
  wchar_t *wide = (wchar_t *)GlobalLock(global);
  if (wide == NULL) {
    GlobalFree(global);
    return 0;
  }
  if (wide_len > 0) {
    MultiByteToWideChar(CP_UTF8, 0, (LPCCH)text, text_len, wide, wide_len);
  }
  wide[wide_len] = L'\0';
  GlobalUnlock(global);
  if (!OpenClipboard(NULL)) {
    GlobalFree(global);
    return 0;
  }
  EmptyClipboard();
  if (SetClipboardData(CF_UNICODETEXT, global) == NULL) {
    CloseClipboard();
    GlobalFree(global);
    return 0;
  }
  CloseClipboard();
  return 1;
}
