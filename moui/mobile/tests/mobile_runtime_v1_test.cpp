#include "moui_mobile_runtime_v1.h"

// Include libc string headers before moonbit.h so memcpy keeps the system
// exception specifier; moonbit.h may redeclare memcpy without noexcept.
#include <cstring>
#include <string.h>
#include <moonbit.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <iterator>
#include <limits>
#include <string>
#include <thread>
#include <vector>

#ifndef MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
#define MOUI_MOBILE_RUNTIME_ENABLE_SCROLL 0
#endif

namespace {

struct TrackedRef {
  void *pointer;
  int decref_count;
};

std::array<TrackedRef, 32> g_tracked_refs{};

std::atomic<int> g_runtime_init_calls{0};
std::atomic<int> g_app_init_calls{0};
int g_runtime_argc = 0;
const char *g_runtime_argv0 = nullptr;

int g_attach_calls = 0;
uint64_t g_surface_handle = 0;
int32_t g_surface_width = 0;
int32_t g_surface_height = 0;
double g_surface_scale = 0.0;
int g_resize_calls = 0;
int g_pointer_calls = 0;
int g_scroll_calls = 0;
int g_frame_tick_calls = 0;
int g_render_calls = 0;
int g_detach_calls = 0;
int g_destroy_calls = 0;
int g_mock_application_state = 0;

int g_renderer_configure_calls = 0;
moonbit_string_t g_retained_renderer_mode = nullptr;
int g_renderer_status_mode = 0;
int g_renderer_status_calls = 0;
int g_host_updates_calls = 0;
int g_host_response_calls = 0;
moonbit_string_t g_retained_host_response = nullptr;
void *g_last_returned_string = nullptr;

int g_text_input_calls = 0;
int32_t g_text_kind = 0;
int32_t g_text_start = 0;
int32_t g_text_end = 0;
moonbit_string_t g_retained_text = nullptr;

int g_command_calls = 0;
int32_t g_command_kind = 0;

int g_accessibility_calls = 0;
int32_t g_accessibility_element = 0;
int32_t g_accessibility_action = 0;
moonbit_string_t g_retained_accessibility_value = nullptr;

int g_clipboard_calls = 0;
int32_t g_clipboard_id = 0;
int32_t g_clipboard_kind = 0;
moonbit_string_t g_retained_clipboard_text = nullptr;
moonbit_bytes_t g_retained_clipboard_bytes = nullptr;

[[noreturn]] void fail(const char *expression, int line) {
  std::fprintf(
      stderr,
      "mobile_runtime_v1_test.cpp:%d: check failed: %s\n",
      line,
      expression);
  std::exit(1);
}

#define CHECK(expression)                         \
  do {                                            \
    if (!(expression)) {                          \
      fail(#expression, __LINE__);                \
    }                                             \
  } while (false)

void track_ref(void *pointer) {
  CHECK(pointer != nullptr);
  for (TrackedRef &entry : g_tracked_refs) {
    if (entry.pointer == pointer) {
      return;
    }
  }
  for (TrackedRef &entry : g_tracked_refs) {
    if (entry.pointer == nullptr) {
      entry.pointer = pointer;
      entry.decref_count = 0;
      return;
    }
  }
  fail("tracked reference capacity", __LINE__);
}

int consume_decref_count(void *pointer) {
  for (TrackedRef &entry : g_tracked_refs) {
    if (entry.pointer == pointer) {
      const int result = entry.decref_count;
      entry.pointer = nullptr;
      entry.decref_count = 0;
      return result;
    }
  }
  fail("reference was tracked", __LINE__);
}

moonbit_string_t make_moonbit_string(
    const uint16_t *units,
    size_t length) {
  CHECK(length <=
        static_cast<size_t>(std::numeric_limits<int32_t>::max()));
  moonbit_string_t result =
      moonbit_make_string_raw(static_cast<int32_t>(length));
  CHECK(result != nullptr);
  if (length != 0) {
    std::memcpy(result, units, length * sizeof(uint16_t));
  }
  return result;
}

void check_moonbit_string(
    moonbit_string_t value,
    const uint16_t *expected,
    size_t expected_length) {
  CHECK(value != nullptr);
  CHECK(Moonbit_array_length(value) ==
        static_cast<int32_t>(expected_length));
  CHECK(expected_length == 0 ||
        std::memcmp(
            value,
            expected,
            expected_length * sizeof(uint16_t)) == 0);
}

void check_moonbit_bytes(
    moonbit_bytes_t value,
    const uint8_t *expected,
    size_t expected_length) {
  CHECK(value != nullptr);
  CHECK(Moonbit_array_length(value) ==
        static_cast<int32_t>(expected_length));
  CHECK(expected_length == 0 ||
        std::memcmp(value, expected, expected_length) == 0);
}

void check_moonbit_ascii(
    moonbit_string_t value,
    const uint8_t *expected,
    size_t expected_length) {
  CHECK(value != nullptr);
  CHECK(Moonbit_array_length(value) ==
        static_cast<int32_t>(expected_length));
  for (size_t index = 0; index < expected_length; ++index) {
    CHECK(value[index] == expected[index]);
  }
}

void release_buffer(moui_mobile_utf8_buffer_v1 *buffer) {
  CHECK(buffer->status == MOUI_MOBILE_RUNTIME_STATUS_OK_V1);
  CHECK(buffer->data != nullptr);
  CHECK(buffer->release_context != nullptr);
  CHECK(buffer->release != nullptr);
  buffer->release(
      buffer->release_context,
      buffer->data,
      buffer->length);
  buffer->data = nullptr;
  buffer->length = 0;
  buffer->release_context = nullptr;
  buffer->release = nullptr;
}

constexpr uint8_t kUtf8Payload[] = {
    UINT8_C(0x41),
    UINT8_C(0xE4), UINT8_C(0xB8), UINT8_C(0xAD),
    UINT8_C(0xF0), UINT8_C(0x9F), UINT8_C(0x98), UINT8_C(0x80),
    UINT8_C(0x00),
    UINT8_C(0x5A)};
constexpr uint16_t kUtf16Payload[] = {
    UINT16_C(0x0041),
    UINT16_C(0x4E2D),
    UINT16_C(0xD83D), UINT16_C(0xDE00),
    UINT16_C(0x0000),
    UINT16_C(0x005A)};

}  // namespace

extern "C" void test_moonbit_decref(void *value) {
  for (TrackedRef &entry : g_tracked_refs) {
    if (entry.pointer == value) {
      entry.decref_count += 1;
      break;
    }
  }
  moonbit_decref(value);
}

extern "C" void mock_runtime_init(int argc, char **argv) {
  g_runtime_init_calls.fetch_add(1, std::memory_order_relaxed);
  g_runtime_argc = argc;
  g_runtime_argv0 = argc > 0 && argv != nullptr ? argv[0] : nullptr;
}

extern "C" void mock_app_init(void) {
  g_app_init_calls.fetch_add(1, std::memory_order_relaxed);
  g_mock_application_state = 73;
}

extern "C" int32_t mock_attach_surface(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor) {
  CHECK(g_mock_application_state == 73);
  g_attach_calls += 1;
  g_surface_handle = surface_handle;
  g_surface_width = width;
  g_surface_height = height;
  g_surface_scale = scale_factor;
  return 1;
}

extern "C" int32_t mock_resize(
    int32_t width,
    int32_t height,
    double scale_factor) {
  g_resize_calls += 1;
  g_surface_width = width;
  g_surface_height = height;
  g_surface_scale = scale_factor;
  return 0;
}

extern "C" int32_t mock_dispatch_pointer(
    int32_t phase,
    double x,
    double y,
    double time_ms) {
  g_pointer_calls += 1;
  CHECK(phase == 2);
  CHECK(x == 10.25);
  CHECK(y == 20.5);
  CHECK(time_ms == 30.75);
  return 1;
}

#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
extern "C" int32_t mock_dispatch_scroll(
    double x,
    double y,
    double delta_x,
    double delta_y,
    int32_t phase) {
  g_scroll_calls += 1;
  CHECK(x == 1.0);
  CHECK(y == 2.0);
  CHECK(delta_x == 3.0);
  CHECK(delta_y == 4.0);
  CHECK(phase == 5);
  return 1;
}
#endif

extern "C" int32_t mock_frame_tick(double time_ms) {
  g_frame_tick_calls += 1;
  CHECK(time_ms == 123.5);
  return 0;
}

extern "C" int32_t mock_render_frame(void) {
  g_render_calls += 1;
  return 1;
}

extern "C" void mock_detach_surface(void) {
  CHECK(g_mock_application_state == 73);
  g_detach_calls += 1;
}

extern "C" void mock_destroy_application(void) {
  CHECK(g_mock_application_state == 73);
  g_destroy_calls += 1;
  g_mock_application_state = -1;
}

extern "C" int32_t mock_renderer_configure(moonbit_string_t mode) {
  g_renderer_configure_calls += 1;
  moonbit_incref(mode);
  g_retained_renderer_mode = mode;
  track_ref(mode);
  return 1;
}

extern "C" moonbit_string_t mock_renderer_status_json(void) {
  g_renderer_status_calls += 1;
  moonbit_string_t result = nullptr;
  if (g_renderer_status_mode == 1) {
    constexpr uint16_t invalid[] = {UINT16_C(0xD800)};
    result = make_moonbit_string(invalid, std::size(invalid));
  } else if (g_renderer_status_mode == 2) {
    return nullptr;
  } else {
    result = make_moonbit_string(kUtf16Payload, std::size(kUtf16Payload));
  }
  g_last_returned_string = result;
  track_ref(result);
  return result;
}

extern "C" moonbit_string_t mock_take_host_updates_json(void) {
  g_host_updates_calls += 1;
  moonbit_string_t result = moonbit_make_string_raw(0);
  CHECK(result != nullptr);
  g_last_returned_string = result;
  track_ref(result);
  return result;
}

extern "C" int32_t mock_dispatch_host_response_envelope(
    moonbit_string_t envelope_json) {
  g_host_response_calls += 1;
  moonbit_incref(envelope_json);
  g_retained_host_response = envelope_json;
  track_ref(envelope_json);
  return 1;
}

extern "C" int32_t mock_dispatch_text_input(
    int32_t kind,
    moonbit_string_t text,
    int32_t start,
    int32_t end) {
  g_text_input_calls += 1;
  g_text_kind = kind;
  g_text_start = start;
  g_text_end = end;
  moonbit_incref(text);
  g_retained_text = text;
  track_ref(text);
  return 1;
}

extern "C" int32_t mock_dispatch_command(int32_t kind) {
  g_command_calls += 1;
  g_command_kind = kind;
  return 0;
}

extern "C" int32_t mock_dispatch_accessibility(
    int32_t element_id,
    int32_t action,
    moonbit_string_t value) {
  g_accessibility_calls += 1;
  g_accessibility_element = element_id;
  g_accessibility_action = action;
  moonbit_incref(value);
  g_retained_accessibility_value = value;
  track_ref(value);
  return 1;
}

extern "C" int32_t mock_complete_clipboard(
    int32_t session_generation,
    int32_t id,
    int32_t kind,
    moonbit_string_t text,
    moonbit_bytes_t bytes) {
  CHECK(session_generation == 7);
  g_clipboard_calls += 1;
  g_clipboard_id = id;
  g_clipboard_kind = kind;
  moonbit_incref(text);
  moonbit_incref(bytes);
  g_retained_clipboard_text = text;
  g_retained_clipboard_bytes = bytes;
  track_ref(text);
  track_ref(bytes);
  return 1;
}

namespace {

void test_consumer_negotiation(const moui_mobile_runtime_api_v1 *api) {
  CHECK(moui_mobile_runtime_api_v1_is_compatible(api) != 0);
  CHECK(api->struct_size == MOUI_MOBILE_RUNTIME_API_V1_REQUIRED_SIZE);

  moui_mobile_runtime_api_v1 candidate = *api;
  candidate.abi_version = MOUI_MOBILE_RUNTIME_ABI_VERSION_V1 + 1;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);

