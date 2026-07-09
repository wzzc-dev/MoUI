#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>

#include <cstdint>
#include <mutex>

namespace {

constexpr const char *kLogTag = "ComponentGallery";
std::once_flag g_init_once;
ANativeWindow *g_window = nullptr;
std::mutex g_window_mutex;

extern "C" void moonbit_runtime_init(int argc, char **argv);
extern "C" void moonbit_init(void);

extern "C" int32_t component_gallery_android_attach_surface(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor);
extern "C" int32_t component_gallery_android_resize(
    int32_t width,
    int32_t height,
    double scale_factor);
extern "C" int32_t component_gallery_android_dispatch_pointer(
    int32_t phase,
    double x,
    double y,
    double time_ms);
extern "C" int32_t component_gallery_android_dispatch_scroll(
    double x,
    double y,
    double delta_x,
    double delta_y,
    int32_t phase);
extern "C" int32_t component_gallery_android_render_frame(void);
extern "C" void component_gallery_android_detach_surface(void);

void ensure_moonbit_runtime() {
  std::call_once(g_init_once, [] {
    static char app_name[] = "moui-component-gallery-android";
    static char *argv[] = {app_name};
    moonbit_runtime_init(1, argv);
    moonbit_init();
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
Java_dev_wzzc_moui_componentgallery_MainActivity_nativeAttachSurface(
    JNIEnv *env,
    jclass,
    jobject surface,
    jint width,
    jint height,
    jdouble density) {
  ensure_moonbit_runtime();
  ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
  if (window == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag, "failed to acquire ANativeWindow");
    return JNI_FALSE;
  }

  {
    std::lock_guard<std::mutex> lock(g_window_mutex);
    release_window_locked();
    g_window = window;
  }

  const int32_t ok = component_gallery_android_attach_surface(
      reinterpret_cast<uint64_t>(window),
      width,
      height,
      density);
  return ok != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_componentgallery_MainActivity_nativeResize(
    JNIEnv *,
    jclass,
    jint width,
    jint height,
    jdouble density) {
  ensure_moonbit_runtime();
  return component_gallery_android_resize(width, height, density) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_componentgallery_MainActivity_nativeDispatchPointer(
    JNIEnv *,
    jclass,
    jint phase,
    jdouble x,
    jdouble y,
    jdouble time_ms) {
  ensure_moonbit_runtime();
  return component_gallery_android_dispatch_pointer(phase, x, y, time_ms) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_componentgallery_MainActivity_nativeDispatchScroll(
    JNIEnv *,
    jclass,
    jdouble x,
    jdouble y,
    jdouble delta_x,
    jdouble delta_y,
    jint phase) {
  ensure_moonbit_runtime();
  return component_gallery_android_dispatch_scroll(x, y, delta_x, delta_y, phase) != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_wzzc_moui_componentgallery_MainActivity_nativeRenderFrame(
    JNIEnv *,
    jclass) {
  ensure_moonbit_runtime();
  return component_gallery_android_render_frame() != 0 ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_dev_wzzc_moui_componentgallery_MainActivity_nativeDetachSurface(JNIEnv *, jclass) {
  ensure_moonbit_runtime();
  component_gallery_android_detach_surface();
  std::lock_guard<std::mutex> lock(g_window_mutex);
  release_window_locked();
}
