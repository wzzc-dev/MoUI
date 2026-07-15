#include <cstdint>
#include <cstdarg>
#include <cctype>
#include <cstdlib>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fstream>
#include <mutex>
#include <moonbit.h>
#include <string>
#include <vector>

std::string std_string_from_moonbit(moonbit_string_t value);

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
#define MOUI_MOBILE_SMOKE_ATTACH_SURFACE moui_mobile_harmonyos_attach_surface_for_smoke
#endif

#ifndef MOUI_MOBILE_SMOKE_RENDER_FRAME
#define MOUI_MOBILE_SMOKE_RENDER_FRAME moui_mobile_harmonyos_render_frame_for_smoke
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

std::once_flag g_runtime_once;
uint64_t g_surface_handle = 0;
int32_t g_width = 1;
int32_t g_height = 1;
double g_scale = 1.0;
double g_logical_width = 0.0;
double g_logical_height = 0.0;

// Display density (vp → px). XComponent size is physical; MoUI draws in logical
// units and scales by this factor. Hardcoding 1.0 made UI ~2x too small on HVD.
double display_density_scale() {
#if defined(MOUI_HARMONYOS_HAS_DISPLAY_MANAGER)
  float density = 0.0f;
  if (
    OH_NativeDisplayManager_GetDefaultDisplayDensityPixels(&density) ==
      DISPLAY_MANAGER_OK &&
    density > 0.0f
  ) {
    return static_cast<double>(density);
  }
  float virtual_pixels = 0.0f;
  if (
    OH_NativeDisplayManager_GetDefaultDisplayVirtualPixelRatio(&virtual_pixels) ==
      DISPLAY_MANAGER_OK &&
    virtual_pixels > 0.0f
  ) {
    return static_cast<double>(virtual_pixels);
  }
#endif
  return 1.0;
}

constexpr unsigned int k_log_domain = 0x4D4F;
constexpr const char *k_log_tag = "MoUIHarmony";

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

#if defined(MOUI_HARMONYOS_HAS_XCOMPONENT)
OH_NativeXComponent *g_xcomponent = nullptr;
OH_NativeXComponent_Callback g_xcomponent_callback;
#endif

extern "C" void moonbit_runtime_init(int argc, char **argv);
extern "C" void moonbit_init(void);

extern "C" int32_t MOUI_MOBILE_ATTACH_SURFACE(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor);
extern "C" int32_t MOUI_MOBILE_RESIZE(
    int32_t width,
    int32_t height,
    double scale_factor);
extern "C" int32_t MOUI_MOBILE_DISPATCH_POINTER(
    int32_t phase,
    double x,
    double y,
    double time_ms);
#if MOUI_MOBILE_ENABLE_SCROLL
extern "C" int32_t MOUI_MOBILE_DISPATCH_SCROLL(
    double x,
    double y,
    double delta_x,
    double delta_y,
    int32_t phase);
#endif
extern "C" int32_t MOUI_MOBILE_RENDER_FRAME(void);
extern "C" int32_t MOUI_MOBILE_FRAME_TICK(double time_ms);
extern "C" void MOUI_MOBILE_DETACH_SURFACE(void);
extern "C" moonbit_string_t moui_mobile_take_host_updates_json(void);
extern "C" int32_t moui_mobile_renderer_configure(moonbit_string_t mode);
extern "C" moonbit_string_t moui_mobile_renderer_status_json(void);
extern "C" int32_t moui_mobile_dispatch_text_input(
    int32_t kind,
    moonbit_string_t text,
    int32_t start,
    int32_t end);
extern "C" int32_t moui_mobile_dispatch_command(int32_t kind);
extern "C" int32_t moui_mobile_dispatch_accessibility(
    int32_t element_id,
    int32_t action,
    moonbit_string_t value);
extern "C" int32_t moui_mobile_complete_clipboard(
    int32_t id,
    int32_t kind,
    moonbit_string_t text,
    moonbit_bytes_t bytes);

