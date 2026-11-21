#ifdef __linux__

// Linux host clock: monotonic milliseconds for the runtime frame clock.
//
// Without it the runtime driver advances the animation clock with a fixed
// 16ms step per painted frame, so a 180ms transition takes eleven frames and
// therefore stretches with the paint rate (on a CPU-rastered window: seconds
// instead of 180ms). Supplying real milliseconds keeps every duration in
// wall-clock time, whatever the refresh or paint rate.

#include <moonbit.h>
#include <time.h>

MOONBIT_FFI_EXPORT
double moui_linux_monotonic_now_ms(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0.0;
  }
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

#else

#include <moonbit.h>

MOONBIT_FFI_EXPORT
double moui_linux_monotonic_now_ms(void) { return 0.0; }

#endif
