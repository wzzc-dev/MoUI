#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commdlg.h>
#include <shellapi.h>
#include <shlobj.h>
#include <moonbit.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

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

static int32_t moui_windows_parse_menu_command(const char *bytes, int32_t length, int32_t *offset,
                                               int32_t *enabled, wchar_t **label) {
  if (*offset >= length) {
    return 0;
  }
  char enabled_char = bytes[*offset];
  if (enabled_char != '0' && enabled_char != '1') {
    return 0;
  }
  *enabled = enabled_char == '1' ? 1 : 0;
  *offset += 1;
  if (*offset >= length || bytes[*offset] != ':') {
    return 0;
  }
  *offset += 1;
  int32_t label_length = 0;
  while (*offset < length && bytes[*offset] >= '0' && bytes[*offset] <= '9') {
    int32_t digit = bytes[*offset] - '0';
    if (label_length > (INT32_MAX - digit) / 10) {
      return 0;
    }
    label_length = label_length * 10 + digit;
    *offset += 1;
  }
  if (*offset >= length || bytes[*offset] != ':') {
    return 0;
  }
  *offset += 1;
  if (label_length < 0 || label_length > length - *offset) {
    return 0;
  }
  int32_t wide_len =
      MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, bytes + *offset, label_length, NULL, 0);
  if (wide_len <= 0 && label_length > 0) {
    return 0;
  }
  wchar_t *wide = (wchar_t *)calloc((size_t)wide_len + 1, sizeof(wchar_t));
  if (wide == NULL) {
    return 0;
  }
  if (wide_len > 0) {
    int32_t written =
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, bytes + *offset, label_length, wide, wide_len);
    if (written != wide_len) {
      free(wide);
      return 0;
    }
  }
  wide[wide_len] = L'\0';
  *label = wide;
  *offset += label_length;
  if (*offset < length && bytes[*offset] == '\n') {
    *offset += 1;
  }
  return 1;
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
int32_t moui_windows_accessibility_high_contrast(void) {
  HIGHCONTRASTW value = {0};
  value.cbSize = sizeof(value);
  return SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(value), &value, 0) &&
         (value.dwFlags & HCF_HIGHCONTRASTON) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_accessibility_reduce_motion(void) {
  // Windows exposes animation reduction through SPI_GETCLIENTAREAANIMATION.
  BOOL enabled = TRUE;
  if (!SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &enabled, 0)) {
    return 0;
  }
  return enabled ? 0 : 1;
}

MOONBIT_FFI_EXPORT
double moui_windows_accessibility_text_scale(void) {
  DWORD percent = 100;
  DWORD size = sizeof(percent);
  LSTATUS status = RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Accessibility",
      L"TextScaleFactor",
      RRF_RT_REG_DWORD,
      NULL,
      &percent,
      &size);
  return status == ERROR_SUCCESS && percent >= 10 && percent <= 1000
      ? (double)percent / 100.0
      : 1.0;
}

static const wchar_t *moui_windows_settings_subkey = L"Software\\MoUI";