moonbit_string_t moonbit_string_from_ascii(const char *value) {
  const size_t length = value == nullptr ? 0 : std::strlen(value);
  moonbit_string_t result = moonbit_make_string_raw(static_cast<int32_t>(length));
  auto *units = reinterpret_cast<uint16_t *>(result);
  for (size_t index = 0; index < length; ++index) {
    units[index] = static_cast<uint8_t>(value[index]);
  }
  return result;
}

// Converts a MoonBit string (length-prefixed UTF-16 units) to a UTF-8
// std::string for logging. Renderer status JSON is ASCII, but the BMP->UTF-8
// path keeps non-ASCII fallback reasons valid.
std::string std_string_from_moonbit(moonbit_string_t value) {
  if (value == nullptr) {
    return {};
  }
  const int32_t length = Moonbit_array_length(value);
  const auto *units = reinterpret_cast<const uint16_t *>(value);
  std::string result;
  result.reserve(static_cast<size_t>(length));
  for (int32_t index = 0; index < length; ++index) {
    const uint16_t unit = units[index];
    if (unit < 0x80) {
      result.push_back(static_cast<char>(unit));
    } else if (unit < 0x800) {
      result.push_back(static_cast<char>(0xC0 | (unit >> 6)));
      result.push_back(static_cast<char>(0x80 | (unit & 0x3F)));
    } else {
      result.push_back(static_cast<char>(0xE0 | (unit >> 12)));
      result.push_back(static_cast<char>(0x80 | ((unit >> 6) & 0x3F)));
      result.push_back(static_cast<char>(0x80 | (unit & 0x3F)));
    }
  }
  moonbit_decref(value);
  return result;
}

void ensure_moonbit_runtime() {
  std::call_once(g_runtime_once, [] {
    static char app_name[] = MOUI_MOBILE_APP_ARG;
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
    moonbit_string_t renderer_mode = moonbit_string_from_ascii(
      MOUI_MOBILE_RENDERER_REQUESTED
    );
    const int32_t renderer_configured = moui_mobile_renderer_configure(
      renderer_mode
    );
    moonbit_decref(renderer_mode);
    log_info(
      "moui-mobile runtime initialized app=%{public}s renderer-requested=%{public}s renderer-selected=%{public}s",
      MOUI_MOBILE_APP_ID,
      MOUI_MOBILE_RENDERER_REQUESTED,
      MOUI_MOBILE_RENDERER_SELECTED
    );
    log_info(
      "moui-mobile renderer configure requested=%{public}s ok=%{public}d status=%{public}s",
      MOUI_MOBILE_RENDERER_REQUESTED,
      renderer_configured,
      std_string_from_moonbit(moui_mobile_renderer_status_json()).c_str()
    );
  });
}

bool attach_or_resize(uint64_t surface_handle, int32_t width, int32_t height, double scale) {
  ensure_moonbit_runtime();
  if (surface_handle == 0 || width <= 0 || height <= 0) {
    log_warn(
      "attach_or_resize rejected surface=%{public}llu width=%{public}d height=%{public}d",
      static_cast<unsigned long long>(surface_handle),
      width,
      height
    );
    return false;
  }
  if (scale <= 0.0) {
    scale = display_density_scale();
  }
  if (g_logical_width > 0.0 && g_logical_height > 0.0) {
    const double x_scale = static_cast<double>(width) / g_logical_width;
    const double y_scale = static_cast<double>(height) / g_logical_height;
    scale = x_scale > y_scale ? x_scale : y_scale;
  } else if (scale <= 1.0) {
    // Prefer display density when ArkTS has not yet reported logical size.
    // HVD MateBook Pro is typically densityPixels≈2; scale=1 made UI too small.
    const double density = display_density_scale();
    if (density > scale) {
      scale = density;
    }
  }
  if (scale <= 0.0) {
    scale = 1.0;
  }
  const bool same_surface = g_surface_handle == surface_handle && g_surface_handle != 0;
  g_surface_handle = surface_handle;
  g_width = width;
  g_height = height;
  g_scale = scale;
  log_info(
    "attach_or_resize surface=%{public}llu width=%{public}d height=%{public}d scale=%{public}f same=%{public}d",
    static_cast<unsigned long long>(surface_handle),
    width,
    height,
    scale,
    same_surface ? 1 : 0
  );
  if (same_surface) {
    const bool resized = MOUI_MOBILE_RESIZE(width, height, scale) != 0;
    log_info("HarmonyOS runtime resize result=%{public}d", resized ? 1 : 0);
    log_info(
      "moui-mobile resize width=%{public}d height=%{public}d result=%{public}d",
      width,
      height,
      resized ? 1 : 0
    );
    return resized;
  }
  const bool attached = MOUI_MOBILE_ATTACH_SURFACE(surface_handle, width, height, scale) != 0;
  log_info("HarmonyOS runtime attach result=%{public}d", attached ? 1 : 0);
  log_info("moui-mobile lifecycle attach result=%{public}d", attached ? 1 : 0);
  return attached;
}

