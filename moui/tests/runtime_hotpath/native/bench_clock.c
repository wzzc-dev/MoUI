#define _POSIX_C_SOURCE 199309L

#include <moonbit.h>

#include <stdint.h>

#if defined(_WIN32)
#include <windows.h>
#elif defined(__APPLE__)
#include <mach/mach_time.h>
#else
#include <time.h>
#endif

MOONBIT_FFI_EXPORT
double moui_reconciliation_benchmark_now_ms(void) {
#if defined(_WIN32)
  LARGE_INTEGER frequency;
  LARGE_INTEGER counter;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&counter);
  return ((double)counter.QuadPart * 1000.0) / (double)frequency.QuadPart;
#elif defined(__APPLE__)
  static mach_timebase_info_data_t timebase = {0, 0};
  if (timebase.denom == 0) {
    mach_timebase_info(&timebase);
  }
  uint64_t ticks = mach_absolute_time();
  double ns = (double)ticks * (double)timebase.numer / (double)timebase.denom;
  return ns / 1000000.0;
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
#endif
}