MOONBIT_FFI_EXPORT
int32_t moui_windows_settings_has_value(moonbit_bytes_t key) {
  wchar_t *name = moui_windows_utf8_to_wide(key);
  if (name == NULL) {
    return 0;
  }
  LSTATUS status = RegGetValueW(
      HKEY_CURRENT_USER, moui_windows_settings_subkey, name,
      RRF_RT_REG_SZ, NULL, NULL, NULL);
  free(name);
  return status == ERROR_SUCCESS ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_settings_read(moonbit_bytes_t key) {
  wchar_t *name = moui_windows_utf8_to_wide(key);
  if (name == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  DWORD byte_count = 0;
  LSTATUS status = RegGetValueW(
      HKEY_CURRENT_USER, moui_windows_settings_subkey, name,
      RRF_RT_REG_SZ, NULL, NULL, &byte_count);
  if (status != ERROR_SUCCESS || byte_count < sizeof(wchar_t)) {
    free(name);
    return moonbit_make_bytes(0, 0);
  }
  wchar_t *value = (wchar_t *)calloc(1, byte_count);
  if (value == NULL) {
    free(name);
    return moonbit_make_bytes(0, 0);
  }
  status = RegGetValueW(
      HKEY_CURRENT_USER, moui_windows_settings_subkey, name,
      RRF_RT_REG_SZ, NULL, value, &byte_count);
  moonbit_bytes_t result = status == ERROR_SUCCESS
      ? moui_windows_wide_to_bytes(value)
      : moonbit_make_bytes(0, 0);
  free(value);
  free(name);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_settings_write(moonbit_bytes_t key, moonbit_bytes_t value) {
  wchar_t *name = moui_windows_utf8_to_wide(key);
  if (name == NULL) {
    return 0;
  }
  wchar_t *text = moui_windows_utf8_to_wide(value);
  if (text == NULL) {
    text = (wchar_t *)calloc(1, sizeof(wchar_t));
  }
  if (text == NULL) {
    free(name);
    return 0;
  }
  HKEY settings_key = NULL;
  LSTATUS status = RegCreateKeyExW(
      HKEY_CURRENT_USER, moui_windows_settings_subkey, 0, NULL, 0,
      KEY_SET_VALUE, NULL, &settings_key, NULL);
  if (status == ERROR_SUCCESS) {
    DWORD byte_count = (DWORD)((wcslen(text) + 1) * sizeof(wchar_t));
    status = RegSetValueExW(
        settings_key, name, 0, REG_SZ, (const BYTE *)text, byte_count);
    RegCloseKey(settings_key);
  }
  free(text);
  free(name);
  return status == ERROR_SUCCESS ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_settings_remove(moonbit_bytes_t key) {
  wchar_t *name = moui_windows_utf8_to_wide(key);
  if (name == NULL) {
    return 0;
  }
  HKEY settings_key = NULL;
  LSTATUS status = RegOpenKeyExW(
      HKEY_CURRENT_USER, moui_windows_settings_subkey, 0,
      KEY_SET_VALUE, &settings_key);
  if (status == ERROR_FILE_NOT_FOUND) {
    free(name);
    return 1;
  }
  if (status == ERROR_SUCCESS) {
    status = RegDeleteValueW(settings_key, name);
    RegCloseKey(settings_key);
  }
  free(name);
  return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND ? 1 : 0;
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

MOONBIT_FFI_EXPORT
int32_t moui_windows_show_menu(moonbit_bytes_t commands) {
  int32_t length = (int32_t)Moonbit_array_length(commands);
  if (length <= 0) {
    return -1;
  }
  const char *bytes = (const char *)commands;
  int32_t offset = 0;
  int32_t index = 0;
  HMENU menu = CreatePopupMenu();
  if (menu == NULL) {
    return -1;
  }

  while (offset < length) {
    int32_t enabled = 0;
    wchar_t *label = NULL;
    if (!moui_windows_parse_menu_command(bytes, length, &offset, &enabled, &label)) {
      DestroyMenu(menu);
      return -1;
    }
    UINT flags = MF_STRING;
    if (!enabled) {
      flags |= MF_GRAYED;
    }
    if (!AppendMenuW(menu, flags, (UINT_PTR)(index + 1), label)) {
      free(label);
      DestroyMenu(menu);
      return -1;
    }
    free(label);
    index += 1;
  }

  if (index == 0) {
    DestroyMenu(menu);
    return -1;
  }

  POINT point;
  if (!GetCursorPos(&point)) {
    point.x = 0;
    point.y = 0;
  }
  HWND hwnd = GetForegroundWindow();
  UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, hwnd, NULL);
  DestroyMenu(menu);
  if (command == 0) {
    return -1;
  }
  return (int32_t)command - 1;
}

#else

#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
int32_t moui_windows_clipboard_has_text(void) {
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_clipboard_read_text(void) {
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_clipboard_write_text(moonbit_bytes_t text) {
  (void)text;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_open_url(moonbit_bytes_t url) {
  (void)url;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_system_theme_is_light(void) {
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_accessibility_high_contrast(void) { return 0; }
MOONBIT_FFI_EXPORT
int32_t moui_windows_accessibility_reduce_motion(void) { return 0; }
MOONBIT_FFI_EXPORT
double moui_windows_accessibility_text_scale(void) { return 1.0; }

MOONBIT_FFI_EXPORT
int32_t moui_windows_settings_has_value(moonbit_bytes_t key) {
  (void)key;
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_settings_read(moonbit_bytes_t key) {
  (void)key;
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_settings_write(moonbit_bytes_t key, moonbit_bytes_t value) {
  (void)key;
  (void)value;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_settings_remove(moonbit_bytes_t key) {
  (void)key;
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_windows_file_dialog(int32_t kind, moonbit_bytes_t title,
                                         moonbit_bytes_t filters,
                                         moonbit_bytes_t default_name) {
  (void)kind;
  (void)title;
  (void)filters;
  (void)default_name;
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t moui_windows_show_menu(moonbit_bytes_t commands) {
  (void)commands;
  return -1;
}

#endif
