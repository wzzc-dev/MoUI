#define MOUI_EMBEDDING_API_IMPLEMENTATION 1
#include "moui_embedding_api_v1.h"

// Include libc string headers before moonbit.h so memcpy keeps the system
// exception specifier; moonbit.h may redeclare memcpy without noexcept.
#include <cstring>
#include <string.h>
#include <moonbit.h>

#include <atomic>
#include <cmath>
#include <cstdlib>
#include <limits>
#include <mutex>

#ifndef MOUI_EMBEDDING_API_ATTACH_SURFACE
#define MOUI_EMBEDDING_API_ATTACH_SURFACE moui_embedding_attach_surface
#endif
#ifndef MOUI_EMBEDDING_API_RESIZE
#define MOUI_EMBEDDING_API_RESIZE moui_embedding_resize
#endif
#ifndef MOUI_EMBEDDING_API_DISPATCH_POINTER
#define MOUI_EMBEDDING_API_DISPATCH_POINTER moui_embedding_dispatch_pointer
#endif
#ifndef MOUI_EMBEDDING_API_FRAME_TICK
#define MOUI_EMBEDDING_API_FRAME_TICK moui_embedding_frame_tick
#endif
#ifndef MOUI_EMBEDDING_API_RENDER_FRAME
#define MOUI_EMBEDDING_API_RENDER_FRAME moui_embedding_render_frame
#endif
#ifndef MOUI_EMBEDDING_API_DETACH_SURFACE
#define MOUI_EMBEDDING_API_DETACH_SURFACE moui_embedding_detach_surface
#endif
#ifndef MOUI_EMBEDDING_API_DESTROY_APPLICATION
#define MOUI_EMBEDDING_API_DESTROY_APPLICATION moui_embedding_destroy_application
#endif

#ifndef MOUI_EMBEDDING_API_ENABLE_SCROLL
#define MOUI_EMBEDDING_API_ENABLE_SCROLL 1
#endif

#ifndef MOUI_EMBEDDING_API_DISPATCH_SCROLL
#define MOUI_EMBEDDING_API_DISPATCH_SCROLL moui_embedding_dispatch_scroll
#endif

#ifndef MOUI_EMBEDDING_API_INIT
#define MOUI_EMBEDDING_API_INIT moonbit_runtime_init
#endif
#ifndef MOUI_EMBEDDING_API_APP_INIT
#define MOUI_EMBEDDING_API_APP_INIT moonbit_init
#endif
#ifndef MOUI_EMBEDDING_API_RENDERER_CONFIGURE
#define MOUI_EMBEDDING_API_RENDERER_CONFIGURE moui_embedding_renderer_configure
#endif
#ifndef MOUI_EMBEDDING_API_RENDERER_STATUS_JSON
#define MOUI_EMBEDDING_API_RENDERER_STATUS_JSON \
  moui_embedding_renderer_status_json
#endif
#ifndef MOUI_EMBEDDING_API_TAKE_HOST_UPDATE_ENVELOPE_JSON
#define MOUI_EMBEDDING_API_TAKE_HOST_UPDATE_ENVELOPE_JSON \
  moui_embedding_take_host_update_envelope_json
#endif
#ifndef MOUI_EMBEDDING_API_DISPATCH_HOST_RESPONSE_ENVELOPE
#define MOUI_EMBEDDING_API_DISPATCH_HOST_RESPONSE_ENVELOPE \
  moui_embedding_dispatch_host_response_envelope_json
#endif
#ifndef MOUI_EMBEDDING_API_DISPATCH_TEXT_INPUT
#define MOUI_EMBEDDING_API_DISPATCH_TEXT_INPUT \
  moui_embedding_dispatch_text_input