  candidate = *api;
  candidate.struct_size = MOUI_MOBILE_RUNTIME_API_V1_REQUIRED_SIZE - 1;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);

  candidate = *api;
  candidate.struct_size = MOUI_MOBILE_RUNTIME_API_V1_REQUIRED_SIZE + 64;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) != 0);

  candidate = *api;
  candidate.capabilities &=
      ~MOUI_MOBILE_RUNTIME_CAPABILITY_APPLICATION_DESTROY_V1;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);

  candidate = *api;
  candidate.destroy_application = nullptr;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);

  candidate = *api;
  candidate.capabilities &=
      ~MOUI_MOBILE_RUNTIME_CAPABILITY_HOST_RESPONSE_ENVELOPE_V1;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);

  candidate = *api;
  candidate.dispatch_host_response_envelope = nullptr;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);

  candidate = *api;
#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
  candidate.capabilities &= ~MOUI_MOBILE_RUNTIME_CAPABILITY_SCROLL_V1;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);
  candidate.dispatch_scroll = nullptr;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) != 0);
#else
  candidate.capabilities |= MOUI_MOBILE_RUNTIME_CAPABILITY_SCROLL_V1;
  CHECK(moui_mobile_runtime_api_v1_is_compatible(&candidate) == 0);
#endif
}

