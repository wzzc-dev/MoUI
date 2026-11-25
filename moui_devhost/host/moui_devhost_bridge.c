// Bridge host side: load a generated app plugin, keep its opaque function
// table, and copy primitive byte buffers across the two MoonBit runtimes.
// MoonBit objects never cross this boundary.

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <process.h>
#include <wchar.h>
#else
// `clock_gettime` is a POSIX extension that Apple headers hide under strict
// language modes; declare the feature level before any system header. Pair it
// with `_DARWIN_C_SOURCE` so `<mach-o/dyld.h>` keeps `_dyld_image_count`.
#if defined(__APPLE__) && !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE 199309L
#endif
#if defined(__APPLE__) && !defined(_DARWIN_C_SOURCE)
#define _DARWIN_C_SOURCE 1
#endif
// `dl_iterate_phdr` is a GNU extension; define the feature macro before any
// system header so the Linux image-count probe compiles under plain `cc`.
#if !defined(__APPLE__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE 1
#endif
#include <dlfcn.h>
#include <time.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <mach-o/dyld.h>
#else
#include <link.h>
#endif
#endif

#include <moonbit.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void (*hot_init_fn)(void);
typedef int32_t (*hot_abi_fn)(void);
typedef int32_t (*hot_create_fn)(const uint8_t *, int32_t);
typedef void (*hot_destroy_fn)(void);
typedef int32_t (*hot_event_fn)(const uint8_t *, int32_t);
typedef const uint8_t *(*hot_frame_fn)(void);
typedef int32_t (*hot_frame_len_fn)(void);
typedef void (*hot_frame_release_fn)(void);
typedef void (*hot_flush_fn)(void);
typedef void (*hot_resize_fn)(double, double);
typedef moonbit_bytes_t (*hot_semantics_action_fn)(const uint8_t *, int32_t);
typedef int32_t (*hot_semantics_action_len_fn)(void);
typedef void (*hot_semantics_action_release_fn)(void);

typedef struct {
  void *handle;
  hot_init_fn init;
  hot_abi_fn abi;
  hot_create_fn create;
  hot_destroy_fn destroy;
  hot_event_fn event;
  hot_frame_fn frame;
  hot_frame_len_fn frame_len;
  hot_frame_release_fn frame_release;
  hot_flush_fn flush;
  hot_resize_fn resize;
  // Optional platform-state entry points. Older plugin builds omit them; the
  // host reports semantics actions as unavailable instead of failing to load.
  hot_semantics_action_fn semantics_action;
  hot_semantics_action_len_fn semantics_action_len;
  hot_semantics_action_release_fn semantics_action_release;
} hot_api;

static hot_api g_current = {0};

#if !defined(_WIN32)
static int g_argc = 0;
static char **g_argv = NULL;

// A dev-loop re-exec keeps the same command line, so the constructor captures
// argv once. On macOS dyld keeps MoonBit dylibs mapped after dlclose (the
// runtime has static TLS); the host therefore re-execs itself after a bounded
// number of swaps. Linux measures the same counter through `dl_iterate_phdr`.
__attribute__((constructor)) static void hot_capture_args(int argc, char **argv,
                                                         char **envp) {
  (void)envp;
  g_argc = argc;
  g_argv = argv;
}
#endif

static int hot_debug_enabled(void) {
  const char *value = getenv("MOUI_HOT_DEBUG");
  return value != NULL && value[0] != '\0';
}

