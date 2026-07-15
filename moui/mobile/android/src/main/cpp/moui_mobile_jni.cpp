#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>

#include "moui_mobile_runtime_v1.h"

#include <cstdint>
#include <cstring>
#include <limits>
#include <mutex>
#include <string>
#include <vector>

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

constexpr const char *kLogTag = "MoUIMobile";
constexpr const char *kNativeBridgeClass =
    "dev/wzzc/moui/mobile/MoUINativeBridge";

const moui_mobile_runtime_api_v1 *g_runtime_api = nullptr;
std::once_flag g_initialize_once;
int32_t g_initialize_result = MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1;
ANativeWindow *g_window = nullptr;
std::mutex g_window_mutex;

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

bool append_utf8(uint32_t code_point, std::string *output) {
  if (output == nullptr || code_point > UINT32_C(0x10FFFF) ||
      (code_point >= UINT32_C(0xD800) && code_point <= UINT32_C(0xDFFF))) {
    return false;
  }
  if (code_point <= UINT32_C(0x7F)) {
    output->push_back(static_cast<char>(code_point));
  } else if (code_point <= UINT32_C(0x7FF)) {
    output->push_back(static_cast<char>(UINT32_C(0xC0) | (code_point >> 6)));
    output->push_back(
        static_cast<char>(UINT32_C(0x80) | (code_point & UINT32_C(0x3F))));
  } else if (code_point <= UINT32_C(0xFFFF)) {
    output->push_back(static_cast<char>(UINT32_C(0xE0) | (code_point >> 12)));
    output->push_back(static_cast<char>(UINT32_C(0x80) |
                                        ((code_point >> 6) & UINT32_C(0x3F))));
    output->push_back(
        static_cast<char>(UINT32_C(0x80) | (code_point & UINT32_C(0x3F))));
  } else {
    output->push_back(static_cast<char>(UINT32_C(0xF0) | (code_point >> 18)));
    output->push_back(static_cast<char>(UINT32_C(0x80) |
                                        ((code_point >> 12) & UINT32_C(0x3F))));
    output->push_back(static_cast<char>(UINT32_C(0x80) |
                                        ((code_point >> 6) & UINT32_C(0x3F))));
    output->push_back(
        static_cast<char>(UINT32_C(0x80) | (code_point & UINT32_C(0x3F))));
  }
  return true;
}

bool utf8_from_java(JNIEnv *env, jstring value, std::string *output) {
  if (env == nullptr || output == nullptr) {
    return false;
  }
  output->clear();
  if (value == nullptr) {
    return true;
  }

  const jsize length = env->GetStringLength(value);
  const jchar *units = env->GetStringChars(value, nullptr);
  if (units == nullptr) {
    return false;
  }

  bool valid = true;
  try {
    output->reserve(static_cast<size_t>(length));
    for (jsize index = 0; index < length; ++index) {
      uint32_t code_point = units[index];
      if (code_point >= UINT32_C(0xD800) && code_point <= UINT32_C(0xDBFF)) {
        if (index + 1 >= length) {
          valid = false;
          break;
        }
        const uint32_t low = units[++index];
        if (low < UINT32_C(0xDC00) || low > UINT32_C(0xDFFF)) {
          valid = false;
          break;
        }
        code_point = UINT32_C(0x10000) +
                     ((code_point - UINT32_C(0xD800)) << 10) +
                     (low - UINT32_C(0xDC00));
      } else if (code_point >= UINT32_C(0xDC00) &&
                 code_point <= UINT32_C(0xDFFF)) {
        valid = false;
        break;
      }
      if (!append_utf8(code_point, output)) {
        valid = false;
        break;
      }
    }
  } catch (...) {
    valid = false;
  }

  env->ReleaseStringChars(value, units);
  if (!valid) {
    output->clear();
  }
  return valid;
}

bool continuation(uint8_t value) {
  return (value & UINT8_C(0xC0)) == UINT8_C(0x80);
}

