#ifdef __linux__

// Linux timer host: drives HostTimerSource subscriptions via a GLib timeout
// source on the default main context. The returned handle removes the source
// via g_source_remove.

#include <glib.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>

// Trampoline: invokes the MoonBit tick closure captured by `closure`.
typedef void (*moui_linux_timer_trampoline_t)(void *closure);

typedef struct MouiLinuxTimer {
  guint source_id;
  void *closure;
  moui_linux_timer_trampoline_t trampoline;
} MouiLinuxTimer;

// Timeout callback: runs on the GLib main loop. Returns TRUE to keep the
// source repeating.
static gboolean moui_linux_timer_proc(gpointer data) {
  MouiLinuxTimer *timer = (MouiLinuxTimer *)data;
  if (timer == NULL || timer->trampoline == NULL || timer->closure == NULL) {
    return FALSE;
  }
  timer->trampoline(timer->closure);
  return TRUE;
}

MOONBIT_FFI_EXPORT
void *moui_linux_timer_start(double interval_ms,
                             moui_linux_timer_trampoline_t trampoline,
                             void *closure) {
  if (interval_ms <= 0.0) {
    return NULL;
  }
  MouiLinuxTimer *timer = (MouiLinuxTimer *)malloc(sizeof(MouiLinuxTimer));
  if (timer == NULL) {
    return NULL;
  }
  timer->trampoline = trampoline;
  timer->closure = closure;
  // Retain the MoonBit closure so it survives until cancel.
  moonbit_incref(closure);
  guint interval_ms_int = (guint)(interval_ms + 0.5);
  if (interval_ms_int == 0) {
    interval_ms_int = 1;
  }
  timer->source_id = g_timeout_add(interval_ms_int, moui_linux_timer_proc, timer);
  return (void *)timer;
}

MOONBIT_FFI_EXPORT
void moui_linux_timer_cancel(void *handle) {
  if (handle == NULL) {
    return;
  }
  MouiLinuxTimer *timer = (MouiLinuxTimer *)handle;
  if (timer->source_id != 0) {
    g_source_remove(timer->source_id);
    timer->source_id = 0;
  }
  if (timer->closure != NULL) {
    moonbit_decref(timer->closure);
    timer->closure = NULL;
  }
  free(timer);
}


#else

#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>

typedef void (*moui_linux_timer_trampoline_t)(void *closure);

MOONBIT_FFI_EXPORT
void *moui_linux_timer_start(double interval_ms,
                             moui_linux_timer_trampoline_t trampoline,
                             void *closure) {
  (void)interval_ms;
  (void)trampoline;
  (void)closure;
  return NULL;
}

MOONBIT_FFI_EXPORT
void moui_linux_timer_cancel(void *handle) {
  (void)handle;
}

#endif