#if defined(MOUI_HARMONYOS_HAS_XCOMPONENT)
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
      std::chrono::steady_clock::now().time_since_epoch()).count();
}

bool g_touch_active = false;
bool g_touch_scrolling = false;
double g_touch_start_x = 0.0;
double g_touch_start_y = 0.0;
double g_touch_last_x = 0.0;
double g_touch_last_y = 0.0;
constexpr double k_touch_slop = 8.0;

void reset_touch_gesture() {
  g_touch_active = false;
  g_touch_scrolling = false;
}

void on_surface_created(OH_NativeXComponent *component, void *window) {
  if (component == nullptr || window == nullptr) {
    log_warn("XComponent surface create missing component/window");
    return;
  }
  uint64_t width = 1;
  uint64_t height = 1;
  OH_NativeXComponent_GetXComponentSize(component, window, &width, &height);
  const double density = display_density_scale();
  const bool attached = attach_or_resize(
    reinterpret_cast<uint64_t>(window),
    static_cast<int32_t>(width > 0 ? width : 1),
    static_cast<int32_t>(height > 0 ? height : 1),
    density
  );
  log_info(
    "XComponent surface created width=%{public}llu height=%{public}llu density=%{public}f attach=%{public}d",
    static_cast<unsigned long long>(width),
    static_cast<unsigned long long>(height),
    density,
    attached ? 1 : 0
  );
}

void on_surface_changed(OH_NativeXComponent *component, void *window) {
  if (component == nullptr || window == nullptr) {
    log_warn("XComponent surface change missing component/window");
    return;
  }
  uint64_t width = 1;
  uint64_t height = 1;
  OH_NativeXComponent_GetXComponentSize(component, window, &width, &height);
  const double density = display_density_scale();
  const bool resized = attach_or_resize(
    reinterpret_cast<uint64_t>(window),
    static_cast<int32_t>(width > 0 ? width : 1),
    static_cast<int32_t>(height > 0 ? height : 1),
    density
  );
  log_info(
    "XComponent surface changed width=%{public}llu height=%{public}llu density=%{public}f resize=%{public}d",
    static_cast<unsigned long long>(width),
    static_cast<unsigned long long>(height),
    density,
    resized ? 1 : 0
  );
}

void on_surface_destroyed(OH_NativeXComponent *component, void *window) {
  (void)component;
  (void)window;
  ensure_moonbit_runtime();
  MOUI_MOBILE_DETACH_SURFACE();
  g_surface_handle = 0;
  reset_touch_gesture();
  log_info("XComponent surface destroyed detach=1");
  log_info("moui-mobile lifecycle detach reason=surface-destroyed");
}

