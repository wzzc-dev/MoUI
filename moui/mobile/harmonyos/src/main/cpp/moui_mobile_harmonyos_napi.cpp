#include "moui_mobile_runtime_v1.h"

#include <chrono>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <limits>
#include <mutex>
#include <string>
#include <vector>

#ifndef MOUI_MOBILE_APP_ARG
#define MOUI_MOBILE_APP_ARG "moui-mobile-harmonyos"
#endif

#ifndef MOUI_MOBILE_APP_ID
#define MOUI_MOBILE_APP_ID "unknown"
#endif

#ifndef MOUI_MOBILE_RENDERER_REQUESTED
#define MOUI_MOBILE_RENDERER_REQUESTED "auto"
#endif

#ifndef MOUI_MOBILE_RENDERER_SELECTED
#define MOUI_MOBILE_RENDERER_SELECTED MOUI_MOBILE_RENDERER_REQUESTED
#endif

#ifndef MOUI_MOBILE_SMOKE_ATTACH_SURFACE
#define MOUI_MOBILE_SMOKE_ATTACH_SURFACE                                       \
  moui_mobile_harmonyos_attach_surface_for_smoke
#endif

#ifndef MOUI_MOBILE_SMOKE_RENDER_FRAME
#define MOUI_MOBILE_SMOKE_RENDER_FRAME                                         \
  moui_mobile_harmonyos_render_frame_for_smoke
#endif

#if defined(__has_include)
#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define MOUI_HARMONYOS_HAS_HILOG 1
#endif
#endif

#if defined(MOUI_HARMONYOS_ENABLE_NAPI) && defined(__has_include)
#if __has_include(<napi/native_api.h>)
#include <napi/native_api.h>
#define MOUI_HARMONYOS_HAS_NAPI 1
#endif
#endif

#if defined(MOUI_HARMONYOS_ENABLE_XCOMPONENT) && defined(__has_include)
#if __has_include(<ace/xcomponent/native_interface_xcomponent.h>)
#include <ace/xcomponent/native_interface_xcomponent.h>
#define MOUI_HARMONYOS_HAS_XCOMPONENT 1
#endif
#endif

#if defined(__has_include)
#if __has_include(<window_manager/oh_display_manager.h>)
#include <window_manager/oh_display_manager.h>
#define MOUI_HARMONYOS_HAS_DISPLAY_MANAGER 1
#endif
#endif

namespace {

constexpr unsigned int k_log_domain = 0x4D4F;
constexpr const char *k_log_tag = "MoUIHarmony";
constexpr double k_touch_slop = 8.0;

const moui_mobile_runtime_api_v1 *g_runtime_api = nullptr;
std::once_flag g_runtime_once;
std::recursive_mutex g_runtime_call_mutex;
using RuntimeCallLock = std::lock_guard<std::recursive_mutex>;
int32_t g_initialize_result = MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1;
uint64_t g_surface_handle = 0;
int32_t g_width = 1;
int32_t g_height = 1;
double g_scale = 1.0;

void log_info(const char *fmt, ...) {
#if defined(MOUI_HARMONYOS_HAS_HILOG)
  va_list args;
  va_start(args, fmt);
  OH_LOG_VPrint(LOG_APP, LOG_INFO, k_log_domain, k_log_tag, fmt, args);
  va_end(args);
#else
  (void)fmt;
#endif
}

void log_warn(const char *fmt, ...) {
#if defined(MOUI_HARMONYOS_HAS_HILOG)
  va_list args;
  va_start(args, fmt);
  OH_LOG_VPrint(LOG_APP, LOG_WARN, k_log_domain, k_log_tag, fmt, args);
  va_end(args);
#else
  (void)fmt;
#endif
}

class OwnedUtf8Buffer {
public:
  explicit OwnedUtf8Buffer(moui_mobile_utf8_buffer_v1 value) : value_(value) {}

  OwnedUtf8Buffer(const OwnedUtf8Buffer &) = delete;
  OwnedUtf8Buffer &operator=(const OwnedUtf8Buffer &) = delete;

  ~OwnedUtf8Buffer() {
    if (value_.release != nullptr) {
      value_.release(value_.release_context, value_.data, value_.length);
    }
  }

