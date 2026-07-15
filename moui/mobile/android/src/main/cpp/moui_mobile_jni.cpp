#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>
#include <moonbit.h>

#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>

#ifndef MOUI_MOBILE_APP_ARG
#define MOUI_MOBILE_APP_ARG "moui-mobile-android"
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

namespace {

std::string std_string_from_moonbit(moonbit_string_t value);

constexpr const char *kLogTag = "MoUIMobile";
std::once_flag g_init_once;
ANativeWindow *g_window = nullptr;
std::mutex g_window_mutex;

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
extern "C" int32_t MOUI_MOBILE_FRAME_TICK(double time_ms);
extern "C" int32_t MOUI_MOBILE_RENDER_FRAME(void);
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

void ensure_moonbit_runtime() {
  std::call_once(g_init_once, [] {
    static char app_name[] = MOUI_MOBILE_APP_ARG;
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
    moonbit_string_t renderer_mode = moonbit_string_from_ascii(
        MOUI_MOBILE_RENDERER_REQUESTED);
    const int32_t renderer_configured = moui_mobile_renderer_configure(
        renderer_mode);
    moonbit_decref(renderer_mode);
    __android_log_print(
        ANDROID_LOG_INFO,
        kLogTag,
        "moui-mobile runtime initialized app=%s renderer-requested=%s renderer-selected=%s",
        MOUI_MOBILE_APP_ID,
        MOUI_MOBILE_RENDERER_REQUESTED,
        MOUI_MOBILE_RENDERER_SELECTED);
    __android_log_print(
        renderer_configured != 0 ? ANDROID_LOG_INFO : ANDROID_LOG_WARN,
        kLogTag,
        "moui-mobile renderer configure requested=%s ok=%d status=%s",
        MOUI_MOBILE_RENDERER_REQUESTED,
        renderer_configured,
        std_string_from_moonbit(moui_mobile_renderer_status_json()).c_str());
  });
}

void release_window_locked() {
  if (g_window != nullptr) {
    ANativeWindow_release(g_window);
    g_window = nullptr;
  }
}

moonbit_string_t moonbit_string_from_java(JNIEnv *env, jstring value) {
  if (value == nullptr) {
    return moonbit_make_string(0, 0);
  }
  const jsize length = env->GetStringLength(value);
  moonbit_string_t result = moonbit_make_string_raw(length);
  env->GetStringRegion(value, 0, length, reinterpret_cast<jchar *>(result));
  return result;
}

jstring java_string_from_moonbit(JNIEnv *env, moonbit_string_t value) {
  if (value == nullptr) {
    return env->NewStringUTF("");
  }
  const int32_t length = Moonbit_array_length(value);
  jstring result = env->NewString(reinterpret_cast<const jchar *>(value), length);
  moonbit_decref(value);
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

moonbit_bytes_t moonbit_bytes_from_java(JNIEnv *env, jbyteArray value) {
  if (value == nullptr) {
    return moonbit_make_bytes(0, 0);
  }
  const jsize length = env->GetArrayLength(value);
  moonbit_bytes_t result = moonbit_make_bytes_raw(length);
  env->GetByteArrayRegion(
      value,
      0,
      length,
      reinterpret_cast<jbyte *>(result));
  return result;
}

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeAttachSurface(
    JNIEnv *env,
    jclass,
    jobject surface,
    jint width,
    jint height,
    jdouble density) {
  ensure_moonbit_runtime();
  ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
  if (window == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag, "failed to acquire ANativeWindow app=%s", MOUI_MOBILE_APP_ID);
    return JNI_FALSE;
  }

  {
    std::lock_guard<std::mutex> lock(g_window_mutex);
    release_window_locked();
    g_window = window;
  }

  const int32_t ok = MOUI_MOBILE_ATTACH_SURFACE(
      reinterpret_cast<uint64_t>(window),
      width,
      height,
      density);
  __android_log_print(ANDROID_LOG_INFO, kLogTag, "moui-mobile attach app=%s ok=%d width=%d height=%d", MOUI_MOBILE_APP_ID, ok, width, height);
  return ok != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeRendererConfigure(
    JNIEnv *env,
    jclass,
    jstring mode) {
  ensure_moonbit_runtime();
  moonbit_string_t native_mode = moonbit_string_from_java(env, mode);
  const int32_t configured = moui_mobile_renderer_configure(native_mode);
  moonbit_decref(native_mode);
  return configured != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeRendererStatusJson(
    JNIEnv *env,
    jclass) {
  ensure_moonbit_runtime();
  return java_string_from_moonbit(env, moui_mobile_renderer_status_json());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeResize(
    JNIEnv *,
    jclass,
    jint width,
    jint height,
    jdouble density) {
  ensure_moonbit_runtime();
  return MOUI_MOBILE_RESIZE(width, height, density) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDispatchPointer(
    JNIEnv *,
    jclass,
    jint phase,
    jdouble x,
    jdouble y,
    jdouble time_ms) {
  ensure_moonbit_runtime();
  return MOUI_MOBILE_DISPATCH_POINTER(phase, x, y, time_ms) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDispatchScroll(
    JNIEnv *,
    jclass,
    jdouble x,
    jdouble y,
    jdouble delta_x,
    jdouble delta_y,
    jint phase) {
  ensure_moonbit_runtime();
#if MOUI_MOBILE_ENABLE_SCROLL
  return MOUI_MOBILE_DISPATCH_SCROLL(x, y, delta_x, delta_y, phase) != 0 ? JNI_TRUE : JNI_FALSE;
#else
  (void)x;
  (void)y;
  (void)delta_x;
  (void)delta_y;
  (void)phase;
  return JNI_FALSE;
#endif
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeRenderFrame(JNIEnv *, jclass) {
  ensure_moonbit_runtime();
  return MOUI_MOBILE_RENDER_FRAME() != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeFrameTick(
    JNIEnv *,
    jclass,
    jdouble time_ms) {
  ensure_moonbit_runtime();
  return MOUI_MOBILE_FRAME_TICK(time_ms) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeTakeHostUpdates(
    JNIEnv *env,
    jclass) {
  ensure_moonbit_runtime();
  return java_string_from_moonbit(env, moui_mobile_take_host_updates_json());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDispatchTextInput(
    JNIEnv *env,
    jclass,
    jint kind,
    jstring text,
    jint start,
    jint end) {
  ensure_moonbit_runtime();
  moonbit_string_t native_text = moonbit_string_from_java(env, text);
  const int32_t result = moui_mobile_dispatch_text_input(
      kind, native_text, start, end);
  moonbit_decref(native_text);
  return result != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDispatchCommand(
    JNIEnv *,
    jclass,
    jint kind) {
  ensure_moonbit_runtime();
  return moui_mobile_dispatch_command(kind) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDispatchAccessibility(
    JNIEnv *env,
    jclass,
    jint element_id,
    jint action,
    jstring value) {
  ensure_moonbit_runtime();
  moonbit_string_t native_value = moonbit_string_from_java(env, value);
  const int32_t result = moui_mobile_dispatch_accessibility(
      element_id, action, native_value);
  moonbit_decref(native_value);
  return result != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeCompleteClipboard(
    JNIEnv *env,
    jclass,
    jint id,
    jint kind,
    jstring text,
    jbyteArray bytes) {
  ensure_moonbit_runtime();
  moonbit_string_t native_text = moonbit_string_from_java(env, text);
  moonbit_bytes_t native_bytes = moonbit_bytes_from_java(env, bytes);
  const int32_t result = moui_mobile_complete_clipboard(
      id, kind, native_text, native_bytes);
  moonbit_decref(native_text);
  moonbit_decref(native_bytes);
  return result != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDetachSurface(JNIEnv *, jclass) {
  ensure_moonbit_runtime();
  MOUI_MOBILE_DETACH_SURFACE();
  std::lock_guard<std::mutex> lock(g_window_mutex);
  release_window_locked();
  __android_log_print(ANDROID_LOG_INFO, kLogTag, "moui-mobile detach app=%s", MOUI_MOBILE_APP_ID);
}