void dispatch_touch_event(OH_NativeXComponent *component, void *window) {
  if (component == nullptr || window == nullptr) {
    log_warn("XComponent touch missing component/window");
    return;
  }
  ensure_moonbit_runtime();
  OH_NativeXComponent_TouchEvent event;
  if (OH_NativeXComponent_GetTouchEvent(component, window, &event) != OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    log_warn("XComponent touch read failed");
    return;
  }
  const int32_t phase = xcomponent_touch_phase(event.type);
  const double now_ms = monotonic_time_ms();
  bool dispatched = false;
  bool scroll_dispatched = false;
  if (phase == 0) {
    g_touch_active = true;
    g_touch_scrolling = false;
    g_touch_start_x = event.x;
    g_touch_start_y = event.y;
    g_touch_last_x = event.x;
    g_touch_last_y = event.y;
    dispatched = MOUI_MOBILE_DISPATCH_POINTER(0, event.x, event.y, now_ms) != 0;
  } else if (phase == 1 && g_touch_active) {
#if MOUI_MOBILE_ENABLE_SCROLL
    if (!g_touch_scrolling) {
      const double dx = event.x - g_touch_start_x;
      const double dy = event.y - g_touch_start_y;
      if (dx * dx + dy * dy > k_touch_slop * k_touch_slop) {
        dispatched = MOUI_MOBILE_DISPATCH_POINTER(3, event.x, event.y, now_ms) != 0;
        scroll_dispatched = MOUI_MOBILE_DISPATCH_SCROLL(
          g_touch_start_x, g_touch_start_y, 0.0, 0.0, 0) != 0;
        g_touch_scrolling = true;
      }
    }
    if (g_touch_scrolling) {
      scroll_dispatched = MOUI_MOBILE_DISPATCH_SCROLL(
        event.x,
        event.y,
        event.x - g_touch_last_x,
        event.y - g_touch_last_y,
        1) != 0 || scroll_dispatched;
    } else {
      dispatched = MOUI_MOBILE_DISPATCH_POINTER(1, event.x, event.y, now_ms) != 0;
    }
#else
    dispatched = MOUI_MOBILE_DISPATCH_POINTER(1, event.x, event.y, now_ms) != 0;
#endif
    g_touch_last_x = event.x;
    g_touch_last_y = event.y;
  } else if ((phase == 2 || phase == 3) && g_touch_active) {
#if MOUI_MOBILE_ENABLE_SCROLL
    if (g_touch_scrolling) {
      scroll_dispatched = MOUI_MOBILE_DISPATCH_SCROLL(
        event.x, event.y, 0.0, 0.0, phase == 2 ? 2 : 3) != 0;
    } else {
      dispatched = MOUI_MOBILE_DISPATCH_POINTER(phase, event.x, event.y, now_ms) != 0;
    }
#else
    dispatched = MOUI_MOBILE_DISPATCH_POINTER(phase, event.x, event.y, now_ms) != 0;
#endif
    reset_touch_gesture();
  }
  log_info(
    "moui-mobile input pointer type=%{public}d x=%{public}f y=%{public}f pointer=%{public}d scroll=%{public}d",
    static_cast<int>(event.type),
    event.x,
    event.y,
    dispatched ? 1 : 0,
    scroll_dispatched ? 1 : 0
  );
  if (scroll_dispatched) {
    log_info("moui-mobile input scroll x=%{public}f y=%{public}f", event.x, event.y);
  }
}

void register_xcomponent_callbacks() {
  if (g_xcomponent == nullptr) {
    log_warn("XComponent callback registration skipped: missing native component");
    return;
  }
  g_xcomponent_callback.OnSurfaceCreated = on_surface_created;
  g_xcomponent_callback.OnSurfaceChanged = on_surface_changed;
  g_xcomponent_callback.OnSurfaceDestroyed = on_surface_destroyed;
  g_xcomponent_callback.DispatchTouchEvent = dispatch_touch_event;
  OH_NativeXComponent_RegisterCallback(g_xcomponent, &g_xcomponent_callback);
  log_info("XComponent callbacks registered");
}
#endif