bool utf16_from_utf8(const uint8_t *data, size_t length,
                     std::vector<jchar> *output) {
  if (output == nullptr || (data == nullptr && length != 0) ||
      length > static_cast<size_t>(std::numeric_limits<jsize>::max())) {
    return false;
  }
  output->clear();
  try {
    output->reserve(length);
    size_t index = 0;
    while (index < length) {
      const uint8_t first = data[index];
      uint32_t code_point = 0;
      size_t width = 0;
      if (first <= UINT8_C(0x7F)) {
        code_point = first;
        width = 1;
      } else if (first >= UINT8_C(0xC2) && first <= UINT8_C(0xDF) &&
                 index + 1 < length && continuation(data[index + 1])) {
        code_point = (static_cast<uint32_t>(first & UINT8_C(0x1F)) << 6) |
                     static_cast<uint32_t>(data[index + 1] & UINT8_C(0x3F));
        width = 2;
      } else if (first >= UINT8_C(0xE0) && first <= UINT8_C(0xEF) &&
                 index + 2 < length && continuation(data[index + 1]) &&
                 continuation(data[index + 2])) {
        const uint8_t second = data[index + 1];
        if ((first == UINT8_C(0xE0) && second < UINT8_C(0xA0)) ||
            (first == UINT8_C(0xED) && second > UINT8_C(0x9F))) {
          return false;
        }
        code_point = (static_cast<uint32_t>(first & UINT8_C(0x0F)) << 12) |
                     (static_cast<uint32_t>(second & UINT8_C(0x3F)) << 6) |
                     static_cast<uint32_t>(data[index + 2] & UINT8_C(0x3F));
        width = 3;
      } else if (first >= UINT8_C(0xF0) && first <= UINT8_C(0xF4) &&
                 index + 3 < length && continuation(data[index + 1]) &&
                 continuation(data[index + 2]) &&
                 continuation(data[index + 3])) {
        const uint8_t second = data[index + 1];
        if ((first == UINT8_C(0xF0) && second < UINT8_C(0x90)) ||
            (first == UINT8_C(0xF4) && second > UINT8_C(0x8F))) {
          return false;
        }
        code_point =
            (static_cast<uint32_t>(first & UINT8_C(0x07)) << 18) |
            (static_cast<uint32_t>(second & UINT8_C(0x3F)) << 12) |
            (static_cast<uint32_t>(data[index + 2] & UINT8_C(0x3F)) << 6) |
            static_cast<uint32_t>(data[index + 3] & UINT8_C(0x3F));
        width = 4;
      } else {
        return false;
      }

      if (code_point <= UINT32_C(0xFFFF)) {
        output->push_back(static_cast<jchar>(code_point));
      } else {
        code_point -= UINT32_C(0x10000);
        output->push_back(
            static_cast<jchar>(UINT32_C(0xD800) | (code_point >> 10)));
        output->push_back(static_cast<jchar>(UINT32_C(0xDC00) |
                                             (code_point & UINT32_C(0x3FF))));
      }
      index += width;
    }
  } catch (...) {
    output->clear();
    return false;
  }
  return output->size() <=
         static_cast<size_t>(std::numeric_limits<jsize>::max());
}

std::string consume_utf8_buffer(moui_mobile_utf8_buffer_v1 raw,
                                const char *operation) {
  OwnedUtf8Buffer buffer(raw);
  const auto &value = buffer.get();
  if (value.status != MOUI_MOBILE_RUNTIME_STATUS_OK_V1 ||
      value.data == nullptr || value.release == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "moui-mobile ABI buffer failure operation=%s status=%d",
                        operation, value.status);
    return {};
  }
  return std::string(reinterpret_cast<const char *>(value.data), value.length);
}

jstring java_string_from_buffer(JNIEnv *env, moui_mobile_utf8_buffer_v1 raw,
                                const char *operation) {
  OwnedUtf8Buffer buffer(raw);
  const auto &value = buffer.get();
  if (value.status != MOUI_MOBILE_RUNTIME_STATUS_OK_V1 ||
      value.data == nullptr || value.release == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "moui-mobile ABI buffer failure operation=%s status=%d",
                        operation, value.status);
    return env->NewStringUTF("");
  }

  std::vector<jchar> units;
  if (!utf16_from_utf8(value.data, value.length, &units)) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "moui-mobile ABI returned invalid UTF-8 operation=%s",
                        operation);
    return env->NewStringUTF("");
  }
  const jchar empty = 0;
  return env->NewString(units.empty() ? &empty : units.data(),
                        static_cast<jsize>(units.size()));
}

