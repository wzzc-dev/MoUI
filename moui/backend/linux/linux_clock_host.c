// Host monotonic milliseconds for the runtime frame clock.
//
// Without it the runtime driver advances the animation clock with a fixed
// 16ms step per painted frame, so a 180ms transition takes eleven frames and
// therefore stretches with the paint rate (on a CPU-rastered window: seconds
// instead of 180ms). Supplying real milliseconds keeps every duration in
// wall-clock time, whatever the refresh or paint rate.
//
// The Linux host is production; the other host profiles still compile this
// package for their test targets, so the same symbol must report real time
// there too instead of a zero stub.

#include <moonbit.h>

#if defined(_WIN32)

#include <windows.h>

MOONBIT_FFI_EXPORT
double moui_linux_monotonic_now_ms(void) {
  static LARGE_INTEGER frequency;
  static int initialized = 0;
  if (!initialized) {
    QueryPerformanceFrequency(&frequency);
    initialized = 1;
  }
  LARGE_INTEGER counter;
  QueryPerformanceCounter(&counter);
  return (double)counter.QuadPart * 1000.0 / (double)frequency.QuadPart;
}

#else

#include <time.h>

MOONBIT_FFI_EXPORT
double moui_linux_monotonic_now_ms(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0.0;
  }
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
}

#endif