#endif
#ifndef MOUI_EMBEDDING_API_DISPATCH_COMMAND
#define MOUI_EMBEDDING_API_DISPATCH_COMMAND moui_embedding_dispatch_command
#endif
#ifndef MOUI_EMBEDDING_API_DISPATCH_ACCESSIBILITY
#define MOUI_EMBEDDING_API_DISPATCH_ACCESSIBILITY \
  moui_embedding_dispatch_accessibility
#endif
#ifndef MOUI_EMBEDDING_API_COMPLETE_CLIPBOARD
#define MOUI_EMBEDDING_API_COMPLETE_CLIPBOARD moui_embedding_complete_clipboard_v1
#endif
#ifndef MOUI_EMBEDDING_API_DECREF
#define MOUI_EMBEDDING_API_DECREF moonbit_decref
#else
extern "C" void MOUI_EMBEDDING_API_DECREF(void *value);
#endif

namespace {

extern "C" void MOUI_EMBEDDING_API_INIT(int argc, char **argv);
extern "C" void MOUI_EMBEDDING_API_APP_INIT(void);
#ifdef MOUI_EMBEDDING_API_APP_MAIN
extern "C" int MOUI_EMBEDDING_API_APP_MAIN(int argc, char **argv);
#endif

extern "C" int32_t MOUI_EMBEDDING_API_ATTACH_SURFACE(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor);
extern "C" int32_t MOUI_EMBEDDING_API_RESIZE(
    int32_t width,
    int32_t height,
    double scale_factor);
extern "C" int32_t MOUI_EMBEDDING_API_DISPATCH_POINTER(
    int32_t phase,
    double x,
    double y,
    double time_ms);
#if MOUI_EMBEDDING_API_ENABLE_SCROLL
extern "C" int32_t MOUI_EMBEDDING_API_DISPATCH_SCROLL(
    double x,
    double y,
    double delta_x,
    double delta_y,
    int32_t phase);
#endif
extern "C" int32_t MOUI_EMBEDDING_API_FRAME_TICK(double time_ms);
extern "C" int32_t MOUI_EMBEDDING_API_RENDER_FRAME(void);
extern "C" void MOUI_EMBEDDING_API_DETACH_SURFACE(void);
extern "C" void MOUI_EMBEDDING_API_DESTROY_APPLICATION(void);

extern "C" int32_t MOUI_EMBEDDING_API_RENDERER_CONFIGURE(
    moonbit_string_t mode);
extern "C" moonbit_string_t MOUI_EMBEDDING_API_RENDERER_STATUS_JSON(void);
extern "C" moonbit_string_t
MOUI_EMBEDDING_API_TAKE_HOST_UPDATE_ENVELOPE_JSON(void);
extern "C" int32_t MOUI_EMBEDDING_API_DISPATCH_HOST_RESPONSE_ENVELOPE(
    moonbit_string_t envelope_json);
extern "C" int32_t MOUI_EMBEDDING_API_DISPATCH_TEXT_INPUT(
    int32_t kind,
    moonbit_string_t text,
    int32_t start,
    int32_t end);
extern "C" int32_t MOUI_EMBEDDING_API_DISPATCH_COMMAND(int32_t kind);
extern "C" int32_t MOUI_EMBEDDING_API_DISPATCH_ACCESSIBILITY(
    int32_t element_id,
    int32_t action,
    moonbit_string_t value);
extern "C" int32_t MOUI_EMBEDDING_API_COMPLETE_CLIPBOARD(
    int32_t session_generation,
    int32_t id,
    int32_t kind,
    moonbit_string_t text,
    moonbit_bytes_t bytes);

/* These runtime conversion helpers are exported by runtime.c but moonbit.h
 * intentionally does not expose them. */
extern "C" int32_t moonbit_utf16_len_from_utf8(
    moonbit_bytes_t src,
    int32_t src_offset,
    int32_t src_length);
extern "C" int32_t moonbit_utf8_decode_into_utf16(
    moonbit_bytes_t src,
    int32_t src_offset,
    int32_t src_length,
    moonbit_string_t dst,
    int32_t dst_offset);
extern "C" int32_t moonbit_utf8_len_from_utf16(
    moonbit_string_t src,
    int32_t src_offset,
    int32_t src_length);
extern "C" int32_t moonbit_utf8_encode_from_utf16(
    moonbit_string_t src,
    int32_t src_offset,
    int32_t src_length,
    moonbit_bytes_t dst,
    int32_t dst_offset);

std::once_flag g_initialize_once;
std::atomic<int32_t> g_initialize_result{
    MOUI_EMBEDDING_API_ERROR_NOT_INITIALIZED_V1};
char *g_process_app_argument = nullptr;
char *g_process_argv[1] = {nullptr};

enum class ApplicationState : uint8_t {
  kUninitialized,
  kActive,
  kDestroying,
  kDestroyed,
};

std::atomic<ApplicationState> g_application_state{
    ApplicationState::kUninitialized};

class OwnedMoonbitRef final {
 public:
  explicit OwnedMoonbitRef(void *value = nullptr) : value_(value) {}