#if defined(MOUI_HARMONYOS_HAS_NAPI)
bool napi_get_number(napi_env env, napi_value value, double *out) {
  return napi_get_value_double(env, value, out) == napi_ok;
}

napi_value napi_bool(napi_env env, bool value) {
  napi_value result;
  napi_get_boolean(env, value, &result);
  return result;
}

moonbit_string_t napi_moonbit_string(napi_env env, napi_value value) {
  size_t length = 0;
  if (napi_get_value_string_utf16(env, value, nullptr, 0, &length) != napi_ok) {
    return moonbit_make_string(0, 0);
  }
  std::vector<char16_t> buffer(length + 1, 0);
  size_t written = 0;
  napi_get_value_string_utf16(env, value, buffer.data(), buffer.size(), &written);
  moonbit_string_t result = moonbit_make_string_raw(static_cast<int32_t>(length));
  memcpy(result, buffer.data(), written * sizeof(char16_t));
  return result;
}

napi_value napi_moonbit_string_value(napi_env env, moonbit_string_t value) {
  napi_value result;
  const int32_t length = value == nullptr ? 0 : Moonbit_array_length(value);
  napi_create_string_utf16(
    env,
    value == nullptr ? u"" : reinterpret_cast<const char16_t *>(value),
    static_cast<size_t>(length),
    &result
  );
  if (value != nullptr) {
    moonbit_decref(value);
  }
  return result;
}

napi_value napi_render_frame(napi_env env, napi_callback_info info) {
  (void)info;
  ensure_moonbit_runtime();
  const bool rendered = MOUI_MOBILE_RENDER_FRAME() != 0;
  log_info("NAPI renderFrame result=%{public}d", rendered ? 1 : 0);
  return napi_bool(env, rendered);
}

napi_value napi_frame_tick(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  double time_ms = 0.0;
  if (argc < 1 || !napi_get_number(env, argv[0], &time_ms)) {
    log_warn("NAPI frameTick rejected invalid args");
    return napi_bool(env, false);
  }
  return napi_bool(env, MOUI_MOBILE_FRAME_TICK(time_ms) != 0);
}

napi_value napi_take_host_updates(napi_env env, napi_callback_info info) {
  (void)info;
  ensure_moonbit_runtime();
  return napi_moonbit_string_value(env, moui_mobile_take_host_updates_json());
}

napi_value napi_renderer_configure(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (argc < 1) {
    return napi_bool(env, false);
  }
  moonbit_string_t mode = napi_moonbit_string(env, argv[0]);
  const int32_t result = moui_mobile_renderer_configure(mode);
  moonbit_decref(mode);
  return napi_bool(env, result != 0);
}

napi_value napi_renderer_status(napi_env env, napi_callback_info info) {
  (void)info;
  ensure_moonbit_runtime();
  return napi_moonbit_string_value(env, moui_mobile_renderer_status_json());
}

// Reads MOUI_MOBILE_A11Y_SMOKE from the process environment so the ArkTS
// host-update handler can fire a deterministic once-fire focus/activate pair
// without a live screen-reader gesture stream, mirroring the iOS path. HarmonyOS
// ability processes are forked by appspawn and do NOT inherit `hdc shell` env,
// so the recorder also writes a flag file at `/data/local/tmp/moui_a11y_smoke`
// as the reliable cross-boundary signal; this function checks both.
napi_value napi_a11y_smoke_enabled(napi_env env, napi_callback_info info) {
  (void)info;
  const char *env_value = std::getenv("MOUI_MOBILE_A11Y_SMOKE");
  bool enabled = false;
  if (env_value != nullptr) {
    std::string lower(env_value);
    for (char &c : lower) {
      c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    enabled = lower == "1" || lower == "true" || lower == "yes";
  }
  if (!enabled) {
    std::ifstream flag("/data/local/tmp/moui_a11y_smoke");
    if (flag.is_open()) {
      std::string value;
      std::getline(flag, value);
      for (char &c : value) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
      }
      // trim whitespace
      while (!value.empty() && (value.back() == '\r' || value.back() == '\n' ||
             value.back() == ' ' || value.back() == '\t')) {
        value.pop_back();
      }
      enabled = value == "1" || value == "true" || value == "yes";
    }
  }
  return napi_bool(env, enabled);
}

