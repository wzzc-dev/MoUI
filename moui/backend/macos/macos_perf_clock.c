#define _POSIX_C_SOURCE 199309L

#include <moonbit.h>

#include <stdint.h>
#include <time.h>

#if defined(__APPLE__)
#include <mach/mach_time.h>
#endif

// Monotonic milliseconds for macOS GPU performance smoke present-to-present
// intervals. Matches the full_cycle benchmark clock style.
MOONBIT_FFI_EXPORT
double moui_macos_perf_now_ms(void) {
#if defined(__APPLE__)
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

static struct tm moui_macos_local_time(void) {
  time_t now = time(NULL);
  struct tm local_time = {0};
#if defined(_WIN32)
  localtime_s(&local_time, &now);
#else
  localtime_r(&now, &local_time);
#endif
  return local_time;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_year(void) {
  return moui_macos_local_time().tm_year + 1900;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_month(void) {
  return moui_macos_local_time().tm_mon + 1;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_day(void) {
  return moui_macos_local_time().tm_mday;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_weekday(void) {
  return moui_macos_local_time().tm_wday;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_hour(void) {
  return moui_macos_local_time().tm_hour;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_minute(void) {
  return moui_macos_local_time().tm_min;
}

MOONBIT_FFI_EXPORT
int moui_macos_wall_clock_second(void) {
  return moui_macos_local_time().tm_sec;
}