  OwnedMoonbitRef(const OwnedMoonbitRef &) = delete;
  OwnedMoonbitRef &operator=(const OwnedMoonbitRef &) = delete;

  OwnedMoonbitRef(OwnedMoonbitRef &&other) noexcept
      : value_(other.release()) {}

  OwnedMoonbitRef &operator=(OwnedMoonbitRef &&other) noexcept {
    if (this != &other) {
      if (value_ != nullptr) {
        MOUI_EMBEDDING_API_DECREF(value_);
      }
      value_ = other.release();
    }
    return *this;
  }

  ~OwnedMoonbitRef() {
    if (value_ != nullptr) {
      MOUI_EMBEDDING_API_DECREF(value_);
    }
  }

  void *get() const { return value_; }

  void *release() {
    void *result = value_;
    value_ = nullptr;
    return result;
  }

 private:
  void *value_;
};

bool is_continuation_byte(uint8_t value) {
  return (value & UINT8_C(0xC0)) == UINT8_C(0x80);
}

bool is_valid_utf8(const uint8_t *data, size_t length) {
  size_t index = 0;
  while (index < length) {
    const uint8_t first = data[index];
    if (first <= UINT8_C(0x7F)) {
      index += 1;
      continue;
    }

    if (first >= UINT8_C(0xC2) && first <= UINT8_C(0xDF)) {
      if (index + 1 >= length || !is_continuation_byte(data[index + 1])) {
        return false;
      }
      index += 2;
      continue;
    }

    if (first >= UINT8_C(0xE0) && first <= UINT8_C(0xEF)) {
      if (index + 2 >= length || !is_continuation_byte(data[index + 1]) ||
          !is_continuation_byte(data[index + 2])) {
        return false;
      }
      const uint8_t second = data[index + 1];
      if ((first == UINT8_C(0xE0) && second < UINT8_C(0xA0)) ||
          (first == UINT8_C(0xED) && second > UINT8_C(0x9F))) {
        return false;
      }
      index += 3;
      continue;
    }

    if (first >= UINT8_C(0xF0) && first <= UINT8_C(0xF4)) {
      if (index + 3 >= length || !is_continuation_byte(data[index + 1]) ||
          !is_continuation_byte(data[index + 2]) ||
          !is_continuation_byte(data[index + 3])) {
        return false;
      }
      const uint8_t second = data[index + 1];
      if ((first == UINT8_C(0xF0) && second < UINT8_C(0x90)) ||
          (first == UINT8_C(0xF4) && second > UINT8_C(0x8F))) {
        return false;
      }
      index += 4;
      continue;
    }

    return false;
  }
  return true;
}

int32_t validate_bytes_view(moui_embedding_bytes_view_v1 view) {
  if (view.data == nullptr && view.length != 0) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  if (view.length > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
    return MOUI_EMBEDDING_API_ERROR_INPUT_TOO_LARGE_V1;
  }
  return MOUI_EMBEDDING_API_STATUS_OK_V1;
}

int32_t validate_utf8_view(moui_embedding_utf8_view_v1 view) {
  const moui_embedding_bytes_view_v1 bytes = {view.data, view.length};
  const int32_t status = validate_bytes_view(bytes);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  if (view.length != 0 && !is_valid_utf8(view.data, view.length)) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_UTF8_V1;
  }
  return MOUI_EMBEDDING_API_STATUS_OK_V1;
}