napi_value napi_dispatch_text_input(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 4;
  napi_value argv[4];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  double kind = 0.0;
  double start = 0.0;
  double end = 0.0;
  if (argc < 4 || !napi_get_number(env, argv[0], &kind) ||
      !napi_get_number(env, argv[2], &start) ||
      !napi_get_number(env, argv[3], &end)) {
    return napi_bool(env, false);
  }
  moonbit_string_t text = napi_moonbit_string(env, argv[1]);
  const int32_t result = moui_mobile_dispatch_text_input(
    static_cast<int32_t>(kind),
    text,
    static_cast<int32_t>(start),
    static_cast<int32_t>(end)
  );
  log_info(
    "moui-mobile service ime edit kind=%{public}d result=%{public}d",
    static_cast<int32_t>(kind),
    result
  );
  moonbit_decref(text);
  return napi_bool(env, result != 0);
}

napi_value napi_dispatch_command(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 1;
  napi_value argv[1];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  double kind = 0.0;
  if (argc < 1 || !napi_get_number(env, argv[0], &kind)) {
    return napi_bool(env, false);
  }
  return napi_bool(env, moui_mobile_dispatch_command(static_cast<int32_t>(kind)) != 0);
}

napi_value napi_dispatch_accessibility(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 3;
  napi_value argv[3];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  double element_id = 0.0;
  double action = 0.0;
  if (argc < 3 || !napi_get_number(env, argv[0], &element_id) ||
      !napi_get_number(env, argv[1], &action)) {
    return napi_bool(env, false);
  }
  moonbit_string_t value = napi_moonbit_string(env, argv[2]);
  const int32_t result = moui_mobile_dispatch_accessibility(
    static_cast<int32_t>(element_id),
    static_cast<int32_t>(action),
    value
  );
  log_info(
    "moui-mobile service accessibility %{public}s id=%{public}d action=%{public}d result=%{public}d",
    static_cast<int32_t>(action) == 1 ? "focus" : "action",
    static_cast<int32_t>(element_id),
    static_cast<int32_t>(action),
    result
  );
  moonbit_decref(value);
  return napi_bool(env, result != 0);
}

napi_value napi_complete_clipboard(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 4;
  napi_value argv[4];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  double id = 0.0;
  double kind = 0.0;
  if (argc < 4 || !napi_get_number(env, argv[0], &id) ||
      !napi_get_number(env, argv[1], &kind)) {
    return napi_bool(env, false);
  }
  moonbit_string_t text = napi_moonbit_string(env, argv[2]);
  void *data = nullptr;
  size_t byte_length = 0;
  napi_get_arraybuffer_info(env, argv[3], &data, &byte_length);
  moonbit_bytes_t bytes = moonbit_make_bytes_raw(static_cast<int32_t>(byte_length));
  if (data != nullptr && byte_length > 0) {
    memcpy(bytes, data, byte_length);
  }
  const int32_t result = moui_mobile_complete_clipboard(
    static_cast<int32_t>(id),
    static_cast<int32_t>(kind),
    text,
    bytes
  );
  log_info(
    "moui-mobile service clipboard complete id=%{public}d kind=%{public}d result=%{public}d",
    static_cast<int32_t>(id),
    static_cast<int32_t>(kind),
    result
  );
  moonbit_decref(text);
  moonbit_decref(bytes);
  return napi_bool(env, result != 0);
}

napi_value napi_detach_surface(napi_env env, napi_callback_info info) {
  (void)info;
  ensure_moonbit_runtime();
  MOUI_MOBILE_DETACH_SURFACE();
  g_surface_handle = 0;
  log_info("NAPI detachSurface result=1");
  return napi_bool(env, true);
}

