#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>

#include <cstdint>
#include <mutex>

#ifndef MOUI_MOBILE_APP_ARG
#define MOUI_MOBILE_APP_ARG "moui-mobile-android"
#endif

#ifndef MOUI_MOBILE_APP_ID
#define MOUI_MOBILE_APP_ID "unknown"
#endif

namespace {

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
extern "C" int32_t MOUI_MOBILE_RENDER_FRAME(void);
extern "C" void MOUI_MOBILE_DETACH_SURFACE(void);

void ensure_moonbit_runtime() {
  std::call_once(g_init_once, [] {
    static char app_name[] = MOUI_MOBILE_APP_ARG;
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
    __android_log_print(ANDROID_LOG_INFO, kLogTag, "moui-mobile runtime initialized app=%s", MOUI_MOBILE_APP_ID);
  });
}

void release_window_locked() {
  if (g_window != nullptr) {
    ANativeWindow_release(g_window);
    g_window = nullptr;
  }
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

extern "C" JNIEXPORT void JNICALL
Java_dev_wzzc_moui_mobile_MobileActivity_nativeDetachSurface(JNIEnv *, jclass) {
  ensure_moonbit_runtime();
  MOUI_MOBILE_DETACH_SURFACE();
  std::lock_guard<std::mutex> lock(g_window_mutex);
  release_window_locked();
  __android_log_print(ANDROID_LOG_INFO, kLogTag, "moui-mobile detach app=%s", MOUI_MOBILE_APP_ID);
}