int32_t make_moonbit_string(
    moui_embedding_utf8_view_v1 view,
    moonbit_string_t *result) {
  if (result == nullptr) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  *result = nullptr;

  const int32_t validation = validate_utf8_view(view);
  if (validation != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return validation;
  }

  const int32_t byte_length = static_cast<int32_t>(view.length);
  moonbit_bytes_t raw_bytes = moonbit_make_bytes_raw(byte_length);
  if (raw_bytes == nullptr) {
    return MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1;
  }
  OwnedMoonbitRef bytes(raw_bytes);
  if (byte_length != 0) {
    std::memcpy(raw_bytes, view.data, view.length);
  }

  const int32_t utf16_length =
      moonbit_utf16_len_from_utf8(raw_bytes, 0, byte_length);
  if (utf16_length < 0) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_UTF8_V1;
  }

  moonbit_string_t raw_string = moonbit_make_string_raw(utf16_length);
  if (raw_string == nullptr) {
    return MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1;
  }
  OwnedMoonbitRef string(raw_string);
  const int32_t decoded = moonbit_utf8_decode_into_utf16(
      raw_bytes, 0, byte_length, raw_string, 0);
  if (decoded < 0 || decoded != utf16_length) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_UTF8_V1;
  }

  *result = static_cast<moonbit_string_t>(string.release());
  return MOUI_EMBEDDING_API_STATUS_OK_V1;
}

int32_t make_moonbit_bytes(
    moui_embedding_bytes_view_v1 view,
    moonbit_bytes_t *result) {
  if (result == nullptr) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  *result = nullptr;

  const int32_t validation = validate_bytes_view(view);
  if (validation != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return validation;
  }

  moonbit_bytes_t raw =
      moonbit_make_bytes_raw(static_cast<int32_t>(view.length));
  if (raw == nullptr) {
    return MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1;
  }
  if (view.length != 0) {
    std::memcpy(raw, view.data, view.length);
  }
  *result = raw;
  return MOUI_EMBEDDING_API_STATUS_OK_V1;
}

moui_embedding_utf8_buffer_v1 failed_buffer(int32_t status) {
  const moui_embedding_utf8_buffer_v1 result = {
      status, nullptr, 0, nullptr, nullptr};
  return result;
}

void release_utf8_buffer(void *context, uint8_t *data, size_t length) {
  (void)data;
  (void)length;
  std::free(context);
}

