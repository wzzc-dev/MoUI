#include <cstdint>
#include <cstdarg>
#include <mutex>

#ifndef MOUI_MOBILE_APP_ARG
#define MOUI_MOBILE_APP_ARG "moui-mobile-harmonyos"
#endif

#ifndef MOUI_MOBILE_APP_ID
#define MOUI_MOBILE_APP_ID "unknown"
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

namespace {

std::once_flag g_runtime_once;
uint64_t g_surface_handle = 0;
int32_t g_width = 1;
int32_t g_height = 1;
double g_scale = 1.0;
double g_logical_width = 0.0;
double g_logical_height = 0.0;

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
extern "C" void MOUI_MOBILE_DETACH_SURFACE(void);

void ensure_moonbit_runtime() {
  std::call_once(g_runtime_once, [] {
    static char app_name[] = MOUI_MOBILE_APP_ARG;
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
    log_info("MoonBit runtime initialized");
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
    scale = 1.0;
  }
  if (g_logical_width > 0.0 && g_logical_height > 0.0) {
    const double x_scale = static_cast<double>(width) / g_logical_width;
    const double y_scale = static_cast<double>(height) / g_logical_height;
    scale = x_scale > y_scale ? x_scale : y_scale;
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
    return resized;
  }
  const bool attached = MOUI_MOBILE_ATTACH_SURFACE(surface_handle, width, height, scale) != 0;
  log_info("HarmonyOS runtime attach result=%{public}d", attached ? 1 : 0);
  return attached;
}

#if defined(MOUI_HARMONYOS_HAS_XCOMPONENT)
double xcomponent_touch_phase(OH_NativeXComponent_TouchEventType type) {
  switch (type) {
    case OH_NATIVEXCOMPONENT_DOWN:
      return 0.0;
    case OH_NATIVEXCOMPONENT_MOVE:
      return 1.0;
    case OH_NATIVEXCOMPONENT_UP:
      return 2.0;
    case OH_NATIVEXCOMPONENT_CANCEL:
      return 3.0;
    default:
      return 1.0;
  }
}

void on_surface_created(OH_NativeXComponent *component, void *window) {
  if (component == nullptr || window == nullptr) {
    log_warn("XComponent surface create missing component/window");
    return;
  }
  uint64_t width = 1;
  uint64_t height = 1;
  OH_NativeXComponent_GetXComponentSize(component, window, &width, &height);
  const bool attached = attach_or_resize(
    reinterpret_cast<uint64_t>(window),
    static_cast<int32_t>(width > 0 ? width : 1),
    static_cast<int32_t>(height > 0 ? height : 1),
    1.0
  );
  const bool rendered = MOUI_MOBILE_RENDER_FRAME() != 0;
  log_info(
    "XComponent surface created width=%{public}llu height=%{public}llu attach=%{public}d render=%{public}d",
    static_cast<unsigned long long>(width),
    static_cast<unsigned long long>(height),
    attached ? 1 : 0,
    rendered ? 1 : 0
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
  const bool resized = attach_or_resize(
    reinterpret_cast<uint64_t>(window),
    static_cast<int32_t>(width > 0 ? width : 1),
    static_cast<int32_t>(height > 0 ? height : 1),
    1.0
  );
  const bool rendered = MOUI_MOBILE_RENDER_FRAME() != 0;
  log_info(
    "XComponent surface changed width=%{public}llu height=%{public}llu resize=%{public}d render=%{public}d",
    static_cast<unsigned long long>(width),
    static_cast<unsigned long long>(height),
    resized ? 1 : 0,
    rendered ? 1 : 0
  );
}

void on_surface_destroyed(OH_NativeXComponent *component, void *window) {
  (void)component;
  (void)window;
  ensure_moonbit_runtime();
  MOUI_MOBILE_DETACH_SURFACE();
  g_surface_handle = 0;
  log_info("XComponent surface destroyed detach=1");
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
  const bool dispatched = MOUI_MOBILE_DISPATCH_POINTER(
    static_cast<int32_t>(xcomponent_touch_phase(event.type)),
    event.x,
    event.y,
    0.0
  ) != 0;
  const bool rendered = MOUI_MOBILE_RENDER_FRAME() != 0;
  log_info(
    "XComponent touch type=%{public}d x=%{public}f y=%{public}f dispatch=%{public}d render=%{public}d",
    static_cast<int>(event.type),
    event.x,
    event.y,
    dispatched ? 1 : 0,
    rendered ? 1 : 0
  );
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

napi_value napi_render_frame(napi_env env, napi_callback_info info) {
  (void)info;
  ensure_moonbit_runtime();
  const bool rendered = MOUI_MOBILE_RENDER_FRAME() != 0;
  log_info("NAPI renderFrame result=%{public}d", rendered ? 1 : 0);
  return napi_bool(env, rendered);
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