bool ensure_runtime_initialized() {
  if (g_runtime_api == nullptr) {
    return false;
  }
  std::call_once(g_initialize_once, [] {
    g_initialize_result =
        g_runtime_api->initialize(utf8_view(MOUI_MOBILE_APP_ARG));
    if (g_initialize_result != MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1) {
      __android_log_print(
          ANDROID_LOG_ERROR, kLogTag,
          "moui-mobile runtime initialization failed app=%s status=%d",
          MOUI_MOBILE_APP_ID, g_initialize_result);
      return;
    }

    const int32_t renderer_configured = g_runtime_api->configure_renderer(
        utf8_view(MOUI_MOBILE_RENDERER_REQUESTED));
    const std::string renderer_status = consume_utf8_buffer(
        g_runtime_api->renderer_status_json(), "renderer-status");
    __android_log_print(ANDROID_LOG_INFO, kLogTag,
                        "moui-mobile runtime initialized app=%s "
                        "renderer-requested=%s renderer-selected=%s",
                        MOUI_MOBILE_APP_ID, MOUI_MOBILE_RENDERER_REQUESTED,
                        MOUI_MOBILE_RENDERER_SELECTED);
    __android_log_print(
        renderer_configured == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1
            ? ANDROID_LOG_INFO
            : ANDROID_LOG_WARN,
        kLogTag,
        "moui-mobile renderer configure requested=%s status=%d detail=%s",
        MOUI_MOBILE_RENDERER_REQUESTED, renderer_configured,
        renderer_status.c_str());
  });
  return g_initialize_result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1;
}

jboolean boolean_result(const char *operation, int32_t result) {
  if (result < MOUI_MOBILE_RUNTIME_STATUS_OK_V1) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "moui-mobile ABI call failed operation=%s status=%d",
                        operation, result);
  }
  return result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1 ? JNI_TRUE : JNI_FALSE;
}

void release_window_locked() {
  if (g_window != nullptr) {
    ANativeWindow_release(g_window);
    g_window = nullptr;
  }
}

jboolean native_attach_surface(JNIEnv *env, jclass, jobject surface, jint width,
                               jint height, jdouble density) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  if (surface == nullptr) {
    return JNI_FALSE;
  }
  ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
  if (window == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "failed to acquire ANativeWindow app=%s",
                        MOUI_MOBILE_APP_ID);
    return JNI_FALSE;
  }

  const int32_t result = g_runtime_api->attach_surface(
      reinterpret_cast<uint64_t>(window), width, height, density);
  if (result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1) {
    std::lock_guard<std::mutex> lock(g_window_mutex);
    release_window_locked();
    g_window = window;
  } else {
    ANativeWindow_release(window);
  }
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "moui-mobile attach app=%s status=%d width=%d height=%d",
                      MOUI_MOBILE_APP_ID, result, width, height);
  return boolean_result("attach-surface", result);
}

jboolean native_renderer_configure(JNIEnv *env, jclass, jstring mode) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  std::string encoded;
  if (!utf8_from_java(env, mode, &encoded)) {
    return JNI_FALSE;
  }
  return boolean_result("renderer-configure",
                        g_runtime_api->configure_renderer(utf8_view(encoded)));
}

jstring native_renderer_status_json(JNIEnv *env, jclass) {
  if (!ensure_runtime_initialized()) {
    return env->NewStringUTF("");
  }
  return java_string_from_buffer(env, g_runtime_api->renderer_status_json(),
                                 "renderer-status");
}

jboolean native_resize(JNIEnv *, jclass, jint width, jint height,
                       jdouble density) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  return boolean_result("resize",
                        g_runtime_api->resize(width, height, density));
}

jboolean native_dispatch_pointer(JNIEnv *, jclass, jint phase, jdouble x,
                                 jdouble y, jdouble time_ms) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  return boolean_result("dispatch-pointer",
                        g_runtime_api->dispatch_pointer(phase, x, y, time_ms));
}

