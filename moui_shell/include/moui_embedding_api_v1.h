#ifndef MOUI_EMBEDDING_API_V1_H
#define MOUI_EMBEDDING_API_V1_H

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

#ifndef MOUI_EMBEDDING_API
#if defined(_WIN32) && \
    (defined(MOUI_EMBEDDING_API_IMPLEMENTATION) || \
     defined(MOUI_EMBEDDING_API_BUILD_SHARED))
#define MOUI_EMBEDDING_API __declspec(dllexport)
#elif defined(_WIN32) && defined(MOUI_EMBEDDING_API_USE_SHARED)
#define MOUI_EMBEDDING_API __declspec(dllimport)
#elif defined(__GNUC__) || defined(__clang__)
#define MOUI_EMBEDDING_API __attribute__((visibility("default")))
#else
#define MOUI_EMBEDDING_API
#endif
#endif

#define MOUI_EMBEDDING_API_ABI_VERSION_V1 UINT32_C(1)

/*
 * Capability bits describe available contracts in moui_embedding_api_v1.
 * Function-specific capabilities require the corresponding entry to be
 * non-NULL; the compatibility helper audits all required entries.
 */
#define MOUI_EMBEDDING_API_CAPABILITY_LIFECYCLE_V1 (UINT64_C(1) << 0)
#define MOUI_EMBEDDING_API_CAPABILITY_SURFACE_V1 (UINT64_C(1) << 1)
#define MOUI_EMBEDDING_API_CAPABILITY_POINTER_V1 (UINT64_C(1) << 2)
#define MOUI_EMBEDDING_API_CAPABILITY_SCROLL_V1 (UINT64_C(1) << 3)
#define MOUI_EMBEDDING_API_CAPABILITY_FRAME_TICK_V1 (UINT64_C(1) << 4)
#define MOUI_EMBEDDING_API_CAPABILITY_EXPLICIT_RENDER_V1 (UINT64_C(1) << 5)
#define MOUI_EMBEDDING_API_CAPABILITY_RENDERER_CONFIGURATION_V1 \
  (UINT64_C(1) << 6)
#define MOUI_EMBEDDING_API_CAPABILITY_RENDERER_STATUS_V1 (UINT64_C(1) << 7)
#define MOUI_EMBEDDING_API_CAPABILITY_HOST_UPDATES_V1 (UINT64_C(1) << 8)
#define MOUI_EMBEDDING_API_CAPABILITY_TEXT_INPUT_V1 (UINT64_C(1) << 9)
#define MOUI_EMBEDDING_API_CAPABILITY_COMMAND_V1 (UINT64_C(1) << 10)
#define MOUI_EMBEDDING_API_CAPABILITY_ACCESSIBILITY_V1 (UINT64_C(1) << 11)
#define MOUI_EMBEDDING_API_CAPABILITY_CLIPBOARD_V1 (UINT64_C(1) << 12)
#define MOUI_EMBEDDING_API_CAPABILITY_OWNED_UTF8_V1 (UINT64_C(1) << 13)
#define MOUI_EMBEDDING_API_CAPABILITY_APPLICATION_DESTROY_V1 \
  (UINT64_C(1) << 14)
#define MOUI_EMBEDDING_API_CAPABILITY_HOST_RESPONSE_ENVELOPE_V1 \
  (UINT64_C(1) << 15)

#define MOUI_EMBEDDING_API_REQUIRED_CAPABILITIES_V1                       \
  (MOUI_EMBEDDING_API_CAPABILITY_LIFECYCLE_V1 |                           \
   MOUI_EMBEDDING_API_CAPABILITY_SURFACE_V1 |                             \
   MOUI_EMBEDDING_API_CAPABILITY_POINTER_V1 |                             \
   MOUI_EMBEDDING_API_CAPABILITY_FRAME_TICK_V1 |                          \
   MOUI_EMBEDDING_API_CAPABILITY_EXPLICIT_RENDER_V1 |                     \
   MOUI_EMBEDDING_API_CAPABILITY_RENDERER_CONFIGURATION_V1 |              \
   MOUI_EMBEDDING_API_CAPABILITY_RENDERER_STATUS_V1 |                     \
   MOUI_EMBEDDING_API_CAPABILITY_HOST_UPDATES_V1 |                        \
   MOUI_EMBEDDING_API_CAPABILITY_TEXT_INPUT_V1 |                          \
   MOUI_EMBEDDING_API_CAPABILITY_COMMAND_V1 |                             \
   MOUI_EMBEDDING_API_CAPABILITY_ACCESSIBILITY_V1 |                       \
   MOUI_EMBEDDING_API_CAPABILITY_CLIPBOARD_V1 |                           \
   MOUI_EMBEDDING_API_CAPABILITY_OWNED_UTF8_V1 |                          \
   MOUI_EMBEDDING_API_CAPABILITY_APPLICATION_DESTROY_V1 |                 \
   MOUI_EMBEDDING_API_CAPABILITY_HOST_RESPONSE_ENVELOPE_V1)