napi_value napi_dispatch_pointer(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 4;
  napi_value argv[4];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (argc < 4) {
    log_warn("NAPI dispatchPointer rejected argc=%{public}llu", static_cast<unsigned long long>(argc));
    return napi_bool(env, false);
  }
  double phase = 0.0;
  double x = 0.0;
  double y = 0.0;
  double time_ms = 0.0;
  if (!napi_get_number(env, argv[0], &phase) ||
      !napi_get_number(env, argv[1], &x) ||
      !napi_get_number(env, argv[2], &y) ||
      !napi_get_number(env, argv[3], &time_ms)) {
    log_warn("NAPI dispatchPointer rejected invalid args");
    return napi_bool(env, false);
  }
  const bool ok = MOUI_MOBILE_DISPATCH_POINTER(
    static_cast<int32_t>(phase),
    x,
    y,
    time_ms
  ) != 0;
  log_info(
    "NAPI dispatchPointer phase=%{public}d x=%{public}f y=%{public}f result=%{public}d",
    static_cast<int32_t>(phase),
    x,
    y,
    ok ? 1 : 0
  );
  return napi_bool(env, ok);
}

#if MOUI_MOBILE_ENABLE_SCROLL
napi_value napi_dispatch_scroll(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 5;
  napi_value argv[5];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (argc < 5) {
    log_warn("NAPI dispatchScroll rejected argc=%{public}llu", static_cast<unsigned long long>(argc));
    return napi_bool(env, false);
  }
  double x = 0.0;
  double y = 0.0;
  double delta_x = 0.0;
  double delta_y = 0.0;
  double phase = 0.0;
  if (!napi_get_number(env, argv[0], &x) ||
      !napi_get_number(env, argv[1], &y) ||
      !napi_get_number(env, argv[2], &delta_x) ||
      !napi_get_number(env, argv[3], &delta_y) ||
      !napi_get_number(env, argv[4], &phase)) {
    log_warn("NAPI dispatchScroll rejected invalid args");
    return napi_bool(env, false);
  }
  const bool ok = MOUI_MOBILE_DISPATCH_SCROLL(
    x,
    y,
    delta_x,
    delta_y,
    static_cast<int32_t>(phase)
  ) != 0;
  log_info(
    "NAPI dispatchScroll x=%{public}f y=%{public}f dx=%{public}f dy=%{public}f phase=%{public}d result=%{public}d",
    x,
    y,
    delta_x,
    delta_y,
    static_cast<int32_t>(phase),
    ok ? 1 : 0
  );
  return napi_bool(env, ok);
}
#endif

napi_value napi_attach_surface(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 4;
  napi_value argv[4];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (argc < 4) {
    log_warn("NAPI attachSurface rejected argc=%{public}llu", static_cast<unsigned long long>(argc));
    return napi_bool(env, false);
  }
  double surface = 0.0;
  double width = 0.0;
  double height = 0.0;
  double scale = 0.0;
  if (!napi_get_number(env, argv[0], &surface) ||
      !napi_get_number(env, argv[1], &width) ||
      !napi_get_number(env, argv[2], &height) ||
      !napi_get_number(env, argv[3], &scale)) {
    log_warn("NAPI attachSurface rejected invalid args");
    return napi_bool(env, false);
  }
  const bool ok = attach_or_resize(
    static_cast<uint64_t>(surface),
    static_cast<int32_t>(width),
    static_cast<int32_t>(height),
    scale
  );
  log_info("NAPI attachSurface result=%{public}d", ok ? 1 : 0);
  return napi_bool(env, ok);
}