moui_embedding_utf8_buffer_v1 make_owned_utf8_buffer(
    moonbit_string_t raw_value) {
  OwnedMoonbitRef value(raw_value);
  int32_t utf16_length = 0;
  if (raw_value != nullptr) {
    utf16_length = Moonbit_array_length(raw_value);
    if (utf16_length < 0) {
      return failed_buffer(MOUI_EMBEDDING_API_ERROR_INTERNAL_V1);
    }
  }

  int32_t utf8_length = 0;
  OwnedMoonbitRef encoded;
  if (raw_value != nullptr) {
    utf8_length =
        moonbit_utf8_len_from_utf16(raw_value, 0, utf16_length);
    if (utf8_length < 0) {
      return failed_buffer(MOUI_EMBEDDING_API_ERROR_INPUT_TOO_LARGE_V1);
    }
    moonbit_bytes_t raw_encoded = moonbit_make_bytes_raw(utf8_length);
    if (raw_encoded == nullptr) {
      return failed_buffer(MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1);
    }
    encoded = OwnedMoonbitRef(raw_encoded);
    const int32_t written = moonbit_utf8_encode_from_utf16(
        raw_value, 0, utf16_length, raw_encoded, 0);
    if (written < 0 || written != utf8_length) {
      return failed_buffer(MOUI_EMBEDDING_API_ERROR_INVALID_UTF16_V1);
    }
  }

  uint8_t *copy = static_cast<uint8_t *>(
      std::malloc(static_cast<size_t>(utf8_length) + 1));
  if (copy == nullptr) {
    return failed_buffer(MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1);
  }
  if (utf8_length != 0) {
    std::memcpy(copy, encoded.get(), static_cast<size_t>(utf8_length));
  }
  copy[utf8_length] = UINT8_C(0);

  const moui_embedding_utf8_buffer_v1 result = {
      MOUI_EMBEDDING_API_STATUS_OK_V1,
      copy,
      static_cast<size_t>(utf8_length),
      copy,
      release_utf8_buffer};
  return result;
}

int32_t application_session_status() {
  switch (g_application_state.load(std::memory_order_acquire)) {
    case ApplicationState::kActive:
      return MOUI_EMBEDDING_API_STATUS_OK_V1;
    case ApplicationState::kDestroying:
    case ApplicationState::kDestroyed:
      return MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1;
    case ApplicationState::kUninitialized:
      return MOUI_EMBEDDING_API_ERROR_NOT_INITIALIZED_V1;
  }
  return MOUI_EMBEDDING_API_ERROR_INTERNAL_V1;
}

int32_t initialize_impl(moui_embedding_utf8_view_v1 app_argument) {
  const int32_t current_status = application_session_status();
  if (current_status == MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return MOUI_EMBEDDING_API_RESULT_TRUE_V1;
  }
  if (current_status == MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1) {
    return current_status;
  }

  const int32_t validation = validate_utf8_view(app_argument);
  if (validation != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return validation;
  }
  if (app_argument.length != 0 &&
      std::memchr(app_argument.data, 0, app_argument.length) != nullptr) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }

  try {
    std::call_once(g_initialize_once, [app_argument]() {
      char *retained = static_cast<char *>(
          std::malloc(app_argument.length + 1));
      if (retained == nullptr) {
        g_initialize_result.store(
            MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1,
            std::memory_order_release);
        return;
      }
      if (app_argument.length != 0) {
        std::memcpy(retained, app_argument.data, app_argument.length);
      }
      retained[app_argument.length] = '\0';
      g_process_app_argument = retained;
      g_process_argv[0] = g_process_app_argument;

      MOUI_EMBEDDING_API_INIT(1, g_process_argv);
      MOUI_EMBEDDING_API_APP_INIT();
#ifdef MOUI_EMBEDDING_API_APP_MAIN
      if (MOUI_EMBEDDING_API_APP_MAIN(1, g_process_argv) != 0) {
        g_initialize_result.store(
            MOUI_EMBEDDING_API_ERROR_INITIALIZATION_FAILED_V1,
            std::memory_order_release);
        return;
      }
#endif
      g_application_state.store(
          ApplicationState::kActive,
          std::memory_order_release);
      g_initialize_result.store(
          MOUI_EMBEDDING_API_RESULT_TRUE_V1,
          std::memory_order_release);
    });
  } catch (...) {
    return MOUI_EMBEDDING_API_ERROR_INITIALIZATION_FAILED_V1;
  }
  const int32_t result = g_initialize_result.load(std::memory_order_acquire);
  if (result == MOUI_EMBEDDING_API_RESULT_TRUE_V1 &&
      application_session_status() != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1;
  }
  return result;
}

