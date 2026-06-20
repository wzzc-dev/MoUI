// macOS timer host: drives HostTimerSource subscriptions via dispatch_source
// timers on the main queue. A repeating timer stores a trampoline + closure
// pair and calls back into MoonBit on each fire; the returned handle cancels
// the source via dispatch_source_cancel.

#import <Foundation/Foundation.h>
#import <moonbit.h>
#import <stdint.h>

// Trampoline: invokes the MoonBit tick closure captured by `closure`.
typedef void (*moui_macos_timer_trampoline_t)(void *closure);

typedef struct MouiMacosTimer {
  dispatch_source_t source;
  void *closure;
  moui_macos_timer_trampoline_t trampoline;
} MouiMacosTimer;

// Fire the timer on the main queue: call the trampoline, which re-enters
// MoonBit to dispatch the subscription message.
static void moui_macos_timer_fire(void *context) {
  MouiMacosTimer *timer = (MouiMacosTimer *)context;
  if (timer == NULL || timer->trampoline == NULL || timer->closure == NULL) {
    return;
  }
  timer->trampoline(timer->closure);
}

MOONBIT_FFI_EXPORT
void *moui_macos_timer_start(double interval_ms,
                             moui_macos_timer_trampoline_t trampoline,
                             void *closure) {
  if (interval_ms <= 0.0) {
    return NULL;
  }
  MouiMacosTimer *timer = (MouiMacosTimer *)malloc(sizeof(MouiMacosTimer));
  if (timer == NULL) {
    return NULL;
  }
  timer->trampoline = trampoline;
  timer->closure = closure;
  // Retain the MoonBit closure so it survives until cancel.
  moonbit_incref(closure);
  // A repeating dispatch source on the main queue; the host run loop drives it.
  dispatch_queue_t queue = dispatch_get_main_queue();
  dispatch_source_t source = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  uint64_t interval_nanos = (uint64_t)(interval_ms * 1000000.0);
  if (interval_nanos < 1000000ULL) {
    interval_nanos = 1000000ULL; // floor at 1ms
  }
  dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, 0),
                            interval_nanos, interval_nanos);
  timer->source = source;
  // Bridge the timer into an Objective-C object so ARC retains it for the
  // source's context lifetime.
  MouiMacosTimer *context = timer;
  dispatch_source_set_event_handler(source, ^{
    moui_macos_timer_fire(context);
  });
  dispatch_resume(source);
  return (void *)timer;
}

MOONBIT_FFI_EXPORT
void moui_macos_timer_cancel(void *handle) {
  if (handle == NULL) {
    return;
  }
  MouiMacosTimer *timer = (MouiMacosTimer *)handle;
  if (timer->source != NULL) {
    dispatch_source_cancel(timer->source);
    // Release the source once the cancellation handler has run; here we just
    // drop our reference since dispatch_source_cancel is idempotent.
    #if __has_feature(objc_arc)
    timer->source = NULL;
    #else
    dispatch_release(timer->source);
    timer->source = NULL;
    #endif
  }
  if (timer->closure != NULL) {
    moonbit_decref(timer->closure);
    timer->closure = NULL;
  }
  free(timer);
}
