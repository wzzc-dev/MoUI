#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
#include <unknwn.h>
#include <WebView2.h>
#include <wrl.h>
#include <string>
#include <vector>
using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
#endif

typedef void (*moui_webview_event_trampoline_t)(
    void *closure, uint64_t native_window, int32_t kind, moonbit_bytes_t id,
    moonbit_bytes_t url, moonbit_bytes_t detail, int32_t flag);

static moui_webview_event_trampoline_t g_event_trampoline = nullptr;
static void *g_event_closure = nullptr;

static moonbit_bytes_t moui_webview_make_bytes(const char *text) {
  if (text == nullptr) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(text);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(bytes, text, len);
  }
  return bytes;
}

static char *moui_webview_bytes_to_cstr(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  char *text = (char *)calloc((size_t)len + 1, 1);
  if (text == nullptr) {
    return nullptr;
  }
  if (len > 0) {
    memcpy(text, bytes, (size_t)len);
  }
  text[len] = '\0';
  return text;
}

static void moui_windows_webview_emit_utf8(uint64_t hwnd, int32_t kind,
                                           const char *id, const char *url,
                                           const char *detail, int32_t flag) {
  if (g_event_trampoline == nullptr || g_event_closure == nullptr) {
    return;
  }
  g_event_trampoline(g_event_closure, hwnd, kind, moui_webview_make_bytes(id),
                     moui_webview_make_bytes(url),
                     moui_webview_make_bytes(detail), flag);
}

#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
static std::wstring mb_bytes_to_wide(moonbit_bytes_t bytes) {
  int32_t len = (int32_t)Moonbit_array_length(bytes);
  if (len <= 0) {
    return L"";
  }
  int wide_len = MultiByteToWideChar(CP_UTF8, 0, (LPCCH)bytes, len, nullptr, 0);
  if (wide_len <= 0) {
    return L"";
  }
  std::wstring out((size_t)wide_len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, (LPCCH)bytes, len, &out[0], wide_len);
  return out;
}

static std::string wide_to_utf8(const wchar_t *wide) {
  if (wide == nullptr || wide[0] == L'\0') {
    return "";
  }
  int len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 0) {
    return "";
  }
  std::string out((size_t)len - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, &out[0], len, nullptr, nullptr);
  return out;
}

static std::string wide_to_utf8(const std::wstring &wide) {
  return wide_to_utf8(wide.c_str());
}

struct MOUWindowsWebView {
  HWND parent = nullptr;
  std::wstring id;
  std::wstring desired_url;
  std::wstring current_url;
  std::wstring title;
  int32_t policy = 0;
  bool seen = false;
  bool creating = false;
  bool allow_next_navigation = false;
  bool navigation_pending = false;
  ComPtr<ICoreWebView2Controller> controller;
  ComPtr<ICoreWebView2> webview;
};

static std::vector<MOUWindowsWebView *> g_views;
static ComPtr<ICoreWebView2Environment> g_environment;
static bool g_environment_creating = false;
static bool g_environment_failed = false;
static HRESULT g_environment_failure = S_OK;

static MOUWindowsWebView *find_view(HWND parent, const std::wstring &id) {
  for (auto *view : g_views) {
    if (view->parent == parent && view->id == id) {
      return view;
    }
  }
  return nullptr;
}

static void emit_wide(HWND parent, int32_t kind, const std::wstring &id,
                      const std::wstring &url, const std::wstring &detail,
                      int32_t flag) {
  std::string id8 = wide_to_utf8(id);
  std::string url8 = wide_to_utf8(url);
  std::string detail8 = wide_to_utf8(detail);
  moui_windows_webview_emit_utf8((uint64_t)(uintptr_t)parent, kind, id8.c_str(),
                                 url8.c_str(), detail8.c_str(), flag);
}

static std::wstring webview2_hresult_detail(const wchar_t *message,
                                            HRESULT result) {
  wchar_t code[32];
  swprintf_s(code, L"0x%08X", (unsigned int)result);
  std::wstring detail(message);
  detail += L"; HRESULT=";
  detail += code;
  return detail;
}

