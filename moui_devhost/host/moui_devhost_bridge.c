// Bridge host side: dlopen a generated app plugin, keep its opaque function
// table, and copy primitive byte buffers across the two MoonBit runtimes.
// MoonBit objects never cross this boundary.

// `dl_iterate_phdr` is a GNU extension; define the feature macro before any
// system header so the Linux image-count probe compiles under plain `cc`.
#if !defined(__APPLE__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE 1
#endif

#include <moonbit.h>

#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <mach-o/dyld.h>
#else
#include <link.h>
#endif

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
} hot_api;

static hot_api g_current = {0};
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

static int hot_debug_enabled(void) {
  const char *value = getenv("MOUI_HOT_DEBUG");
  return value != NULL && value[0] != '\0';
}

#if defined(__APPLE__)
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

static void hot_log_close(const char *label, void *handle, int result) {
  if (!hot_debug_enabled()) {
    return;
  }
  fprintf(stderr, "moui-devhost: %s dlclose=%d rc=%d images=%d\n", label,
          handle != NULL, result, hot_plugin_image_count());
}

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

static void hot_clear_api(hot_api *api) {
  memset(api, 0, sizeof(hot_api));
}

static int hot_resolve(hot_api *api, void *handle) {
  hot_clear_api(api);
  api->handle = handle;
  api->init = (hot_init_fn)dlsym(handle, "moonbit_init");
  api->abi = (hot_abi_fn)dlsym(handle, "dev_abi_version");
  api->create = (hot_create_fn)dlsym(handle, "dev_create");
  api->destroy = (hot_destroy_fn)dlsym(handle, "dev_destroy");
  api->event = (hot_event_fn)dlsym(handle, "dev_event");
  api->frame = (hot_frame_fn)dlsym(handle, "dev_frame");
  api->frame_len = (hot_frame_len_fn)dlsym(handle, "dev_frame_len");
  api->frame_release =
      (hot_frame_release_fn)dlsym(handle, "dev_frame_release");
  api->flush = (hot_flush_fn)dlsym(handle, "dev_flush");
  api->resize = (hot_resize_fn)dlsym(handle, "dev_resize");
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
    dlclose(g_current.handle);
    hot_clear_api(&g_current);
  }
  char *plugin_path = hot_copy_string(path, path_len);
  if (plugin_path == NULL) {
    return 1;
  }
  void *handle = dlopen(plugin_path, RTLD_NOW | RTLD_LOCAL);
  free(plugin_path);
  if (handle == NULL) {
    if (hot_debug_enabled()) {
      const char *error = dlerror();
      fprintf(stderr, "moui-devhost: open dlopen failed: %s\n",
              error != NULL ? error : "(no error)");
    }
    return 1;
  }
  hot_api next;
  if (hot_resolve(&next, handle) != 0) {
    hot_log("open missing ABI symbols");
    dlclose(handle);
    return 1;
  }
  next.init();
  if (next.abi() != 1) {
    hot_log("open ABI mismatch");
    dlclose(handle);
    return 1;
  }
  if (next.create(config, config_len) != 0) {
    hot_log("open dev_create failed");
    dlclose(handle);
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
  char *plugin_path = hot_copy_string(path, path_len);
  if (plugin_path == NULL) {
    return 1;
  }
  void *handle = dlopen(plugin_path, RTLD_NOW | RTLD_LOCAL);
  free(plugin_path);
  if (handle == NULL) {
    if (hot_debug_enabled()) {
      const char *error = dlerror();
      fprintf(stderr, "moui-devhost: reload dlopen failed: %s\n",
              error != NULL ? error : "(no error)");
    }
    return 1;
  }
  hot_api next;
  if (hot_resolve(&next, handle) != 0) {
    hot_log("reload missing ABI symbols");
    dlclose(handle);
    return 1;
  }
  next.init();
  if (next.abi() != 1) {
    hot_log("reload ABI mismatch");
    dlclose(handle);
    return 1;
  }
  if (g_current.handle != NULL) {
    g_current.flush();
  }
  if (next.create(config, config_len) != 0) {
    hot_log("reload dev_create failed; keeping previous generation");
    dlclose(handle);
    return 1;
  }
  if (g_current.handle != NULL) {
    g_current.destroy();
    int close_rc = dlclose(g_current.handle);
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
  int close_rc = dlclose(g_current.handle);
  hot_log_close("shutdown", g_current.handle, close_rc);
  hot_clear_api(&g_current);
}

// Called after the plugin has flushed state and before the host is replaced.
// The dev runner sees the same process continue; only the window is recreated.
MOONBIT_FFI_EXPORT
void moui_devhost_reexec(void) {
  if (hot_debug_enabled()) {
    fprintf(stderr, "moui-devhost: re-exec after reload budget\n");
  }
  if (g_argc > 0 && g_argv != NULL && g_argv[0] != NULL) {
    execv(g_argv[0], g_argv);
  }
  _exit(75);
}