  const moui_mobile_utf8_buffer_v1 &get() const { return value_; }

private:
  moui_mobile_utf8_buffer_v1 value_;
};

moui_mobile_utf8_view_v1 utf8_view(const char *value) {
  const size_t length = value == nullptr ? 0 : std::strlen(value);
  return {
      reinterpret_cast<const uint8_t *>(value),
      length,
  };
}

moui_mobile_utf8_view_v1 utf8_view(const std::string &value) {
  return {
      reinterpret_cast<const uint8_t *>(value.data()),
      value.size(),
  };
}

std::string consume_utf8_buffer(moui_mobile_utf8_buffer_v1 raw,
                                const char *operation) {
  OwnedUtf8Buffer buffer(raw);
  const auto &value = buffer.get();
  if (value.status != MOUI_MOBILE_RUNTIME_STATUS_OK_V1 ||
      value.data == nullptr || value.release == nullptr) {
    log_warn(
        "moui-mobile ABI buffer failure operation=%{public}s status=%{public}d",
        operation, value.status);
    return {};
  }
  return std::string(reinterpret_cast<const char *>(value.data), value.length);
}

double display_density_scale() {
#if defined(MOUI_HARMONYOS_HAS_DISPLAY_MANAGER)
  float density = 0.0f;
  if (OH_NativeDisplayManager_GetDefaultDisplayDensityPixels(&density) ==
          DISPLAY_MANAGER_OK &&
      density > 0.0f) {
    return static_cast<double>(density);
  }
  float ratio = 0.0f;
  if (OH_NativeDisplayManager_GetDefaultDisplayVirtualPixelRatio(&ratio) ==
          DISPLAY_MANAGER_OK &&
      ratio > 0.0f) {
    return static_cast<double>(ratio);
  }
#endif
  return 1.0;
}

bool ensure_runtime_initialized() {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  std::call_once(g_runtime_once, [] {
    g_runtime_api = moui_mobile_get_runtime_api_v1();
    if (!moui_mobile_runtime_api_v1_is_compatible(g_runtime_api)) {
      g_runtime_api = nullptr;
      g_initialize_result = MOUI_MOBILE_RUNTIME_ERROR_INITIALIZATION_FAILED_V1;
      log_warn("moui-mobile runtime ABI v1 negotiation failed app=%{public}s",
               MOUI_MOBILE_APP_ID);
      return;
    }
    g_initialize_result =
        g_runtime_api->initialize(utf8_view(MOUI_MOBILE_APP_ARG));
    if (g_initialize_result != MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1) {
      log_warn("moui-mobile runtime initialize failed app=%{public}s "
               "status=%{public}d",
               MOUI_MOBILE_APP_ID, g_initialize_result);
      return;
    }
    const int32_t renderer_result = g_runtime_api->configure_renderer(
        utf8_view(MOUI_MOBILE_RENDERER_REQUESTED));
    const std::string status = consume_utf8_buffer(
        g_runtime_api->renderer_status_json(), "renderer-status");
    log_info("moui-mobile runtime initialized app=%{public}s "
             "renderer-requested=%{public}s renderer-selected=%{public}s",
             MOUI_MOBILE_APP_ID, MOUI_MOBILE_RENDERER_REQUESTED,
             MOUI_MOBILE_RENDERER_SELECTED);
    log_info("moui-mobile renderer configure requested=%{public}s "
             "status=%{public}d detail=%{public}s",
             MOUI_MOBILE_RENDERER_REQUESTED, renderer_result, status.c_str());
  });
  return g_runtime_api != nullptr &&
         g_initialize_result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1;
}

bool boolean_result(const char *operation, int32_t result) {
  if (result < MOUI_MOBILE_RUNTIME_STATUS_OK_V1) {
    log_warn(
        "moui-mobile ABI call failed operation=%{public}s status=%{public}d",
        operation, result);
  }
  return result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1;
}

bool attach_or_resize(uint64_t surface_handle, int32_t width, int32_t height,
                      double scale) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized() || surface_handle == 0 || width <= 0 ||
      height <= 0) {
    log_warn("attach_or_resize rejected surface=%{public}llu width=%{public}d "
             "height=%{public}d",
             static_cast<unsigned long long>(surface_handle), width, height);
    return false;
  }
  if (scale <= 0.0) {
    scale = display_density_scale();
  }
  if (scale <= 0.0) {
    scale = 1.0;
  }
  const bool same_surface =
      g_surface_handle == surface_handle && g_surface_handle != 0;
  const int32_t result =
      same_surface
          ? g_runtime_api->resize(width, height, scale)
          : g_runtime_api->attach_surface(surface_handle, width, height, scale);
  if (result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1) {
    g_surface_handle = surface_handle;
    g_width = width;
    g_height = height;
    g_scale = scale;
  }
  log_info("moui-mobile XComponent %{public}s width=%{public}d "
           "height=%{public}d scale=%{public}f status=%{public}d",
           same_surface ? "resize" : "attach", width, height, scale, result);
  if (!same_surface) {
    log_info("moui-mobile lifecycle attach width=%{public}d height=%{public}d "
             "attached=%{public}d",
             width, height,
             result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1 ? 1 : 0);
  } else {
    log_info("moui-mobile resize width=%{public}d height=%{public}d "
             "result=%{public}d",
             width, height,
             result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1 ? 1 : 0);
  }
  return boolean_result(same_surface ? "resize" : "attach-surface", result);
}