int32_t destroy_application_impl() {
  ApplicationState expected = ApplicationState::kActive;
  if (!g_application_state.compare_exchange_strong(
          expected,
          ApplicationState::kDestroying,
          std::memory_order_acq_rel,
          std::memory_order_acquire)) {
    if (expected == ApplicationState::kUninitialized) {
      return MOUI_EMBEDDING_API_ERROR_NOT_INITIALIZED_V1;
    }
    return MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1;
  }

  MOUI_EMBEDDING_API_DESTROY_APPLICATION();
  g_application_state.store(
      ApplicationState::kDestroyed,
      std::memory_order_release);
  return MOUI_EMBEDDING_API_RESULT_TRUE_V1;
}

int32_t detach_surface_impl() {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  MOUI_EMBEDDING_API_DETACH_SURFACE();
  return MOUI_EMBEDDING_API_RESULT_TRUE_V1;
}

int32_t attach_surface_impl(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor) {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  if (surface_handle == 0 || width <= 0 || height <= 0 ||
      !std::isfinite(scale_factor) || scale_factor <= 0.0) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  return MOUI_EMBEDDING_API_ATTACH_SURFACE(
      surface_handle, width, height, scale_factor);
}

int32_t resize_impl(int32_t width, int32_t height, double scale_factor) {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  if (width <= 0 || height <= 0 || !std::isfinite(scale_factor) ||
      scale_factor <= 0.0) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  return MOUI_EMBEDDING_API_RESIZE(width, height, scale_factor);
}

int32_t dispatch_pointer_impl(
    int32_t phase,
    double x,
    double y,
    double time_ms) {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(time_ms)) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  return MOUI_EMBEDDING_API_DISPATCH_POINTER(phase, x, y, time_ms);
}

#if MOUI_EMBEDDING_API_ENABLE_SCROLL
int32_t dispatch_scroll_impl(
    double x,
    double y,
    double delta_x,
    double delta_y,
    int32_t phase) {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(delta_x) ||
      !std::isfinite(delta_y)) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  return MOUI_EMBEDDING_API_DISPATCH_SCROLL(
      x, y, delta_x, delta_y, phase);
}
#endif

int32_t frame_tick_impl(double time_ms) {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  if (!std::isfinite(time_ms)) {
    return MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1;
  }
  return MOUI_EMBEDDING_API_FRAME_TICK(time_ms);
}

int32_t render_frame_impl() {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  return MOUI_EMBEDDING_API_RENDER_FRAME();
}

int32_t configure_renderer_impl(moui_embedding_utf8_view_v1 mode) {
  const int32_t session_status = application_session_status();
  if (session_status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return session_status;
  }
  moonbit_string_t raw_mode = nullptr;
  const int32_t status = make_moonbit_string(mode, &raw_mode);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  OwnedMoonbitRef owned_mode(raw_mode);
  return MOUI_EMBEDDING_API_RENDERER_CONFIGURE(raw_mode);
}

moui_embedding_utf8_buffer_v1 renderer_status_json_impl() {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return failed_buffer(status);
  }
  return make_owned_utf8_buffer(MOUI_EMBEDDING_API_RENDERER_STATUS_JSON());
}

moui_embedding_utf8_buffer_v1 take_host_update_envelope_json_impl() {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return failed_buffer(status);
  }
  return make_owned_utf8_buffer(
      MOUI_EMBEDDING_API_TAKE_HOST_UPDATE_ENVELOPE_JSON());
}

int32_t dispatch_host_response_envelope_impl(
    moui_embedding_utf8_view_v1 envelope_json) {
  const int32_t session_status = application_session_status();
  if (session_status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return session_status;
  }
  moonbit_string_t raw_envelope = nullptr;
  const int32_t status = make_moonbit_string(envelope_json, &raw_envelope);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  OwnedMoonbitRef owned_envelope(raw_envelope);
  return MOUI_EMBEDDING_API_DISPATCH_HOST_RESPONSE_ENVELOPE(raw_envelope);
}