jboolean native_dispatch_scroll(JNIEnv *, jclass, jdouble x, jdouble y,
                                jdouble delta_x, jdouble delta_y, jint phase) {
  if (!ensure_runtime_initialized() ||
      g_runtime_api->dispatch_scroll == nullptr) {
    return JNI_FALSE;
  }
  return boolean_result("dispatch-scroll", g_runtime_api->dispatch_scroll(
                                               x, y, delta_x, delta_y, phase));
}

jboolean native_render_frame(JNIEnv *, jclass) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  return boolean_result("render-frame", g_runtime_api->render_frame());
}

jboolean native_frame_tick(JNIEnv *, jclass, jdouble time_ms) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  return boolean_result("frame-tick", g_runtime_api->frame_tick(time_ms));
}

jstring native_take_host_updates(JNIEnv *env, jclass) {
  if (!ensure_runtime_initialized()) {
    return env->NewStringUTF("");
  }
  return java_string_from_buffer(
      env, g_runtime_api->take_host_update_envelope_json(),
      "take-host-update-envelope");
}

jboolean native_dispatch_host_response_envelope(JNIEnv *env, jclass,
                                                jstring envelope_json) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  std::string encoded;
  if (!utf8_from_java(env, envelope_json, &encoded)) {
    return JNI_FALSE;
  }
  return boolean_result(
      "dispatch-host-response-envelope",
      g_runtime_api->dispatch_host_response_envelope(utf8_view(encoded)));
}

jboolean native_dispatch_text_input(JNIEnv *env, jclass, jint kind,
                                    jstring text, jint start, jint end) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  std::string encoded;
  if (!utf8_from_java(env, text, &encoded)) {
    return JNI_FALSE;
  }
  return boolean_result(
      "dispatch-text-input",
      g_runtime_api->dispatch_text_input(kind, utf8_view(encoded), start, end));
}

jboolean native_dispatch_command(JNIEnv *, jclass, jint kind) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  return boolean_result("dispatch-command",
                        g_runtime_api->dispatch_command(kind));
}

jboolean native_dispatch_accessibility(JNIEnv *env, jclass, jint element_id,
                                       jint action, jstring value) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  std::string encoded;
  if (!utf8_from_java(env, value, &encoded)) {
    return JNI_FALSE;
  }
  return boolean_result("dispatch-accessibility",
                        g_runtime_api->dispatch_accessibility(
                            element_id, action, utf8_view(encoded)));
}

jboolean native_complete_clipboard(JNIEnv *env, jclass, jint session_generation,
                                   jint id, jint kind, jstring text,
                                   jbyteArray bytes) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  std::string encoded_text;
  if (!utf8_from_java(env, text, &encoded_text)) {
    return JNI_FALSE;
  }

  std::vector<uint8_t> encoded_bytes;
  if (bytes != nullptr) {
    const jsize length = env->GetArrayLength(bytes);
    try {
      encoded_bytes.resize(static_cast<size_t>(length));
    } catch (...) {
      return JNI_FALSE;
    }
    if (length != 0) {
      env->GetByteArrayRegion(bytes, 0, length,
                              reinterpret_cast<jbyte *>(encoded_bytes.data()));
      if (env->ExceptionCheck()) {
        return JNI_FALSE;
      }
    }
  }

  const moui_mobile_bytes_view_v1 byte_view = {
      encoded_bytes.empty() ? nullptr : encoded_bytes.data(),
      encoded_bytes.size(),
  };
  return boolean_result(
      "complete-clipboard",
      g_runtime_api->complete_clipboard(session_generation, id, kind,
                                        utf8_view(encoded_text), byte_view));
}

void native_detach_surface(JNIEnv *, jclass) {
  if (!ensure_runtime_initialized()) {
    return;
  }
  const int32_t result = g_runtime_api->detach_surface();
  {
    std::lock_guard<std::mutex> lock(g_window_mutex);
    release_window_locked();
  }
  boolean_result("detach-surface", result);
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "moui-mobile detach app=%s status=%d", MOUI_MOBILE_APP_ID,
                      result);
}