#if defined(MOUI_HARMONYOS_HAS_XCOMPONENT)
OH_NativeXComponent *g_xcomponent = nullptr;
OH_NativeXComponent_Callback g_xcomponent_callback;
bool g_touch_active = false;
bool g_touch_scrolling = false;
double g_touch_start_x = 0.0;
double g_touch_start_y = 0.0;
double g_touch_last_x = 0.0;
double g_touch_last_y = 0.0;

int32_t xcomponent_touch_phase(OH_NativeXComponent_TouchEventType type) {
  switch (type) {
  case OH_NATIVEXCOMPONENT_DOWN:
    return 0;
  case OH_NATIVEXCOMPONENT_MOVE:
    return 1;
  case OH_NATIVEXCOMPONENT_UP:
    return 2;
  case OH_NATIVEXCOMPONENT_CANCEL:
    return 3;
  default:
    return 1;
  }
}

double monotonic_time_ms() {
  return std::chrono::duration<double, std::milli>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

void reset_touch_gesture() {
  g_touch_active = false;
  g_touch_scrolling = false;
}

void sync_xcomponent_surface(OH_NativeXComponent *component, void *window,
                             const char *event_name) {
  if (component == nullptr || window == nullptr) {
    log_warn("XComponent %{public}s missing component/window", event_name);
    return;
  }
  uint64_t width = 1;
  uint64_t height = 1;
  if (OH_NativeXComponent_GetXComponentSize(component, window, &width,
                                            &height) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    log_warn("XComponent %{public}s failed to read surface size", event_name);
    return;
  }
  if (width > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
      height > static_cast<uint64_t>(std::numeric_limits<int32_t>::max())) {
    log_warn("XComponent %{public}s rejected oversized surface", event_name);
    return;
  }
  const bool accepted = attach_or_resize(
      reinterpret_cast<uint64_t>(window),
      static_cast<int32_t>(width > 0 ? width : 1),
      static_cast<int32_t>(height > 0 ? height : 1), display_density_scale());
  log_info("XComponent surface %{public}s width=%{public}llu "
           "height=%{public}llu accepted=%{public}d source=native-xcomponent",
           event_name, static_cast<unsigned long long>(width),
           static_cast<unsigned long long>(height), accepted ? 1 : 0);
}

void on_surface_created(OH_NativeXComponent *component, void *window) {
  sync_xcomponent_surface(component, window, "created");
}

void on_surface_changed(OH_NativeXComponent *component, void *window) {
  sync_xcomponent_surface(component, window, "changed");
}

void on_surface_destroyed(OH_NativeXComponent *component, void *window) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  (void)component;
  (void)window;
  if (ensure_runtime_initialized()) {
    const int32_t result = g_runtime_api->detach_surface();
    boolean_result("detach-surface", result);
    log_info("XComponent surface destroyed detach=%{public}d "
             "source=native-xcomponent",
             result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1 ? 1 : 0);
  }
  g_surface_handle = 0;
  reset_touch_gesture();
  log_info("moui-mobile lifecycle detach reason=surface-destroyed");
}