static bool webview2_runtime_available(void) {
  LPWSTR version = nullptr;
  HRESULT result = GetAvailableCoreWebView2BrowserVersionString(nullptr, &version);
  if (version != nullptr) {
    CoTaskMemFree(version);
  }
  return SUCCEEDED(result);
}

static void emit_environment_failure(MOUWindowsWebView *view, HRESULT result) {
  if (view == nullptr) {
    return;
  }
  view->creating = false;
  view->navigation_pending = false;
  emit_wide(
      view->parent, 4, view->id, view->desired_url,
      webview2_hresult_detail(L"WebView2 environment creation failed", result),
      (int32_t)result);
}

static wchar_t lower_ascii_wide(wchar_t ch) {
  if (ch >= L'A' && ch <= L'Z') {
    return ch - L'A' + L'a';
  }
  return ch;
}

static bool starts_with_scheme(const std::wstring &url,
                               const wchar_t *scheme) {
  std::wstring scheme_text(scheme);
  if (url.size() < scheme_text.size()) {
    return false;
  }
  for (size_t index = 0; index < scheme_text.size(); ++index) {
    if (lower_ascii_wide(url[index]) != scheme_text[index]) {
      return false;
    }
  }
  return true;
}

static bool webview_policy_allows(int32_t policy, const std::wstring &url) {
  if (policy == 2) {
    return true;
  }
  if (starts_with_scheme(url, L"http:") || starts_with_scheme(url, L"https:")) {
    return true;
  }
  return policy == 0 && starts_with_scheme(url, L"file:");
}

static void emit_policy_blocked(MOUWindowsWebView *view,
                                const std::wstring &url) {
  if (view == nullptr) {
    return;
  }
  emit_wide(view->parent, 4, view->id, url,
            L"WebView navigation policy blocked URL", 0);
}

static double window_dpi_scale(HWND hwnd) {
  if (hwnd == nullptr) {
    return 1.0;
  }
  HMODULE user32 = GetModuleHandleW(L"user32.dll");
  if (user32 != nullptr) {
    typedef UINT(WINAPI *GetDpiForWindowFn)(HWND);
    auto get_dpi_for_window =
        (GetDpiForWindowFn)GetProcAddress(user32, "GetDpiForWindow");
    if (get_dpi_for_window != nullptr) {
      UINT dpi = get_dpi_for_window(hwnd);
      if (dpi > 0) {
        return (double)dpi / 96.0;
      }
    }
  }
  HDC dc = GetDC(hwnd);
  if (dc != nullptr) {
    int dpi = GetDeviceCaps(dc, LOGPIXELSX);
    ReleaseDC(hwnd, dc);
    if (dpi > 0) {
      return (double)dpi / 96.0;
    }
  }
  return 1.0;
}

static void apply_bounds(MOUWindowsWebView *view, double x, double y,
                         double width, double height) {
  if (view == nullptr || !view->controller) {
    return;
  }
  double scale = window_dpi_scale(view->parent);
  x *= scale;
  y *= scale;
  width *= scale;
  height *= scale;
  RECT bounds;
  bounds.left = (LONG)x;
  bounds.top = (LONG)y;
  bounds.right = (LONG)(x + width);
  bounds.bottom = (LONG)(y + height);
  view->controller->put_Bounds(bounds);
  view->controller->put_IsVisible(width > 0.0 && height > 0.0);
}

static BOOL CALLBACK find_webview_child(HWND child, LPARAM data) {
  HWND *result = reinterpret_cast<HWND *>(data);
  if (IsWindowVisible(child) && result != nullptr && *result == nullptr) {
    *result = child;
  }
  return *result == nullptr;
}