jboolean native_destroy_application(JNIEnv *, jclass) {
  if (!ensure_runtime_initialized()) {
    return JNI_FALSE;
  }
  const int32_t result = g_runtime_api->destroy_application();
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "moui-mobile application destroy app=%s status=%d",
                      MOUI_MOBILE_APP_ID, result);
  return boolean_result("destroy-application", result);
}

#define MOUI_JNI_METHOD(name, descriptor, function)                            \
  {                                                                            \
    const_cast<char *>(name), const_cast<char *>(descriptor),                  \
        reinterpret_cast<void *>(function)                                     \
  }

const JNINativeMethod kNativeMethods[] = {
    MOUI_JNI_METHOD("attachSurface", "(Landroid/view/Surface;IID)Z",
                    native_attach_surface),
    MOUI_JNI_METHOD("resize", "(IID)Z", native_resize),
    MOUI_JNI_METHOD("dispatchPointer", "(IDDD)Z", native_dispatch_pointer),
    MOUI_JNI_METHOD("dispatchScroll", "(DDDDI)Z", native_dispatch_scroll),
    MOUI_JNI_METHOD("frameTick", "(D)Z", native_frame_tick),
    MOUI_JNI_METHOD("takeHostUpdates", "()Ljava/lang/String;",
                    native_take_host_updates),
    MOUI_JNI_METHOD("dispatchHostResponseEnvelope", "(Ljava/lang/String;)Z",
                    native_dispatch_host_response_envelope),
    MOUI_JNI_METHOD("dispatchTextInput", "(ILjava/lang/String;II)Z",
                    native_dispatch_text_input),
    MOUI_JNI_METHOD("dispatchCommand", "(I)Z", native_dispatch_command),
    MOUI_JNI_METHOD("dispatchAccessibility", "(IILjava/lang/String;)Z",
                    native_dispatch_accessibility),
    MOUI_JNI_METHOD("completeClipboard", "(IIILjava/lang/String;[B)Z",
                    native_complete_clipboard),
    MOUI_JNI_METHOD("renderFrame", "()Z", native_render_frame),
    MOUI_JNI_METHOD("detachSurface", "()V", native_detach_surface),
    MOUI_JNI_METHOD("destroyApplication", "()Z", native_destroy_application),
    MOUI_JNI_METHOD("rendererConfigure", "(Ljava/lang/String;)Z",
                    native_renderer_configure),
    MOUI_JNI_METHOD("rendererStatusJson", "()Ljava/lang/String;",
                    native_renderer_status_json),
};

#undef MOUI_JNI_METHOD

} // namespace

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
  const moui_mobile_runtime_api_v1 *runtime_api =
      moui_mobile_get_runtime_api_v1();
  if (!moui_mobile_runtime_api_v1_is_compatible(runtime_api)) {
    __android_log_print(
        ANDROID_LOG_ERROR, kLogTag,
        "incompatible MoUI mobile runtime ABI expected=%u actual=%u size=%u "
        "capabilities=%llu",
        MOUI_MOBILE_RUNTIME_ABI_VERSION_V1,
        runtime_api == nullptr ? 0 : runtime_api->abi_version,
        runtime_api == nullptr ? 0 : runtime_api->struct_size,
        static_cast<unsigned long long>(
            runtime_api == nullptr ? 0 : runtime_api->capabilities));
    return JNI_ERR;
  }
  g_runtime_api = runtime_api;

  JNIEnv *env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK ||
      env == nullptr) {
    return JNI_ERR;
  }
  jclass bridge = env->FindClass(kNativeBridgeClass);
  if (bridge == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "failed to find managed native bridge class=%s",
                        kNativeBridgeClass);
    return JNI_ERR;
  }
  constexpr jint method_count =
      static_cast<jint>(sizeof(kNativeMethods) / sizeof(kNativeMethods[0]));
  const jint registered =
      env->RegisterNatives(bridge, kNativeMethods, method_count);
  env->DeleteLocalRef(bridge);
  if (registered != JNI_OK) {
    __android_log_print(
        ANDROID_LOG_ERROR, kLogTag,
        "failed to register managed native bridge methods count=%d",
        method_count);
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}