void dispatch_touch_event(OH_NativeXComponent *component, void *window) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (component == nullptr || window == nullptr ||
      !ensure_runtime_initialized()) {
    log_warn("XComponent touch missing component/window/runtime");
    return;
  }
  OH_NativeXComponent_TouchEvent event;
  if (OH_NativeXComponent_GetTouchEvent(component, window, &event) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    log_warn("XComponent touch read failed");
    return;
  }
  const int32_t phase = xcomponent_touch_phase(event.type);
  const double time_ms = monotonic_time_ms();
  bool pointer_dispatched = false;
  bool scroll_dispatched = false;
  const bool supports_scroll = g_runtime_api->dispatch_scroll != nullptr;
  if (phase == 0) {
    g_touch_active = true;
    g_touch_scrolling = false;
    g_touch_start_x = event.x;
    g_touch_start_y = event.y;
    g_touch_last_x = event.x;
    g_touch_last_y = event.y;
    pointer_dispatched = boolean_result(
        "dispatch-pointer",
        g_runtime_api->dispatch_pointer(0, event.x, event.y, time_ms));
  } else if (phase == 1 && g_touch_active) {
    if (supports_scroll && !g_touch_scrolling) {
      const double dx = event.x - g_touch_start_x;
      const double dy = event.y - g_touch_start_y;
      if (dx * dx + dy * dy > k_touch_slop * k_touch_slop) {
        pointer_dispatched = boolean_result(
            "dispatch-pointer-cancel",
            g_runtime_api->dispatch_pointer(3, event.x, event.y, time_ms));
        scroll_dispatched =
            boolean_result("dispatch-scroll-begin",
                           g_runtime_api->dispatch_scroll(
                               g_touch_start_x, g_touch_start_y, 0.0, 0.0, 0));
        g_touch_scrolling = true;
      }
    }
    if (g_touch_scrolling) {
      scroll_dispatched =
          boolean_result("dispatch-scroll-move",
                         g_runtime_api->dispatch_scroll(
                             event.x, event.y, event.x - g_touch_last_x,
                             event.y - g_touch_last_y, 1)) ||
          scroll_dispatched;
    } else {
      pointer_dispatched = boolean_result(
          "dispatch-pointer",
          g_runtime_api->dispatch_pointer(1, event.x, event.y, time_ms));
    }
    g_touch_last_x = event.x;
    g_touch_last_y = event.y;
  } else if ((phase == 2 || phase == 3) && g_touch_active) {
    if (g_touch_scrolling && supports_scroll) {
      scroll_dispatched =
          boolean_result("dispatch-scroll-end",
                         g_runtime_api->dispatch_scroll(
                             event.x, event.y, 0.0, 0.0, phase == 2 ? 2 : 3));
    } else {
      pointer_dispatched = boolean_result(
          "dispatch-pointer",
          g_runtime_api->dispatch_pointer(phase, event.x, event.y, time_ms));
    }
    reset_touch_gesture();
  }
  log_info(
      "moui-mobile input pointer type=%{public}d x=%{public}f y=%{public}f "
      "pointer=%{public}d scroll=%{public}d source=native-xcomponent",
      static_cast<int32_t>(event.type), event.x, event.y,
      pointer_dispatched ? 1 : 0, scroll_dispatched ? 1 : 0);
  if (scroll_dispatched) {
    log_info("moui-mobile input scroll x=%{public}f y=%{public}f "
             "source=native-xcomponent",
             event.x, event.y);
  }
}

void register_xcomponent_callbacks() {
  if (g_xcomponent == nullptr) {
    log_warn(
        "XComponent callback registration skipped: missing native component");
    return;
  }
  g_xcomponent_callback.OnSurfaceCreated = on_surface_created;
  g_xcomponent_callback.OnSurfaceChanged = on_surface_changed;
  g_xcomponent_callback.OnSurfaceDestroyed = on_surface_destroyed;
  g_xcomponent_callback.DispatchTouchEvent = dispatch_touch_event;
  OH_NativeXComponent_RegisterCallback(g_xcomponent, &g_xcomponent_callback);
  log_info("XComponent callbacks registered as exclusive surface/input source");
}
#endif

#if defined(MOUI_HARMONYOS_HAS_NAPI)
bool napi_get_number(napi_env env, napi_value value, double *out) {
  return out != nullptr && napi_get_value_double(env, value, out) == napi_ok &&
         std::isfinite(*out);
}