/*
 * Functions that forward MoonBit Boolean results preserve 1/0. Adapter
 * failures are negative. Owned-buffer functions use STATUS_OK on success.
 * Session calls return NOT_INITIALIZED before initialize completes and
 * APPLICATION_DESTROYED once final destruction starts.
 */
enum {
  MOUI_EMBEDDING_API_STATUS_OK_V1 = 0,
  MOUI_EMBEDDING_API_RESULT_FALSE_V1 = 0,
  MOUI_EMBEDDING_API_RESULT_TRUE_V1 = 1,
  MOUI_EMBEDDING_API_ERROR_INVALID_ARGUMENT_V1 = -1,
  MOUI_EMBEDDING_API_ERROR_NOT_INITIALIZED_V1 = -2,
  MOUI_EMBEDDING_API_ERROR_ALLOCATION_FAILED_V1 = -3,
  MOUI_EMBEDDING_API_ERROR_INVALID_UTF8_V1 = -4,
  MOUI_EMBEDDING_API_ERROR_INPUT_TOO_LARGE_V1 = -5,
  MOUI_EMBEDDING_API_ERROR_INVALID_UTF16_V1 = -6,
  MOUI_EMBEDDING_API_ERROR_INITIALIZATION_FAILED_V1 = -7,
  MOUI_EMBEDDING_API_ERROR_INTERNAL_V1 = -8,
  MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1 = -9
};

/*
 * Borrowed, length-driven input. data may be NULL only when length is zero.
 * The adapter never retains data after the function call. Embedded NUL bytes
 * are supported except in initialize's process argument.
 */
typedef struct moui_embedding_utf8_view_v1 {
  const uint8_t *data;
  size_t length;
} moui_embedding_utf8_view_v1;

typedef struct moui_embedding_bytes_view_v1 {
  const uint8_t *data;
  size_t length;
} moui_embedding_bytes_view_v1;

typedef void (*moui_embedding_utf8_release_v1)(
    void *release_context,
    uint8_t *data,
    size_t length);

/*
 * On success, data owns length + 1 bytes and data[length] is NUL. length is
 * authoritative and may include embedded NUL bytes. release and
 * release_context are non-NULL, including for an empty string. The consumer
 * must invoke release exactly once with the unmodified context/data/length.
 * On failure, status is negative and all other fields are NULL/zero.
 */
typedef struct moui_embedding_utf8_buffer_v1 {
  int32_t status;
  uint8_t *data;
  size_t length;
  void *release_context;
  moui_embedding_utf8_release_v1 release;
} moui_embedding_utf8_buffer_v1;

typedef int32_t (*moui_embedding_initialize_v1)(
    moui_embedding_utf8_view_v1 app_argument);
typedef int32_t (*moui_embedding_destroy_application_v1)(void);
typedef int32_t (*moui_embedding_detach_surface_v1)(void);
typedef int32_t (*moui_embedding_attach_surface_v1)(
    uint64_t surface_handle,
    int32_t width,
    int32_t height,
    double scale_factor);
typedef int32_t (*moui_embedding_resize_v1)(
    int32_t width,
    int32_t height,
    double scale_factor);
typedef int32_t (*moui_embedding_dispatch_pointer_v1)(
    int32_t phase,
    double x,
    double y,
    double time_ms);
typedef int32_t (*moui_embedding_dispatch_scroll_v1)(
    double x,
    double y,
    double delta_x,
    double delta_y,
    int32_t phase);
typedef int32_t (*moui_embedding_frame_tick_v1)(double time_ms);
typedef int32_t (*moui_embedding_render_frame_v1)(void);
typedef int32_t (*moui_embedding_configure_renderer_v1)(
    moui_embedding_utf8_view_v1 mode);
typedef moui_embedding_utf8_buffer_v1 (*moui_embedding_renderer_status_json_v1)(void);
typedef moui_embedding_utf8_buffer_v1 (*moui_embedding_take_host_update_envelope_json_v1)(void);
typedef int32_t (*moui_embedding_dispatch_host_response_envelope_v1)(
    moui_embedding_utf8_view_v1 envelope_json);
typedef int32_t (*moui_embedding_dispatch_text_input_v1)(
    int32_t kind,
    moui_embedding_utf8_view_v1 text,
    int32_t start,
    int32_t end);
typedef int32_t (*moui_embedding_dispatch_command_v1)(int32_t kind);
typedef int32_t (*moui_embedding_dispatch_accessibility_v1)(
    int32_t element_id,
    int32_t action,
    moui_embedding_utf8_view_v1 value);
typedef int32_t (*moui_embedding_complete_clipboard_v1)(
    int32_t session_generation,
    int32_t id,
    int32_t kind,
    moui_embedding_utf8_view_v1 text,
    moui_embedding_bytes_view_v1 bytes);