#if defined(_WIN32)
static int hot_plugin_image_count(void) {
  int count = 0;
  HANDLE snapshot = CreateToolhelp32Snapshot(
      TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, GetCurrentProcessId());
  if (snapshot == INVALID_HANDLE_VALUE) {
    return 0;
  }
  MODULEENTRY32W entry;
  entry.dwSize = sizeof(entry);
  if (Module32FirstW(snapshot, &entry)) {
    do {
      if (wcsstr(entry.szModule, L"plugin") != NULL ||
          wcsstr(entry.szExePath, L"plugin") != NULL) {
        count++;
      }
    } while (Module32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  return count;
}
#elif defined(__APPLE__)
static int hot_plugin_image_count(void) {
  int count = 0;
  uint32_t total = _dyld_image_count();
  for (uint32_t index = 0; index < total; index++) {
    const char *name = _dyld_get_image_name(index);
    if (name != NULL && strstr(name, "plugin") != NULL) {
      count++;
    }
  }
  return count;
}
#else
static int hot_count_plugin_image(struct dl_phdr_info *info, size_t size,
                                  void *data) {
  (void)size;
  int *count = (int *)data;
  if (info != NULL && info->dlpi_name != NULL &&
      strstr(info->dlpi_name, "plugin") != NULL) {
    *count += 1;
  }
  return 0;
}

static int hot_plugin_image_count(void) {
  int count = 0;
  dl_iterate_phdr(hot_count_plugin_image, &count);
  return count;
}
#endif

static void hot_log(const char *message) {
  if (hot_debug_enabled()) {
    fprintf(stderr, "moui-devhost: %s\n", message);
  }
}

#if defined(_WIN32)
static void hot_log_close(const char *label, void *handle, int result) {
  if (!hot_debug_enabled()) {
    return;
  }
  fprintf(stderr, "moui-devhost: %s FreeLibrary=%d rc=%d images=%d\n", label,
          handle != NULL, result, hot_plugin_image_count());
}
#else
static void hot_log_close(const char *label, void *handle, int result) {
  if (!hot_debug_enabled()) {
    return;
  }
  fprintf(stderr, "moui-devhost: %s dlclose=%d rc=%d images=%d\n", label,
          handle != NULL, result, hot_plugin_image_count());
}
#endif

static char *hot_copy_string(const uint8_t *data, int32_t length) {
  if (length < 0 || data == NULL) {
    return NULL;
  }
  char *text = (char *)malloc((size_t)length + 1);
  if (text == NULL) {
    return NULL;
  }
  memcpy(text, data, (size_t)length);
  text[length] = '\0';
  return text;
}

#if defined(_WIN32)
// UTF-8 (the MoonBit String encoding) to UTF-16 for LoadLibraryW.
static wchar_t *hot_copy_wide(const uint8_t *data, int32_t length) {
  if (length < 0 || data == NULL) {
    return NULL;
  }
  int wide_len = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                     (const char *)data, length, NULL, 0);
  if (wide_len <= 0) {
    return NULL;
  }
  wchar_t *wide =
      (wchar_t *)malloc(((size_t)wide_len + 1) * sizeof(wchar_t));
  if (wide == NULL) {
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)data,
                          length, wide, wide_len) != wide_len) {
    free(wide);
    return NULL;
  }
  wide[wide_len] = L'\0';
  return wide;
}

static void *hot_open_library(const uint8_t *path, int32_t path_len,
                              const char *label) {
  wchar_t *wide = hot_copy_wide(path, path_len);
  if (wide == NULL) {
    hot_log("plugin path is not valid UTF-8");
    return NULL;
  }
  HMODULE handle = LoadLibraryW(wide);
  if (handle == NULL && hot_debug_enabled()) {
    fprintf(stderr, "moui-devhost: %s LoadLibraryW failed: %lu\n", label,
            (unsigned long)GetLastError());
  }
  free(wide);
  return (void *)handle;
}

static int hot_close_library(void *handle) {
  return FreeLibrary((HMODULE)handle) ? 0 : 1;
}

static void *hot_symbol(void *handle, const char *name) {
  return (void *)GetProcAddress((HMODULE)handle, name);
}
#else
static void *hot_open_library(const uint8_t *path, int32_t path_len,
                              const char *label) {
  char *plugin_path = hot_copy_string(path, path_len);
  if (plugin_path == NULL) {
    return NULL;
  }
  void *handle = dlopen(plugin_path, RTLD_NOW | RTLD_LOCAL);
  free(plugin_path);
  if (handle == NULL && hot_debug_enabled()) {
    const char *error = dlerror();
    fprintf(stderr, "moui-devhost: %s dlopen failed: %s\n", label,
            error != NULL ? error : "(no error)");
  }
  return handle;
}

static int hot_close_library(void *handle) { return dlclose(handle); }

static void *hot_symbol(void *handle, const char *name) {
  return dlsym(handle, name);
}
#endif