int32_t dispatch_text_input_impl(
    int32_t kind,
    moui_embedding_utf8_view_v1 text,
    int32_t start,
    int32_t end) {
  const int32_t session_status = application_session_status();
  if (session_status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return session_status;
  }
  moonbit_string_t raw_text = nullptr;
  const int32_t status = make_moonbit_string(text, &raw_text);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  OwnedMoonbitRef owned_text(raw_text);
  return MOUI_EMBEDDING_API_DISPATCH_TEXT_INPUT(
      kind, raw_text, start, end);
}

int32_t dispatch_command_impl(int32_t kind) {
  const int32_t status = application_session_status();
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  return MOUI_EMBEDDING_API_DISPATCH_COMMAND(kind);
}

int32_t dispatch_accessibility_impl(
    int32_t element_id,
    int32_t action,
    moui_embedding_utf8_view_v1 value) {
  const int32_t session_status = application_session_status();
  if (session_status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return session_status;
  }
  moonbit_string_t raw_value = nullptr;
  const int32_t status = make_moonbit_string(value, &raw_value);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  OwnedMoonbitRef owned_value(raw_value);
  return MOUI_EMBEDDING_API_DISPATCH_ACCESSIBILITY(
      element_id, action, raw_value);
}

int32_t complete_clipboard_impl(
    int32_t session_generation,
    int32_t id,
    int32_t kind,
    moui_embedding_utf8_view_v1 text,
    moui_embedding_bytes_view_v1 bytes) {
  const int32_t session_status = application_session_status();
  if (session_status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return session_status;
  }
  const int32_t text_validation = validate_utf8_view(text);
  if (text_validation != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return text_validation;
  }
  const int32_t bytes_validation = validate_bytes_view(bytes);
  if (bytes_validation != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return bytes_validation;
  }

  moonbit_string_t raw_text = nullptr;
  int32_t status = make_moonbit_string(text, &raw_text);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  OwnedMoonbitRef owned_text(raw_text);

  moonbit_bytes_t raw_bytes = nullptr;
  status = make_moonbit_bytes(bytes, &raw_bytes);
  if (status != MOUI_EMBEDDING_API_STATUS_OK_V1) {
    return status;
  }
  OwnedMoonbitRef owned_bytes(raw_bytes);
  return MOUI_EMBEDDING_API_COMPLETE_CLIPBOARD(
      session_generation, id, kind, raw_text, raw_bytes);
}

constexpr uint64_t kCapabilities =
    MOUI_EMBEDDING_API_REQUIRED_CAPABILITIES_V1
#if MOUI_EMBEDDING_API_ENABLE_SCROLL
    | MOUI_EMBEDDING_API_CAPABILITY_SCROLL_V1
#endif
    ;

static_assert(
    sizeof(moui_embedding_api_v1) <=
        static_cast<size_t>(std::numeric_limits<uint32_t>::max()),
    "runtime API table size must fit its uint32_t struct_size field");

const moui_embedding_api_v1 kRuntimeApi = {
    MOUI_EMBEDDING_API_ABI_VERSION_V1,
    static_cast<uint32_t>(sizeof(moui_embedding_api_v1)),
    kCapabilities,
    initialize_impl,
    destroy_application_impl,
    detach_surface_impl,
    attach_surface_impl,
    resize_impl,
    dispatch_pointer_impl,
#if MOUI_EMBEDDING_API_ENABLE_SCROLL
    dispatch_scroll_impl,
#else
    nullptr,
#endif
    frame_tick_impl,
    render_frame_impl,
    configure_renderer_impl,
    renderer_status_json_impl,
    take_host_update_envelope_json_impl,
    dispatch_host_response_envelope_impl,
    dispatch_text_input_impl,
    dispatch_command_impl,
    dispatch_accessibility_impl,
    complete_clipboard_impl};

}  // namespace

extern "C" MOUI_EMBEDDING_API const moui_embedding_api_v1 *
moui_embedding_get_api_v1(void) {
  return &kRuntimeApi;
}
