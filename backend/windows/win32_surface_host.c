#ifndef _WIN32
#error "win32_surface_host.c is only for Windows"
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <shlobj.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

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

static wchar_t *moui_windows_utf8_to_wide(moonbit_bytes_t text) {
  int32_t text_len = (int32_t)Moonbit_array_length(text);
  if (text_len <= 0) {
    return NULL;
  }
  int32_t wide_len = MultiByteToWideChar(CP_UTF8, 0, (LPCCH)text, text_len, NULL, 0);
  if (wide_len <= 0) {
    return NULL;
  }
  wchar_t *wide = (wchar_t *)calloc((size_t)wide_len + 1, sizeof(wchar_t));
  if (wide == NULL) {
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, 0, (LPCCH)text, text_len, wide, wide_len) <= 0) {
    free(wide);
    return NULL;
  }
  wide[wide_len] = L'\0';
  return wide;
}

static moonbit_bytes_t moui_windows_wide_to_bytes(const wchar_t *wide) {
  if (wide == NULL || wide[0] == L'\0') {
    return moonbit_make_bytes(0, 0);
  }
  int32_t utf8_len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, NULL, 0, NULL, NULL);
  if (utf8_len <= 0) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(utf8_len - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, (char *)bytes, utf8_len, NULL, NULL);
  return bytes;
}

static wchar_t *moui_windows_filter_spec(moonbit_bytes_t filters) {
  wchar_t *patterns = moui_windows_utf8_to_wide(filters);
  if (patterns == NULL || patterns[0] == L'\0') {
    free(patterns);
    return NULL;
  }
  for (wchar_t *cursor = patterns; *cursor != L'\0'; cursor++) {
    if (*cursor == L'\n') {
      *cursor = L';';
    }
  }
  const wchar_t supported_label[] = L"Supported Files";
  const wchar_t all_label[] = L"All Files";
  const wchar_t all_pattern[] = L"*.*";
  size_t total =
      wcslen(supported_label) + 1 +
      wcslen(patterns) + 1 +
      wcslen(all_label) + 1 +
      wcslen(all_pattern) + 1 +
      1;
  wchar_t *filter = (wchar_t *)calloc(total, sizeof(wchar_t));
  if (filter == NULL) {
    free(patterns);
    return NULL;
  }
  wchar_t *cursor = filter;
  wcscpy(cursor, supported_label);
  cursor += wcslen(cursor) + 1;
  wcscpy(cursor, patterns);
  cursor += wcslen(cursor) + 1;
  wcscpy(cursor, all_label);
  cursor += wcslen(cursor) + 1;
  wcscpy(cursor, all_pattern);
  free(patterns);
  return filter;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_open_url(moonbit_bytes_t url) {
  wchar_t *wide = moui_windows_utf8_to_wide(url);
  if (wide == NULL) {
    return 0;
  }
  HINSTANCE result = ShellExecuteW(NULL, L"open", wide, NULL, NULL, SW_SHOWNORMAL);
  free(wide);
  return ((uintptr_t)result > 32) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_system_theme_is_light(void) {
  DWORD value = 1;
  DWORD value_size = sizeof(value);
  LSTATUS status = RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"AppsUseLightTheme",
      RRF_RT_REG_DWORD,
      NULL,
      &value,
      &value_size);
  if (status != ERROR_SUCCESS) {
    return 1;
  }
  return value != 0 ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_file_dialog(int32_t kind, moonbit_bytes_t title, moonbit_bytes_t filters,
                                         moonbit_bytes_t default_name) {
  wchar_t *title_wide = moui_windows_utf8_to_wide(title);
  wchar_t *default_wide = moui_windows_utf8_to_wide(default_name);
  wchar_t *filter_wide = moui_windows_filter_spec(filters);

  if (kind == 2) {
    BROWSEINFOW browse;
    ZeroMemory(&browse, sizeof(browse));
    browse.hwndOwner = NULL;
    browse.lpszTitle = title_wide;
    browse.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    PIDLIST_ABSOLUTE pidl = SHBrowseForFolderW(&browse);
    wchar_t path[MAX_PATH];
    path[0] = L'\0';
    if (pidl != NULL) {
      SHGetPathFromIDListW(pidl, path);
      CoTaskMemFree(pidl);
    }
    free(title_wide);
    free(default_wide);
    free(filter_wide);
    return moui_windows_wide_to_bytes(path);
  }

  wchar_t file_path[4096];
  ZeroMemory(file_path, sizeof(file_path));
  if (default_wide != NULL) {
    wcsncpy(file_path, default_wide, 4095);
    file_path[4095] = L'\0';
  }

  static const wchar_t all_files_filter[] = L"All Files\0*.*\0\0";
  OPENFILENAMEW ofn;
  ZeroMemory(&ofn, sizeof(ofn));
  ofn.lStructSize = sizeof(ofn);
  ofn.hwndOwner = NULL;
  ofn.lpstrFile = file_path;
  ofn.nMaxFile = 4096;
  ofn.lpstrTitle = title_wide;
  ofn.lpstrFilter = filter_wide != NULL ? filter_wide : all_files_filter;
  ofn.Flags = OFN_NOCHANGEDIR | OFN_PATHMUSTEXIST;

  BOOL ok = FALSE;
  if (kind == 1) {
    ofn.Flags |= OFN_OVERWRITEPROMPT;
    ok = GetSaveFileNameW(&ofn);
  } else {
    ofn.Flags |= OFN_FILEMUSTEXIST;
    ok = GetOpenFileNameW(&ofn);
  }

  moonbit_bytes_t result = ok ? moui_windows_wide_to_bytes(file_path) : moonbit_make_bytes(0, 0);
  free(title_wide);
  free(default_wide);
  free(filter_wide);
  return result;
}