static void sync_overlay_region(HWND parent, BOOL has_bounds, double x,
                                 double y, double width, double height) {
  if (parent == nullptr) return;
  // DrawCommand::bounds() inflates overlay paint rects by 1.0 logical px for
  // damage safety (moui/core/damage.mbt). The mask must expose exactly the
  // painted overlay pixels, so deflate back before DPI scaling.
  x += 1.0;
  y += 1.0;
  width -= 2.0;
  height -= 2.0;
  double scale = window_dpi_scale(parent);
  x *= scale;
  y *= scale;
  width *= scale;
  height *= scale;
  HWND child = nullptr;
  EnumChildWindows(parent, find_webview_child, reinterpret_cast<LPARAM>(&child));
  if (child == nullptr) return;
  RECT client;
  if (!GetClientRect(child, &client)) return;
  HRGN region = CreateRectRgn(0, 0, client.right, client.bottom);
  if (has_bounds && width > 0.0 && height > 0.0) {
    const bool small_floating_overlay = width < 96.0 * scale && height < 96.0 * scale;
    HRGN hole = small_floating_overlay
                    ? CreateEllipticRgn((int)x, (int)y, (int)(x + width),
                                       (int)(y + height))
                    : CreateRectRgn((int)x, (int)y, (int)(x + width),
                                    (int)(y + height));
    CombineRgn(region, region, hole, RGN_DIFF);
    DeleteObject(hole);
  }
  SetWindowRgn(child, region, TRUE);
}

static void install_handlers(MOUWindowsWebView *view) {
  if (view == nullptr || !view->webview) {
    return;
  }
  EventRegistrationToken token;
  view->webview->add_NavigationStarting(
      Callback<ICoreWebView2NavigationStartingEventHandler>(
          [view](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args)
              -> HRESULT {
            LPWSTR uri = nullptr;
            args->get_Uri(&uri);
            std::wstring url = uri ? uri : L"";
            CoTaskMemFree(uri);
            if (!webview_policy_allows(view->policy, url)) {
              args->put_Cancel(TRUE);
              view->allow_next_navigation = false;
              view->navigation_pending = false;
              emit_policy_blocked(view, url);
              return S_OK;
            }
            if (view->allow_next_navigation) {
              // Keep allow_next_navigation true for the entire navigation
              // sequence (including HTTP redirects). Only navigate_controlled
              // resets it when starting a new sequence.
              emit_wide(view->parent, 1, view->id, url, L"", 0);
            } else {
              args->put_Cancel(TRUE);
              emit_wide(view->parent, 0, view->id, url, L"", 0);
            }
            return S_OK;
          })
          .Get(),
      &token);
  view->webview->add_SourceChanged(
      Callback<ICoreWebView2SourceChangedEventHandler>(
          [view](ICoreWebView2 *sender, ICoreWebView2SourceChangedEventArgs *)
              -> HRESULT {
            LPWSTR source = nullptr;
            sender->get_Source(&source);
            std::wstring url = source ? source : L"";
            CoTaskMemFree(source);
            view->current_url = url;
            // Do NOT clear navigation_pending here — only navigate_controlled
            // manages it. SourceChanged fires mid-navigation (e.g. on redirect)
            // and clearing the flag here would cause navigate_controlled to
            // call Navigate() again, restarting the in-progress navigation.
            emit_wide(view->parent, 2, view->id, url, L"", 0);
            return S_OK;
          })
          .Get(),
      &token);
  view->webview->add_NavigationCompleted(
      Callback<ICoreWebView2NavigationCompletedEventHandler>(
          [view](ICoreWebView2 *, ICoreWebView2NavigationCompletedEventArgs *args)
              -> HRESULT {
            view->navigation_pending = false;
            view->allow_next_navigation = false;
            BOOL success = FALSE;
            args->get_IsSuccess(&success);
            if (success) {
              emit_wide(view->parent, 3, view->id, view->current_url, L"", 0);
            } else {
              COREWEBVIEW2_WEB_ERROR_STATUS status;
              args->get_WebErrorStatus(&status);
              emit_wide(view->parent, 4, view->id, view->current_url,
                        L"WebView2 navigation failed", (int32_t)status);
            }
            return S_OK;
          })
          .Get(),
      &token);
  view->webview->add_DocumentTitleChanged(
      Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
          [view](ICoreWebView2 *sender, IUnknown *) -> HRESULT {
            LPWSTR title = nullptr;
            sender->get_DocumentTitle(&title);
            std::wstring text = title ? title : L"";
            CoTaskMemFree(title);
            emit_wide(view->parent, 5, view->id, L"", text, 0);
            return S_OK;
          })
          .Get(),
      &token);
  view->webview->add_HistoryChanged(
      Callback<ICoreWebView2HistoryChangedEventHandler>(
          [view](ICoreWebView2 *sender, IUnknown *) -> HRESULT {
            BOOL can_go_back = FALSE;
            BOOL can_go_forward = FALSE;
            sender->get_CanGoBack(&can_go_back);
            sender->get_CanGoForward(&can_go_forward);
            emit_wide(view->parent, 6, view->id, L"", L"", can_go_back ? 1 : 0);
            emit_wide(view->parent, 7, view->id, L"", L"",
                      can_go_forward ? 1 : 0);
            return S_OK;
          })
          .Get(),
      &token);
}