/*
 * The table is immutable and has process lifetime. Consumers must check both
 * abi_version, struct_size, required capabilities, and required function
 * pointers must be negotiated before use. New v1-compatible fields may only be
 * appended. Session calls must be serialized by the platform host; initialize
 * is internally synchronized and process-wide idempotent, and destroy is
 * internally guarded so its application hook executes at most once.
 *
 * MoonBit ownership never crosses this boundary. For borrowed text/bytes input,
 * the adapter creates temporary MoonBit values and releases them immediately
 * after the MoonBit export returns. Returned MoonBit strings are copied into an
 * owned UTF-8 buffer and then released by the adapter.
 */
typedef struct moui_embedding_api_v1 {
  uint32_t abi_version;
  uint32_t struct_size;
  uint64_t capabilities;

  /*
   * Lifecycle. initialize retains the selected argv[0] for process lifetime.
   * destroy_application permanently ends the application session without
   * shutting down the process-wide MoonBit runtime. It succeeds once; repeated
   * destroy and every later session call return APPLICATION_DESTROYED.
   */
  moui_embedding_initialize_v1 initialize;
  moui_embedding_destroy_application_v1 destroy_application;

  /*
   * Surface detach only releases the current platform surface. It preserves
   * application state and a later attach_surface starts a new surface epoch.
   */
  moui_embedding_detach_surface_v1 detach_surface;

  /* Surface. */
  moui_embedding_attach_surface_v1 attach_surface;
  moui_embedding_resize_v1 resize;

  /* Input. dispatch_scroll is NULL when its capability bit is absent. */
  moui_embedding_dispatch_pointer_v1 dispatch_pointer;
  moui_embedding_dispatch_scroll_v1 dispatch_scroll;

  /* Frame. */
  moui_embedding_frame_tick_v1 frame_tick;
  moui_embedding_render_frame_v1 render_frame;

  /* Renderer. */
  moui_embedding_configure_renderer_v1 configure_renderer;
  moui_embedding_renderer_status_json_v1 renderer_status_json;

  /* Host services. */
  /* Returns one Host Wire v1 update envelope with its surface generation. */
  moui_embedding_take_host_update_envelope_json_v1
      take_host_update_envelope_json;
  /*
   * Dispatches one length-driven Host Wire v1 UTF-8 response envelope. The
   * adapter preserves embedded NUL bytes; the MoonBit export owns JSON/schema
   * validation and returns 1/0 for handled/rejected envelopes.
   */
  moui_embedding_dispatch_host_response_envelope_v1
      dispatch_host_response_envelope;
  moui_embedding_dispatch_text_input_v1 dispatch_text_input;
  moui_embedding_dispatch_command_v1 dispatch_command;
  moui_embedding_dispatch_accessibility_v1 dispatch_accessibility;
  /* session_generation rejects async completions from detached surfaces. */
  moui_embedding_complete_clipboard_v1 complete_clipboard;
} moui_embedding_api_v1;

/*
 * Required v1 ends at complete_clipboard. Future optional fields may be
 * appended without changing this negotiation floor.
 */
#define MOUI_EMBEDDING_API_V1_REQUIRED_SIZE                              \
  ((uint32_t)(offsetof(moui_embedding_api_v1, complete_clipboard) +       \
              sizeof(((moui_embedding_api_v1 *)0)->complete_clipboard)))

/*
 * Consumer-side negotiation for the table returned by the getter. This helper
 * deliberately accepts a larger struct_size for forward-compatible v1 tables.
 */
static inline int moui_embedding_api_v1_is_compatible(
    const moui_embedding_api_v1 *api) {
  if (api == NULL ||
      api->abi_version != MOUI_EMBEDDING_API_ABI_VERSION_V1 ||
      api->struct_size < MOUI_EMBEDDING_API_V1_REQUIRED_SIZE ||
      (api->capabilities & MOUI_EMBEDDING_API_REQUIRED_CAPABILITIES_V1) !=
          MOUI_EMBEDDING_API_REQUIRED_CAPABILITIES_V1) {
    return 0;
  }

  if (api->initialize == NULL || api->destroy_application == NULL ||
      api->detach_surface == NULL || api->attach_surface == NULL ||
      api->resize == NULL || api->dispatch_pointer == NULL ||
      api->frame_tick == NULL || api->render_frame == NULL ||
      api->configure_renderer == NULL || api->renderer_status_json == NULL ||
      api->take_host_update_envelope_json == NULL ||
      api->dispatch_host_response_envelope == NULL ||
      api->dispatch_text_input == NULL || api->dispatch_command == NULL ||
      api->dispatch_accessibility == NULL ||
      api->complete_clipboard == NULL) {
    return 0;
  }

  if ((api->capabilities & MOUI_EMBEDDING_API_CAPABILITY_SCROLL_V1) != 0) {
    return api->dispatch_scroll != NULL;
  }
  return api->dispatch_scroll == NULL;
}

/* The returned table has process lifetime and must not be released. */
MOUI_EMBEDDING_API const moui_embedding_api_v1 *
moui_embedding_get_api_v1(void);

#if defined(__cplusplus)
} /* extern "C" */
#endif

#endif /* MOUI_EMBEDDING_API_V1_H */