bool napi_get_int32(napi_env env, napi_value value, int32_t *out) {
  double number = 0.0;
  if (out == nullptr || !napi_get_number(env, value, &number) ||
      std::trunc(number) != number ||
      number < static_cast<double>(std::numeric_limits<int32_t>::min()) ||
      number > static_cast<double>(std::numeric_limits<int32_t>::max())) {
    return false;
  }
  *out = static_cast<int32_t>(number);
  return true;
}

napi_value napi_bool(napi_env env, bool value) {
  napi_value result;
  napi_get_boolean(env, value, &result);
  return result;
}

bool napi_utf8(napi_env env, napi_value value, std::string *out) {
  if (out == nullptr) {
    return false;
  }
  size_t length = 0;
  if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok ||
      length > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
    return false;
  }
  std::vector<char> buffer(length + 1, 0);
  size_t written = 0;
  if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(),
                                 &written) != napi_ok ||
      written != length) {
    return false;
  }
  out->assign(buffer.data(), written);
  return true;
}

napi_value napi_string_from_buffer(napi_env env, moui_mobile_utf8_buffer_v1 raw,
                                   const char *operation) {
  OwnedUtf8Buffer buffer(raw);
  const auto &value = buffer.get();
  napi_value result;
  if (value.status != MOUI_MOBILE_RUNTIME_STATUS_OK_V1 ||
      value.data == nullptr || value.release == nullptr ||
      napi_create_string_utf8(env, reinterpret_cast<const char *>(value.data),
                              value.length, &result) != napi_ok) {
    log_warn(
        "moui-mobile ABI string failure operation=%{public}s status=%{public}d",
        operation, value.status);
    napi_create_string_utf8(env, "", 0, &result);
  }
  return result;
}

napi_value napi_frame_tick(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  double time_ms = 0.0;
  if (argc < 1 || !napi_get_number(env, argv[0], &time_ms)) {
    return napi_bool(env, false);
  }
  return napi_bool(
      env, boolean_result("frame-tick", g_runtime_api->frame_tick(time_ms)));
}

napi_value napi_take_host_updates(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  (void)info;
  if (!ensure_runtime_initialized()) {
    napi_value empty;
    napi_create_string_utf8(env, "", 0, &empty);
    return empty;
  }
  return napi_string_from_buffer(
      env, g_runtime_api->take_host_update_envelope_json(),
      "take-host-update-envelope");
}

napi_value napi_renderer_configure(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string mode;
  if (argc < 1 || !napi_utf8(env, argv[0], &mode)) {
    return napi_bool(env, false);
  }
  return napi_bool(
      env, boolean_result("renderer-configure",
                          g_runtime_api->configure_renderer(utf8_view(mode))));
}

napi_value napi_renderer_status(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  (void)info;
  if (!ensure_runtime_initialized()) {
    napi_value empty;
    napi_create_string_utf8(env, "", 0, &empty);
    return empty;
  }
  return napi_string_from_buffer(env, g_runtime_api->renderer_status_json(),
                                 "renderer-status");
}

napi_value napi_dispatch_host_response(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string encoded;
  if (argc < 1 || !napi_utf8(env, argv[0], &encoded)) {
    return napi_bool(env, false);
  }
  return napi_bool(
      env, boolean_result("dispatch-host-response-envelope",
                          g_runtime_api->dispatch_host_response_envelope(
                              utf8_view(encoded))));
}

napi_value napi_dispatch_text_input(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 4;
  napi_value argv[4];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int32_t kind = 0;
  int32_t start = 0;
  int32_t end = 0;
  std::string text;
  if (argc < 4 || !napi_get_int32(env, argv[0], &kind) ||
      !napi_utf8(env, argv[1], &text) ||
      !napi_get_int32(env, argv[2], &start) ||
      !napi_get_int32(env, argv[3], &end)) {
    return napi_bool(env, false);
  }
  return napi_bool(env, boolean_result("dispatch-text-input",
                                       g_runtime_api->dispatch_text_input(
                                           kind, utf8_view(text), start, end)));
}

napi_value napi_dispatch_command(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int32_t kind = 0;
  if (argc < 1 || !napi_get_int32(env, argv[0], &kind)) {
    return napi_bool(env, false);
  }
  return napi_bool(env, boolean_result("dispatch-command",
                                       g_runtime_api->dispatch_command(kind)));
}

