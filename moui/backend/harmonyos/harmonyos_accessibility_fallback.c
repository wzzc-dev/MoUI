/* Host-build fallbacks for the HarmonyOS accessibility bridge.
 *
 * `harmonyos_accessibility.cpp` only compiles into the HAP's shared library,
 * where the ArkUI accessibility headers exist. Host builds of the Showcase
 * entrypoint still link the MoonBit side (which references these symbols), so
 * provide inert definitions that report "no provider" instead of failing the
 * link. Nothing calls them on a host.
 */
#include <stdint.h>

/* Weak definitions: on a device the real bridge in
 * harmonyos_accessibility.cpp wins, and on a host build these keep the link
 * alive. The template globs this file together with the real implementation, so
 * strong symbols here would collide. */
#define MBW_A11Y_FALLBACK __attribute__((weak))

MBW_A11Y_FALLBACK int32_t mbw_harmonyos_accessibility_register(void) { return 0; }

MBW_A11Y_FALLBACK void mbw_harmonyos_accessibility_publish(
    int64_t nodes_ptr, int32_t node_count, int64_t child_ids_ptr,
    int32_t child_count, int64_t action_kinds_ptr, int32_t action_count,
    int64_t root_id, int64_t focused_id, int64_t generation) {
  (void)nodes_ptr;
  (void)node_count;
  (void)child_ids_ptr;
  (void)child_count;
  (void)action_kinds_ptr;
  (void)action_count;
  (void)root_id;
  (void)focused_id;
  (void)generation;
}

MBW_A11Y_FALLBACK int32_t mbw_harmonyos_accessibility_status(void) { return 0; }

MBW_A11Y_FALLBACK int32_t mbw_harmonyos_accessibility_take_action(
    int64_t *element_id, int32_t *action, int64_t *generation) {
  (void)element_id;
  (void)action;
  (void)generation;
  return 0;
}

MBW_A11Y_FALLBACK void mbw_harmonyos_accessibility_set_xcomponent(int64_t handle) {
  (void)handle;
}

MBW_A11Y_FALLBACK uint64_t mbw_harmonyos_int64_address(void *array) {
  return (uint64_t)(uintptr_t)array;
}

MBW_A11Y_FALLBACK uint64_t mbw_harmonyos_int32_address(void *array) {
  return (uint64_t)(uintptr_t)array;
}

MBW_A11Y_FALLBACK uint64_t mbw_harmonyos_record_address(void *array) {
  return (uint64_t)(uintptr_t)array;
}

MBW_A11Y_FALLBACK void mbw_harmonyos_log_image_status(void *summary) {
  (void)summary;
}

MBW_A11Y_FALLBACK void mbw_harmonyos_log_text(void *tag, void *text) {
  (void)tag;
  (void)text;
}

/* Host-build stand-ins for the vsync frame pacing hooks. On a device the real
 * implementation lives in window/modules/window/harmonyos/native/
 * mbw_harmonyos_compat.c (guarded by __OHOS__); host builds skip that file, so
 * these keep the MoonBit side linkable. Weak so the device build wins. */
MBW_A11Y_FALLBACK int32_t mbw_harmonyos_vsync_init(void) { return 0; }

MBW_A11Y_FALLBACK int32_t mbw_harmonyos_wait_for_vsync(int32_t timeout_ms) {
  (void)timeout_ms;
  return 0;
}

MBW_A11Y_FALLBACK double mbw_harmonyos_monotonic_ms(void) { return 0.0; }