static void navigate_controlled(MOUWindowsWebView *view, const std::wstring &url) {
  if (view == nullptr || url.empty()) {
    return;
  }
  if (!webview_policy_allows(view->policy, url)) {
    emit_policy_blocked(view, url);
    return;
  }
  bool desired_changed = view->desired_url != url;
  view->desired_url = url;
  if (!view->webview) {
    return;
  }
  if (desired_changed || (!view->navigation_pending && view->current_url != url)) {
    view->allow_next_navigation = true;
    view->navigation_pending = true;
    view->webview->Navigate(url.c_str());
  }
}

static void ensure_environment();

static void create_controller(MOUWindowsWebView *view) {
  if (view == nullptr || view->creating || view->controller || !g_environment) {
    return;
  }
  view->creating = true;
  g_environment->CreateCoreWebView2Controller(
      view->parent,
      Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
          [view](HRESULT result, ICoreWebView2Controller *controller) -> HRESULT {
            view->creating = false;
            if (FAILED(result) || controller == nullptr) {
              emit_wide(view->parent, 4, view->id, view->desired_url,
                        L"WebView2 controller creation failed", (int32_t)result);
              return S_OK;
            }
            view->controller = controller;
            view->controller->get_CoreWebView2(&view->webview);
            install_handlers(view);
            navigate_controlled(view, view->desired_url);
            return S_OK;
          })
          .Get());
}

static void ensure_environment() {
  if (g_environment || g_environment_creating || g_environment_failed) {
    return;
  }
  if (!webview2_runtime_available()) {
    g_environment_failed = true;
    g_environment_failure = HRESULT_FROM_WIN32(ERROR_PRODUCT_UNINSTALLED);
    for (auto *view : g_views) {
      emit_environment_failure(view, g_environment_failure);
    }
    return;
  }
  g_environment_creating = true;
  CreateCoreWebView2EnvironmentWithOptions(
      nullptr, nullptr, nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [](HRESULT result, ICoreWebView2Environment *environment) -> HRESULT {
            g_environment_creating = false;
            if (FAILED(result) || environment == nullptr) {
              g_environment_failed = true;
              g_environment_failure = result;
              for (auto *view : g_views) {
                emit_environment_failure(view, result);
              }
              return S_OK;
            }
            g_environment = environment;
            for (auto *view : g_views) {
              create_controller(view);
            }
            return S_OK;
          })
          .Get());
}

static MOUWindowsWebView *ensure_view(HWND parent, const std::wstring &id) {
  MOUWindowsWebView *view = find_view(parent, id);
  if (view != nullptr) {
    return view;
  }
  view = new MOUWindowsWebView();
  view->parent = parent;
  view->id = id;
  g_views.push_back(view);
  ensure_environment();
  if (g_environment_failed) {
    emit_environment_failure(view, g_environment_failure);
  }
  create_controller(view);
  return view;
}
#endif

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_install_event_callback(
    moui_webview_event_trampoline_t trampoline, void *closure) {
  if (g_event_closure != nullptr) {
    moonbit_decref(g_event_closure);
  }
  g_event_trampoline = trampoline;
  g_event_closure = closure;
}

