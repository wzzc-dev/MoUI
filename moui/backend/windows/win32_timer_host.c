#ifdef _WIN32

// Windows timer host: drives TimerSource subscriptions via a timer-queue
// timer that calls back into MoonBit on each tick. The returned handle cancels
// the timer via DeleteTimerQueueTimer.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>

// Trampoline: invokes the MoonBit tick closure captured by `closure`.
typedef void (*moui_windows_timer_trampoline_t)(void *closure);

typedef struct MouiWindowsTimer {
  HANDLE queue_timer;
  void *closure;
  moui_windows_timer_trampoline_t trampoline;
} MouiWindowsTimer;

// Timer callback: runs on the timer-queue thread. We marshal onto the MoonBit
// side directly; the subscription dispatch is thread-safe with respect to the
// runtime's pending-message queue.
static VOID CALLBACK moui_windows_timer_proc(PVOID context, BOOLEAN fired) {
  (void)fired;
  MouiWindowsTimer *timer = (MouiWindowsTimer *)context;
  if (timer == NULL || timer->trampoline == NULL || timer->closure == NULL) {
    return;
  }
  timer->trampoline(timer->closure);
}

MOONBIT_FFI_EXPORT
void *moui_windows_timer_start(double interval_ms,
                               moui_windows_timer_trampoline_t trampoline,
                               void *closure) {
  if (interval_ms <= 0.0) {
    return NULL;
  }
  MouiWindowsTimer *timer =
      (MouiWindowsTimer *)malloc(sizeof(MouiWindowsTimer));
  if (timer == NULL) {
    return NULL;
  }
  timer->trampoline = trampoline;
  timer->closure = closure;
  timer->queue_timer = NULL;
  // Retain the MoonBit closure so it survives until cancel.
  moonbit_incref(closure);
  DWORD period_ms = (DWORD)(interval_ms + 0.5);
  if (period_ms == 0) {
    period_ms = 1;
  }
  // Use the default timer queue (TimerQueue = NULL). There is no
  // GetTimerQueue() in the Windows API; NULL is the documented way to
  // schedule against the process default queue.
  BOOL ok = CreateTimerQueueTimer(
      &timer->queue_timer, NULL, moui_windows_timer_proc, timer,
      period_ms, period_ms, WT_EXECUTEDEFAULT);
  if (!ok) {
    moonbit_decref(closure);
    free(timer);
    return NULL;
  }
  return (void *)timer;
}

MOONBIT_FFI_EXPORT
void moui_windows_timer_cancel(void *handle) {
  if (handle == NULL) {
    return;
  }
  MouiWindowsTimer *timer = (MouiWindowsTimer *)handle;
  if (timer->queue_timer != NULL) {
    // TimerQueue = NULL targets the default queue, matching the queue used
    // at creation time in moui_windows_timer_start.
    DeleteTimerQueueTimer(NULL, timer->queue_timer,
                          INVALID_HANDLE_VALUE);
    timer->queue_timer = NULL;
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

typedef void (*moui_windows_timer_trampoline_t)(void *closure);

MOONBIT_FFI_EXPORT
void *moui_windows_timer_start(double interval_ms,
                               moui_windows_timer_trampoline_t trampoline,
                               void *closure) {
  (void)interval_ms;
  (void)trampoline;
  (void)closure;
  return NULL;
}

MOONBIT_FFI_EXPORT
void moui_windows_timer_cancel(void *handle) {
  (void)handle;
}

#endif