void test_table_and_initialization(const moui_mobile_runtime_api_v1 *api) {
  CHECK(api != nullptr);
  CHECK(api == moui_mobile_get_runtime_api_v1());
  CHECK(api->abi_version == MOUI_MOBILE_RUNTIME_ABI_VERSION_V1);
  CHECK(api->struct_size == sizeof(moui_mobile_runtime_api_v1));

  uint64_t expected_capabilities =
      MOUI_MOBILE_RUNTIME_REQUIRED_CAPABILITIES_V1;
#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
  expected_capabilities |= MOUI_MOBILE_RUNTIME_CAPABILITY_SCROLL_V1;
#endif
  CHECK(api->capabilities == expected_capabilities);

  CHECK(api->initialize != nullptr);
  CHECK(api->destroy_application != nullptr);
  CHECK(api->detach_surface != nullptr);
  CHECK(api->attach_surface != nullptr);
  CHECK(api->resize != nullptr);
  CHECK(api->dispatch_pointer != nullptr);
#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
  CHECK(api->dispatch_scroll != nullptr);
#else
  CHECK(api->dispatch_scroll == nullptr);
#endif
  CHECK(api->frame_tick != nullptr);
  CHECK(api->render_frame != nullptr);
  CHECK(api->configure_renderer != nullptr);
  CHECK(api->renderer_status_json != nullptr);
  CHECK(api->take_host_update_envelope_json != nullptr);
  CHECK(api->dispatch_host_response_envelope != nullptr);
  CHECK(api->dispatch_text_input != nullptr);
  CHECK(api->dispatch_command != nullptr);
  CHECK(api->dispatch_accessibility != nullptr);
  CHECK(api->complete_clipboard != nullptr);

  const moui_mobile_utf8_view_v1 empty_text = {nullptr, 0};
  const moui_mobile_bytes_view_v1 empty_bytes = {nullptr, 0};
  CHECK(api->destroy_application() ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->detach_surface() ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->attach_surface(1, 1, 1, 1.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->resize(1, 1, 1.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->dispatch_pointer(0, 0.0, 0.0, 0.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
  CHECK(api->dispatch_scroll(0.0, 0.0, 0.0, 0.0, 0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
#endif
  CHECK(api->frame_tick(0.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->render_frame() ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->configure_renderer(empty_text) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  const moui_mobile_utf8_buffer_v1 preinit = api->renderer_status_json();
  CHECK(preinit.status == MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(preinit.data == nullptr);
  CHECK(preinit.length == 0);
  CHECK(preinit.release_context == nullptr);
  CHECK(preinit.release == nullptr);
  const moui_mobile_utf8_buffer_v1 preinit_updates =
      api->take_host_update_envelope_json();
  CHECK(preinit_updates.status ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(preinit_updates.data == nullptr);
  CHECK(preinit_updates.release == nullptr);
  CHECK(api->dispatch_host_response_envelope(empty_text) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->dispatch_text_input(0, empty_text, 0, 0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->dispatch_command(0) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->dispatch_accessibility(0, 0, empty_text) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(api->complete_clipboard(7, 0, 0, empty_text, empty_bytes) ==
        MOUI_MOBILE_RUNTIME_ERROR_NOT_INITIALIZED_V1);
  CHECK(g_detach_calls == 0);
  CHECK(g_destroy_calls == 0);
  CHECK(g_attach_calls == 0);
  CHECK(g_resize_calls == 0);
  CHECK(g_pointer_calls == 0);
  CHECK(g_scroll_calls == 0);
  CHECK(g_frame_tick_calls == 0);
  CHECK(g_render_calls == 0);
  CHECK(g_renderer_configure_calls == 0);
  CHECK(g_host_response_calls == 0);
  CHECK(g_text_input_calls == 0);
  CHECK(g_command_calls == 0);
  CHECK(g_accessibility_calls == 0);
  CHECK(g_clipboard_calls == 0);

  const uint8_t invalid_utf8[] = {UINT8_C(0xC0), UINT8_C(0xAF)};
  CHECK(api->initialize({invalid_utf8, std::size(invalid_utf8)}) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_UTF8_V1);
  const uint8_t embedded_nul[] = {'a', 0, 'b'};
  CHECK(api->initialize({embedded_nul, std::size(embedded_nul)}) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_ARGUMENT_V1);
  CHECK(g_runtime_init_calls.load(std::memory_order_relaxed) == 0);
  CHECK(g_app_init_calls.load(std::memory_order_relaxed) == 0);

  std::string app_argument = "external-consumer";
  const std::string expected_argument = app_argument;
  const moui_mobile_utf8_view_v1 app_view = {
      reinterpret_cast<const uint8_t *>(app_argument.data()),
      app_argument.size()};
  std::array<int32_t, 16> results{};
  std::vector<std::thread> threads;
  threads.reserve(results.size());
  for (size_t index = 0; index < results.size(); ++index) {
    threads.emplace_back([api, app_view, &results, index]() {
      results[index] = api->initialize(app_view);
    });
  }
  for (std::thread &thread : threads) {
    thread.join();
  }
  for (int32_t result : results) {
    CHECK(result == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1);
  }
  CHECK(g_runtime_init_calls.load(std::memory_order_relaxed) == 1);
  CHECK(g_app_init_calls.load(std::memory_order_relaxed) == 1);
  CHECK(g_mock_application_state == 73);
  CHECK(g_runtime_argc == 1);
  CHECK(g_runtime_argv0 != nullptr);
  CHECK(std::strcmp(g_runtime_argv0, expected_argument.c_str()) == 0);

  std::fill(app_argument.begin(), app_argument.end(), 'x');
  CHECK(std::strcmp(g_runtime_argv0, expected_argument.c_str()) == 0);
  const uint8_t ignored_argument[] = {'o', 't', 'h', 'e', 'r'};
  CHECK(api->initialize({ignored_argument, std::size(ignored_argument)}) ==
        MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1);
  CHECK(g_runtime_init_calls.load(std::memory_order_relaxed) == 1);
  CHECK(g_app_init_calls.load(std::memory_order_relaxed) == 1);
  CHECK(std::strcmp(g_runtime_argv0, expected_argument.c_str()) == 0);
}

void test_lifecycle_surface_input_and_frame(
    const moui_mobile_runtime_api_v1 *api) {
  CHECK(api->attach_surface(0, 100, 200, 2.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_ARGUMENT_V1);
  CHECK(api->attach_surface(42, 100, 200, 2.0) == 1);
  CHECK(g_attach_calls == 1);
  CHECK(g_surface_handle == 42);
  CHECK(g_surface_width == 100);
  CHECK(g_surface_height == 200);
  CHECK(g_surface_scale == 2.0);

  CHECK(api->resize(300, 400, 3.0) == 0);
  CHECK(g_resize_calls == 1);
  CHECK(g_surface_width == 300);
  CHECK(g_surface_height == 400);
  CHECK(g_surface_scale == 3.0);
  CHECK(api->resize(0, 400, 3.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_ARGUMENT_V1);

  CHECK(api->dispatch_pointer(2, 10.25, 20.5, 30.75) == 1);
  CHECK(g_pointer_calls == 1);
  CHECK(api->dispatch_pointer(
            2,
            std::numeric_limits<double>::quiet_NaN(),
            20.5,
            30.75) == MOUI_MOBILE_RUNTIME_ERROR_INVALID_ARGUMENT_V1);

#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
  CHECK(api->dispatch_scroll(1.0, 2.0, 3.0, 4.0, 5) == 1);
  CHECK(g_scroll_calls == 1);
#else
  CHECK(g_scroll_calls == 0);
#endif

  CHECK(api->frame_tick(123.5) == 0);
  CHECK(g_frame_tick_calls == 1);
  CHECK(api->render_frame() == 1);
  CHECK(g_render_calls == 1);

  const int retained_application_state = g_mock_application_state;
  CHECK(api->detach_surface() == MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1);
  CHECK(g_detach_calls == 1);
  CHECK(g_mock_application_state == retained_application_state);
  CHECK(api->attach_surface(43, 640, 480, 2.0) == 1);
  CHECK(g_attach_calls == 2);
  CHECK(g_surface_handle == 43);
  CHECK(g_mock_application_state == retained_application_state);
}

void test_utf8_and_ownership(const moui_mobile_runtime_api_v1 *api) {
  const moui_mobile_utf8_view_v1 payload = {
      kUtf8Payload, std::size(kUtf8Payload)};

  CHECK(api->configure_renderer(payload) == 1);
  CHECK(g_renderer_configure_calls == 1);
  check_moonbit_string(
      g_retained_renderer_mode,
      kUtf16Payload,
      std::size(kUtf16Payload));
  CHECK(consume_decref_count(g_retained_renderer_mode) == 1);
  moonbit_decref(g_retained_renderer_mode);
  g_retained_renderer_mode = nullptr;

  const uint8_t invalid_utf8[] = {UINT8_C(0xED), UINT8_C(0xA0), UINT8_C(0x80)};
  CHECK(api->configure_renderer(
            {invalid_utf8, std::size(invalid_utf8)}) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_UTF8_V1);
  CHECK(g_renderer_configure_calls == 1);

  const uint8_t dummy = 0;
  if (sizeof(size_t) > sizeof(int32_t)) {
    CHECK(api->configure_renderer(
              {&dummy,
               static_cast<size_t>(std::numeric_limits<int32_t>::max()) + 1}) ==
          MOUI_MOBILE_RUNTIME_ERROR_INPUT_TOO_LARGE_V1);
  }

  moui_mobile_utf8_buffer_v1 status = api->renderer_status_json();
  CHECK(status.status == MOUI_MOBILE_RUNTIME_STATUS_OK_V1);
  CHECK(status.length == std::size(kUtf8Payload));
  CHECK(std::memcmp(status.data, kUtf8Payload, status.length) == 0);
  CHECK(status.data[status.length] == 0);
  CHECK(status.release_context == status.data);
  CHECK(consume_decref_count(g_last_returned_string) == 1);
  release_buffer(&status);

  moui_mobile_utf8_buffer_v1 updates =
      api->take_host_update_envelope_json();
  CHECK(updates.status == MOUI_MOBILE_RUNTIME_STATUS_OK_V1);
  CHECK(updates.length == 0);
  CHECK(updates.data[0] == 0);
  CHECK(consume_decref_count(g_last_returned_string) == 1);
  release_buffer(&updates);

  g_renderer_status_mode = 1;
  status = api->renderer_status_json();
  CHECK(status.status == MOUI_MOBILE_RUNTIME_ERROR_INVALID_UTF16_V1);
  CHECK(status.data == nullptr);
  CHECK(status.release_context == nullptr);
  CHECK(status.release == nullptr);
  CHECK(consume_decref_count(g_last_returned_string) == 1);

  g_renderer_status_mode = 2;
  status = api->renderer_status_json();
  CHECK(status.status == MOUI_MOBILE_RUNTIME_STATUS_OK_V1);
  CHECK(status.length == 0);
  CHECK(status.data[0] == 0);
  release_buffer(&status);
  g_renderer_status_mode = 0;
}

void test_host_services(const moui_mobile_runtime_api_v1 *api) {
  const moui_mobile_utf8_view_v1 payload = {
      kUtf8Payload, std::size(kUtf8Payload)};

  constexpr char host_response_json[] =
      "{\"schemaVersion\":1,\"sessionGeneration\":7,"
      "\"response\":{\"kind\":\"command\",\"command\":0}}";
  const auto *host_response_bytes =
      reinterpret_cast<const uint8_t *>(host_response_json);
  CHECK(api->dispatch_host_response_envelope(
            {host_response_bytes, sizeof(host_response_json) - 1}) == 1);
  CHECK(g_host_response_calls == 1);
  check_moonbit_ascii(
      g_retained_host_response,
      host_response_bytes,
      sizeof(host_response_json) - 1);
  CHECK(consume_decref_count(g_retained_host_response) == 1);
  moonbit_decref(g_retained_host_response);
  g_retained_host_response = nullptr;

  constexpr uint8_t embedded_nul_envelope[] = {
      '{', '}', UINT8_C(0), 'x'};
  CHECK(api->dispatch_host_response_envelope(
            {embedded_nul_envelope, std::size(embedded_nul_envelope)}) == 1);
  CHECK(g_host_response_calls == 2);
  check_moonbit_ascii(
      g_retained_host_response,
      embedded_nul_envelope,
      std::size(embedded_nul_envelope));
  CHECK(consume_decref_count(g_retained_host_response) == 1);
  moonbit_decref(g_retained_host_response);
  g_retained_host_response = nullptr;

  constexpr uint8_t invalid_utf8_envelope[] = {
      UINT8_C(0xF0), UINT8_C(0x28), UINT8_C(0x8C), UINT8_C(0x28)};
  CHECK(api->dispatch_host_response_envelope(
            {invalid_utf8_envelope, std::size(invalid_utf8_envelope)}) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_UTF8_V1);
  CHECK(g_host_response_calls == 2);

  CHECK(api->dispatch_text_input(7, payload, 2, 5) == 1);
  CHECK(g_text_input_calls == 1);
  CHECK(g_text_kind == 7);
  CHECK(g_text_start == 2);
  CHECK(g_text_end == 5);
  check_moonbit_string(
      g_retained_text, kUtf16Payload, std::size(kUtf16Payload));
  CHECK(consume_decref_count(g_retained_text) == 1);
  moonbit_decref(g_retained_text);
  g_retained_text = nullptr;

  CHECK(api->dispatch_command(9) == 0);
  CHECK(g_command_calls == 1);
  CHECK(g_command_kind == 9);

  CHECK(api->dispatch_accessibility(11, 13, payload) == 1);
  CHECK(g_accessibility_calls == 1);
  CHECK(g_accessibility_element == 11);
  CHECK(g_accessibility_action == 13);
  check_moonbit_string(
      g_retained_accessibility_value,
      kUtf16Payload,
      std::size(kUtf16Payload));
  CHECK(consume_decref_count(g_retained_accessibility_value) == 1);
  moonbit_decref(g_retained_accessibility_value);
  g_retained_accessibility_value = nullptr;

  constexpr uint8_t clipboard_bytes[] = {
      UINT8_C(0x00), UINT8_C(0x01), UINT8_C(0x7F), UINT8_C(0xFF)};
  CHECK(api->complete_clipboard(
            7,
            17,
            19,
            payload,
            {clipboard_bytes, std::size(clipboard_bytes)}) == 1);
  CHECK(g_clipboard_calls == 1);
  CHECK(g_clipboard_id == 17);
  CHECK(g_clipboard_kind == 19);
  check_moonbit_string(
      g_retained_clipboard_text,
      kUtf16Payload,
      std::size(kUtf16Payload));
  check_moonbit_bytes(
      g_retained_clipboard_bytes,
      clipboard_bytes,
      std::size(clipboard_bytes));
  CHECK(consume_decref_count(g_retained_clipboard_text) == 1);
  CHECK(consume_decref_count(g_retained_clipboard_bytes) == 1);
  moonbit_decref(g_retained_clipboard_text);
  moonbit_decref(g_retained_clipboard_bytes);
  g_retained_clipboard_text = nullptr;
  g_retained_clipboard_bytes = nullptr;

  CHECK(api->complete_clipboard(7, 1, 2, payload, {nullptr, 1}) ==
        MOUI_MOBILE_RUNTIME_ERROR_INVALID_ARGUMENT_V1);
  CHECK(g_clipboard_calls == 1);
}

void test_destroy_is_terminal(const moui_mobile_runtime_api_v1 *api) {
  const int attach_calls = g_attach_calls;
  const int resize_calls = g_resize_calls;
  const int pointer_calls = g_pointer_calls;
  const int scroll_calls = g_scroll_calls;
  const int frame_tick_calls = g_frame_tick_calls;
  const int render_calls = g_render_calls;
  const int detach_calls = g_detach_calls;
  const int renderer_configure_calls = g_renderer_configure_calls;
  const int renderer_status_calls = g_renderer_status_calls;
  const int host_updates_calls = g_host_updates_calls;
  const int host_response_calls = g_host_response_calls;
  const int text_input_calls = g_text_input_calls;
  const int command_calls = g_command_calls;
  const int accessibility_calls = g_accessibility_calls;
  const int clipboard_calls = g_clipboard_calls;

  std::array<int32_t, 16> destroy_results{};
  std::vector<std::thread> destroy_threads;
  destroy_threads.reserve(destroy_results.size());
  for (size_t index = 0; index < destroy_results.size(); ++index) {
    destroy_threads.emplace_back([api, &destroy_results, index]() {
      destroy_results[index] = api->destroy_application();
    });
  }
  for (std::thread &thread : destroy_threads) {
    thread.join();
  }
  CHECK(std::count(
            destroy_results.begin(),
            destroy_results.end(),
            MOUI_MOBILE_RUNTIME_RESULT_TRUE_V1) == 1);
  CHECK(std::count(
            destroy_results.begin(),
            destroy_results.end(),
            MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1) == 15);
  CHECK(g_destroy_calls == 1);
  CHECK(g_mock_application_state == -1);

  const uint8_t app_argument[] = {'a', 'p', 'p'};
  const moui_mobile_utf8_view_v1 text = {
      app_argument, std::size(app_argument)};
  const moui_mobile_bytes_view_v1 bytes = {nullptr, 0};
  CHECK(api->initialize(text) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->destroy_application() ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->detach_surface() ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->attach_surface(99, 100, 100, 1.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->resize(100, 100, 1.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->dispatch_pointer(0, 0.0, 0.0, 0.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
#if MOUI_MOBILE_RUNTIME_ENABLE_SCROLL
  CHECK(api->dispatch_scroll(0.0, 0.0, 0.0, 0.0, 0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
#endif
  CHECK(api->frame_tick(0.0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->render_frame() ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->configure_renderer(text) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);

  const moui_mobile_utf8_buffer_v1 renderer_status =
      api->renderer_status_json();
  CHECK(renderer_status.status ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(renderer_status.data == nullptr);
  CHECK(renderer_status.release_context == nullptr);
  CHECK(renderer_status.release == nullptr);
  const moui_mobile_utf8_buffer_v1 host_updates =
      api->take_host_update_envelope_json();
  CHECK(host_updates.status ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(host_updates.data == nullptr);
  CHECK(host_updates.release_context == nullptr);
  CHECK(host_updates.release == nullptr);

  CHECK(api->dispatch_host_response_envelope(text) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->dispatch_text_input(0, text, 0, 0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->dispatch_command(0) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->dispatch_accessibility(0, 0, text) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);
  CHECK(api->complete_clipboard(7, 0, 0, text, bytes) ==
        MOUI_MOBILE_RUNTIME_ERROR_APPLICATION_DESTROYED_V1);

  CHECK(g_destroy_calls == 1);
  CHECK(g_attach_calls == attach_calls);
  CHECK(g_resize_calls == resize_calls);
  CHECK(g_pointer_calls == pointer_calls);
  CHECK(g_scroll_calls == scroll_calls);
  CHECK(g_frame_tick_calls == frame_tick_calls);
  CHECK(g_render_calls == render_calls);
  CHECK(g_detach_calls == detach_calls);
  CHECK(g_renderer_configure_calls == renderer_configure_calls);
  CHECK(g_renderer_status_calls == renderer_status_calls);
  CHECK(g_host_updates_calls == host_updates_calls);
  CHECK(g_host_response_calls == host_response_calls);
  CHECK(g_text_input_calls == text_input_calls);
  CHECK(g_command_calls == command_calls);
  CHECK(g_accessibility_calls == accessibility_calls);
  CHECK(g_clipboard_calls == clipboard_calls);
}

}  // namespace

int main() {
  const moui_mobile_runtime_api_v1 *api = moui_mobile_get_runtime_api_v1();
  test_consumer_negotiation(api);
  test_table_and_initialization(api);
  test_lifecycle_surface_input_and_frame(api);
  test_utf8_and_ownership(api);
  test_host_services(api);
  for (const TrackedRef &entry : g_tracked_refs) {
    CHECK(entry.pointer == nullptr);
  }
  test_destroy_is_terminal(api);

  std::puts("mobile runtime ABI v1 tests passed");
  return 0;
}