extern "C" MOONBIT_FFI_EXPORT
int32_t moui_windows_webview_available(void) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  return webview2_runtime_available() ? 1 : 0;
#else
  return 0;
#endif
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_platform_views_begin(uint64_t hwnd) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  for (auto *view : g_views) {
    if (view->parent == (HWND)(uintptr_t)hwnd) {
      view->seen = false;
    }
  }
#else
  (void)hwnd;
#endif
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_sync(uint64_t hwnd, moonbit_bytes_t id,
                               moonbit_bytes_t url, moonbit_bytes_t title,
                               int32_t policy, double x, double y,
                               double width, double height) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  (void)policy;
  MOUWindowsWebView *view =
      ensure_view((HWND)(uintptr_t)hwnd, mb_bytes_to_wide(id));
  view->seen = true;
  view->policy = policy;
  view->title = mb_bytes_to_wide(title);
  apply_bounds(view, x, y, width, height);
  navigate_controlled(view, mb_bytes_to_wide(url));
#else
  (void)hwnd;
  (void)id;
  (void)url;
  (void)title;
  (void)policy;
  (void)x;
  (void)y;
  (void)width;
  (void)height;
#endif
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_sync_overlay_mask(uint64_t hwnd, int32_t has_bounds,
                                             double x, double y, double width,
                                             double height) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  sync_overlay_region((HWND)(uintptr_t)hwnd, has_bounds != 0, x, y, width,
                      height);
#else
  (void)hwnd;
  (void)has_bounds;
  (void)x;
  (void)y;
  (void)width;
  (void)height;
#endif
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_platform_views_end(uint64_t hwnd) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  for (auto *view : g_views) {
    if (view->parent == (HWND)(uintptr_t)hwnd && !view->seen &&
        view->controller) {
      view->controller->put_IsVisible(FALSE);
    }
  }
#else
  (void)hwnd;
#endif
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_platform_views_dispose(uint64_t hwnd) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  std::vector<MOUWindowsWebView *> remaining;
  for (auto *view : g_views) {
    if (view->parent == (HWND)(uintptr_t)hwnd) {
      if (view->controller) {
        view->controller->Close();
      }
      delete view;
    } else {
      remaining.push_back(view);
    }
  }
  g_views.swap(remaining);
#else
  (void)hwnd;
#endif
}

extern "C" MOONBIT_FFI_EXPORT
void moui_windows_webview_command(uint64_t hwnd, moonbit_bytes_t id,
                                  int32_t command, moonbit_bytes_t text,
                                  moonbit_bytes_t detail) {
#if defined(_WIN32) && defined(MOUI_WINDOWS_ENABLE_WEBVIEW2)
  MOUWindowsWebView *view =
      find_view((HWND)(uintptr_t)hwnd, mb_bytes_to_wide(id));
  if (view == nullptr || !view->webview) {
    return;
  }
  switch (command) {
  case 0:
    navigate_controlled(view, mb_bytes_to_wide(text));
    break;
  case 1:
    view->webview->Reload();
    break;
  case 2:
    view->webview->Stop();
    break;
  case 3:
    view->webview->GoBack();
    break;
  case 4:
    view->webview->GoForward();
    break;
  case 5: {
    std::wstring script = mb_bytes_to_wide(text);
    std::wstring request_id = mb_bytes_to_wide(detail);
    view->webview->ExecuteScript(
        script.c_str(),
        Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
            [view, request_id](HRESULT result, LPCWSTR value) -> HRESULT {
              std::wstring output = SUCCEEDED(result) && value ? value : L"";
              emit_wide(view->parent, 8, view->id, request_id, output,
                        (int32_t)result);
              return S_OK;
            })
            .Get());
    break;
  }
  default:
    break;
  }
#else
  (void)hwnd;
  (void)text;
  (void)detail;
  if (command == 0) {
    char *id_text = moui_webview_bytes_to_cstr(id);
    moui_windows_webview_emit_utf8(
        hwnd, 4, id_text ? id_text : "", "",
        "Windows WebView2 native bridge is unavailable", 0);
    free(id_text);
  } else {
    (void)id;
  }
#endif
}