static void hot_clear_api(hot_api *api) {
  memset(api, 0, sizeof(hot_api));
}

static int hot_resolve(hot_api *api, void *handle) {
  hot_clear_api(api);
  api->handle = handle;
  api->init = (hot_init_fn)hot_symbol(handle, "moonbit_init");
  api->abi = (hot_abi_fn)hot_symbol(handle, "dev_abi_version");
  api->create = (hot_create_fn)hot_symbol(handle, "dev_create");
  api->destroy = (hot_destroy_fn)hot_symbol(handle, "dev_destroy");
  api->event = (hot_event_fn)hot_symbol(handle, "dev_event");
  api->frame = (hot_frame_fn)hot_symbol(handle, "dev_frame");
  api->frame_len = (hot_frame_len_fn)hot_symbol(handle, "dev_frame_len");
  api->frame_release =
      (hot_frame_release_fn)hot_symbol(handle, "dev_frame_release");
  api->flush = (hot_flush_fn)hot_symbol(handle, "dev_flush");
  api->resize = (hot_resize_fn)hot_symbol(handle, "dev_resize");
  api->semantics_action =
      (hot_semantics_action_fn)hot_symbol(handle, "dev_semantics_action");
  api->semantics_action_len = (hot_semantics_action_len_fn)hot_symbol(
      handle, "dev_semantics_action_len");
  api->semantics_action_release = (hot_semantics_action_release_fn)hot_symbol(
      handle, "dev_semantics_action_release");
  if (api->semantics_action == NULL || api->semantics_action_len == NULL ||
      api->semantics_action_release == NULL) {
    // All three are optional together: a partial implementation is treated as
    // absent so the host has one unambiguous capability answer.
    api->semantics_action = NULL;
    api->semantics_action_len = NULL;
    api->semantics_action_release = NULL;
  }
  if (api->init == NULL || api->abi == NULL || api->create == NULL ||
      api->destroy == NULL ||
      api->event == NULL || api->frame == NULL || api->frame_len == NULL ||
      api->frame_release == NULL || api->flush == NULL || api->resize == NULL) {
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_devhost_open(const uint8_t *path, int32_t path_len,
                          const uint8_t *config, int32_t config_len) {
  if (g_current.handle != NULL) {
    g_current.destroy();
    g_current.destroy = NULL;
    hot_close_library(g_current.handle);
    hot_clear_api(&g_current);
  }
  void *handle = hot_open_library(path, path_len, "open");
  if (handle == NULL) {
    return 1;
  }
  hot_api next;
  if (hot_resolve(&next, handle) != 0) {
    hot_log("open missing ABI symbols");
    hot_close_library(handle);
    return 1;
  }
  next.init();
  if (next.abi() != 1) {
    hot_log("open ABI mismatch");
    hot_close_library(handle);
    return 1;
  }
  if (next.create(config, config_len) != 0) {
    hot_log("open dev_create failed");
    hot_close_library(handle);
    return 1;
  }
  g_current = next;
  return 0;
}

// Atomically replace the live plugin generation. The old generation is flushed
// before the new one restores state, and only destroyed after the new create
// succeeds; a build/load failure leaves the old UI running.
MOONBIT_FFI_EXPORT
int32_t moui_devhost_reload(const uint8_t *path, int32_t path_len,
                            const uint8_t *config, int32_t config_len) {
  void *handle = hot_open_library(path, path_len, "reload");
  if (handle == NULL) {
    return 1;
  }
  hot_api next;
  if (hot_resolve(&next, handle) != 0) {
    hot_log("reload missing ABI symbols");
    hot_close_library(handle);
    return 1;
  }
  next.init();
  if (next.abi() != 1) {
    hot_log("reload ABI mismatch");
    hot_close_library(handle);
    return 1;
  }
  if (g_current.handle != NULL) {
    g_current.flush();
  }
  if (next.create(config, config_len) != 0) {
    hot_log("reload dev_create failed; keeping previous generation");
    hot_close_library(handle);
    return 1;
  }
  if (g_current.handle != NULL) {
    g_current.destroy();
    int close_rc = hot_close_library(g_current.handle);
    hot_log_close("reload-old", g_current.handle, close_rc);
  }
  g_current = next;
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_devhost_event(const uint8_t *data, int32_t length) {
  if (g_current.handle == NULL) {
    return 1;
  }
  return g_current.event(data, length);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_devhost_frame(void) {
  if (g_current.handle == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  const uint8_t *data = g_current.frame();
  int32_t length = g_current.frame_len();
  moonbit_bytes_t copy = moonbit_make_bytes(length, 0);
  if (data != NULL && length > 0) {
    memcpy(copy, data, (size_t)length);
  }
  g_current.frame_release();
  return copy;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_devhost_semantics_action(const uint8_t *data,
                                              int32_t length) {
  if (g_current.handle == NULL || g_current.semantics_action == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  const uint8_t *payload = g_current.semantics_action(data, length);
  int32_t payload_length = g_current.semantics_action_len();
  moonbit_bytes_t copy = moonbit_make_bytes(payload_length, 0);
  if (payload != NULL && payload_length > 0) {
    memcpy(copy, payload, (size_t)payload_length);
  }
  g_current.semantics_action_release();
  return copy;
}

MOONBIT_FFI_EXPORT
void moui_devhost_resize(double width, double height) {
  if (g_current.handle != NULL) {
    g_current.resize(width, height);
  }
}

MOONBIT_FFI_EXPORT
void moui_devhost_destroy(void) {
  if (g_current.handle == NULL) {
    return;
  }
  g_current.flush();
  g_current.destroy();
  int close_rc = hot_close_library(g_current.handle);
  hot_log_close("shutdown", g_current.handle, close_rc);
  hot_clear_api(&g_current);
}

// Dev-only offscreen pacing. The bridge host runs a synchronous frame loop
// outside any window backend, so it needs a blocking millisecond sleep without
// depending on a platform package. These are additive host-side facilities;
// they never cross the plugin ABI.
MOONBIT_FFI_EXPORT
void moui_devhost_sleep_ms(int32_t milliseconds) {
  if (milliseconds <= 0) {
    return;
  }
#if defined(_WIN32)
  Sleep((DWORD)milliseconds);
#else
  struct timespec request;
  request.tv_sec = milliseconds / 1000;
  request.tv_nsec = (long)(milliseconds % 1000) * 1000000L;
  while (nanosleep(&request, &request) != 0) {
    // A signal can shorten the sleep; resume with the remaining time.
  }
#endif
}

// Monotonic milliseconds for the offscreen runtime clock and plugin frame
// ticks. QueryPerformanceCounter is used on Windows because it is available
// regardless of the targeted _WIN32_WINNT and does not wrap during a run.
MOONBIT_FFI_EXPORT
double moui_devhost_now_ms(void) {
#if defined(_WIN32)
  LARGE_INTEGER frequency;
  LARGE_INTEGER counter;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&counter);
  if (frequency.QuadPart == 0) {
    return 0.0;
  }
  return (double)counter.QuadPart * 1000.0 / (double)frequency.QuadPart;
#else
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec * 1000.0 + (double)now.tv_nsec / 1000000.0;
#endif
}

// Called after the plugin has flushed state and before the host is replaced.
// The dev runner sees the same process continue; only the window is recreated.
MOONBIT_FFI_EXPORT
void moui_devhost_reexec(void) {
  if (hot_debug_enabled()) {
    fprintf(stderr, "moui-devhost: re-exec after reload budget\n");
  }
#if defined(_WIN32)
  wchar_t module_path[32768];
  DWORD len = GetModuleFileNameW(NULL, module_path,
                                 (DWORD)(sizeof(module_path) /
                                         sizeof(module_path[0])));
  if (len > 0 && len < (DWORD)(sizeof(module_path) / sizeof(module_path[0]))) {
    int argc = 0;
    wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    (void)argc;
    if (argv != NULL) {
      _wexecv(module_path, (const wchar_t *const *)argv);
      LocalFree(argv);
    }
  }
#else
  if (g_argc > 0 && g_argv != NULL && g_argv[0] != NULL) {
    execv(g_argv[0], g_argv);
  }
#endif
  _exit(75);
}