napi_value napi_dispatch_accessibility(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 3;
  napi_value argv[3];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int32_t element_id = 0;
  int32_t action = 0;
  std::string value;
  if (argc < 3 || !napi_get_int32(env, argv[0], &element_id) ||
      !napi_get_int32(env, argv[1], &action) ||
      !napi_utf8(env, argv[2], &value)) {
    return napi_bool(env, false);
  }
  return napi_bool(env,
                   boolean_result("dispatch-accessibility",
                                  g_runtime_api->dispatch_accessibility(
                                      element_id, action, utf8_view(value))));
}

napi_value napi_complete_clipboard(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  size_t argc = 5;
  napi_value argv[5];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int32_t generation = 0;
  int32_t id = 0;
  int32_t kind = 0;
  std::string text;
  if (argc < 5 || !napi_get_int32(env, argv[0], &generation) ||
      !napi_get_int32(env, argv[1], &id) ||
      !napi_get_int32(env, argv[2], &kind) || !napi_utf8(env, argv[3], &text)) {
    return napi_bool(env, false);
  }
  void *data = nullptr;
  size_t length = 0;
  if (napi_get_arraybuffer_info(env, argv[4], &data, &length) != napi_ok) {
    return napi_bool(env, false);
  }
  const moui_mobile_bytes_view_v1 bytes = {
      reinterpret_cast<const uint8_t *>(data),
      length,
  };
  return napi_bool(
      env, boolean_result("complete-clipboard",
                          g_runtime_api->complete_clipboard(
                              generation, id, kind, utf8_view(text), bytes)));
}

napi_value napi_destroy_application(napi_env env, napi_callback_info info) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  (void)info;
  if (!ensure_runtime_initialized()) {
    return napi_bool(env, false);
  }
  const int32_t result = g_runtime_api->destroy_application();
  log_info("moui-mobile application destroy app=%{public}s status=%{public}d",
           MOUI_MOBILE_APP_ID, result);
  return napi_bool(env, boolean_result("destroy-application", result));
}

napi_value init(napi_env env, napi_value exports) {
#if defined(MOUI_HARMONYOS_HAS_XCOMPONENT)
  napi_value export_instance;
  if (napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ,
                              &export_instance) == napi_ok) {
    void *native_xcomponent = nullptr;
    if (napi_unwrap(env, export_instance, &native_xcomponent) == napi_ok) {
      g_xcomponent = reinterpret_cast<OH_NativeXComponent *>(native_xcomponent);
      register_xcomponent_callbacks();
      log_info("NAPI init received native XComponent");
    }
  }
#endif
  napi_property_descriptor descriptors[] = {
      {"frameTick", nullptr, napi_frame_tick, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"takeHostUpdates", nullptr, napi_take_host_updates, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"rendererConfigure", nullptr, napi_renderer_configure, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"rendererStatusJson", nullptr, napi_renderer_status, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"dispatchHostResponseEnvelope", nullptr, napi_dispatch_host_response,
       nullptr, nullptr, nullptr, napi_default, nullptr},
      {"dispatchTextInput", nullptr, napi_dispatch_text_input, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"dispatchCommand", nullptr, napi_dispatch_command, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"dispatchAccessibility", nullptr, napi_dispatch_accessibility, nullptr,
       nullptr, nullptr, napi_default, nullptr},
      {"completeClipboard", nullptr, napi_complete_clipboard, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"destroyApplication", nullptr, napi_destroy_application, nullptr,
       nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(
      env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
  log_info("NAPI module initialized with Mobile Runtime ABI v1");
  return exports;
}
#endif

} // namespace

extern "C" int32_t MOUI_MOBILE_SMOKE_ATTACH_SURFACE(uint64_t surface_handle,
                                                    int32_t width,
                                                    int32_t height,
                                                    double scale_factor) {
  return attach_or_resize(surface_handle, width, height, scale_factor) ? 1 : 0;
}

extern "C" int32_t MOUI_MOBILE_SMOKE_RENDER_FRAME(void) {
  RuntimeCallLock runtime_call_lock(g_runtime_call_mutex);
  if (!ensure_runtime_initialized()) {
    return MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1;
  }
  return g_runtime_api->render_frame();
}

#if defined(MOUI_HARMONYOS_HAS_NAPI)
#ifndef NODE_GYP_MODULE_NAME
#define NODE_GYP_MODULE_NAME moui_mobile_harmonyos
#endif
NAPI_MODULE(NODE_GYP_MODULE_NAME, init)
#endif
