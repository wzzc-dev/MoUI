#include <stdint.h>
#include <stdio.h>
#include <sys/stat.h>
#include <time.h>

#if defined(__APPLE__)
#include <mach-o/dyld.h>
#include <malloc/malloc.h>
#include <sys/resource.h>
#elif defined(__linux__)
#include <limits.h>
#include <malloc.h>
#include <sys/resource.h>
#include <unistd.h>
#elif defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <psapi.h>
#endif

double moui_performance_budget_now_ms(void) {
#if defined(_WIN32)
  LARGE_INTEGER frequency;
  LARGE_INTEGER counter;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&counter);
  return (double)counter.QuadPart * 1000.0 / (double)frequency.QuadPart;
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
#endif
}

double moui_performance_budget_peak_rss_bytes(void) {
#if defined(_WIN32)
  PROCESS_MEMORY_COUNTERS counters;
  if (GetProcessMemoryInfo(GetCurrentProcess(), &counters, sizeof(counters))) {
    return (double)counters.PeakWorkingSetSize;
  }
  return 0.0;
#else
  struct rusage usage;
  if (getrusage(RUSAGE_SELF, &usage) != 0) {
    return 0.0;
  }
#if defined(__APPLE__)
  return (double)usage.ru_maxrss;
#else
  return (double)usage.ru_maxrss * 1024.0;
#endif
#endif
}

double moui_performance_budget_allocation_count(void) {
#if defined(__APPLE__)
  malloc_statistics_t statistics;
  malloc_zone_statistics(malloc_default_zone(), &statistics);
  return (double)statistics.blocks_in_use;
#elif defined(__linux__)
  struct mallinfo2 info = mallinfo2();
  return (double)(info.hblks + info.ordblks);
#else
  return 0.0;
#endif
}

double moui_performance_budget_package_bytes(void) {
  char path[4096];
#if defined(__APPLE__)
  uint32_t length = (uint32_t)sizeof(path);
  if (_NSGetExecutablePath(path, &length) != 0) {
    return 0.0;
  }
#elif defined(__linux__)
  ssize_t length = readlink("/proc/self/exe", path, sizeof(path) - 1);
  if (length <= 0) {
    return 0.0;
  }
  path[length] = '\0';
#elif defined(_WIN32)
  DWORD length = GetModuleFileNameA(NULL, path, (DWORD)sizeof(path));
  if (length == 0 || length >= sizeof(path)) {
    return 0.0;
  }
#else
  return 0.0;
#endif
  struct stat file_stat;
  if (stat(path, &file_stat) != 0) {
    return 0.0;
  }
  return (double)file_stat.st_size;
}