napi_value napi_resize(napi_env env, napi_callback_info info) {
  ensure_moonbit_runtime();
  size_t argc = 3;
  napi_value argv[3];
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (argc < 3) {
    log_warn("NAPI resize rejected argc=%{public}llu", static_cast<unsigned long long>(argc));
    return napi_bool(env, false);
  }
  double width = 0.0;
  double height = 0.0;
  double scale = 0.0;
  if (!napi_get_number(env, argv[0], &width) ||
      !napi_get_number(env, argv[1], &height) ||
      !napi_get_number(env, argv[2], &scale)) {
    log_warn("NAPI resize rejected invalid args");
    return napi_bool(env, false);
  }
  g_logical_width = width;
  g_logical_height = height;
  const int32_t physical_width = g_width > 0 ? g_width : static_cast<int32_t>(width);
  const int32_t physical_height = g_height > 0 ? g_height : static_cast<int32_t>(height);
  if (width > 0.0 && height > 0.0 && g_surface_handle != 0) {
    const double x_scale = static_cast<double>(physical_width) / width;
    const double y_scale = static_cast<double>(physical_height) / height;
    g_scale = x_scale > y_scale ? x_scale : y_scale;
  } else {
    g_scale = scale > 0.0 ? scale : 1.0;
  }
  const bool ok = MOUI_MOBILE_RESIZE(physical_width, physical_height, g_scale) != 0;
  log_info(
    "NAPI resize logical=%{public}fx%{public}f physical=%{public}dx%{public}d scale=%{public}f result=%{public}d",
    width,
    height,
    physical_width,
    physical_height,
    g_scale,
    ok ? 1 : 0
  );
  return napi_bool(env, ok);
}

napi_value init(napi_env env, napi_value exports) {
#if defined(MOUI_HARMONYOS_HAS_XCOMPONENT)
  napi_value export_instance;
  if (napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &export_instance) == napi_ok) {
    void *native_xcomponent = nullptr;
    if (napi_unwrap(env, export_instance, &native_xcomponent) == napi_ok) {
      g_xcomponent = reinterpret_cast<OH_NativeXComponent *>(native_xcomponent);
      register_xcomponent_callbacks();
      log_info("NAPI init received native XComponent");
    }
  }
#endif
  napi_property_descriptor descriptors[] = {
    {"attachSurface", nullptr, napi_attach_surface, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"resize", nullptr, napi_resize, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"dispatchPointer", nullptr, napi_dispatch_pointer, nullptr, nullptr, nullptr, napi_default, nullptr},
#if MOUI_MOBILE_ENABLE_SCROLL
    {"dispatchScroll", nullptr, napi_dispatch_scroll, nullptr, nullptr, nullptr, napi_default, nullptr},
#endif
    {"frameTick", nullptr, napi_frame_tick, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"takeHostUpdates", nullptr, napi_take_host_updates, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"rendererConfigure", nullptr, napi_renderer_configure, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"rendererStatusJson", nullptr, napi_renderer_status, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"a11ySmokeEnabled", nullptr, napi_a11y_smoke_enabled, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"dispatchTextInput", nullptr, napi_dispatch_text_input, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"dispatchCommand", nullptr, napi_dispatch_command, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"dispatchAccessibility", nullptr, napi_dispatch_accessibility, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"completeClipboard", nullptr, napi_complete_clipboard, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"renderFrame", nullptr, napi_render_frame, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"detachSurface", nullptr, napi_detach_surface, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
  log_info("NAPI module initialized");
  return exports;
}
#endif

}  // namespace

extern "C" int32_t MOUI_MOBILE_SMOKE_ATTACH_SURFACE(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor) {
  return attach_or_resize(surface_handle, width, height, scale_factor) ? 1 : 0;
}

extern "C" int32_t MOUI_MOBILE_SMOKE_RENDER_FRAME(void) {
  ensure_moonbit_runtime();
  return MOUI_MOBILE_RENDER_FRAME();
}

#if defined(MOUI_HARMONYOS_HAS_NAPI)
#ifndef NODE_GYP_MODULE_NAME
#define NODE_GYP_MODULE_NAME moui_mobile_harmonyos
#endif
NAPI_MODULE(NODE_GYP_MODULE_NAME, init)
#endif
