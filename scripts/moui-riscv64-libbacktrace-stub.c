/*
 * Minimal libbacktrace-compatible implementation for the MoUI Linux
 * RISC-V64 cross build.
 *
 * moon links the host-prebuilt ~/.moon/lib/libbacktrace.a into every
 * native executable; that archive is built for the host architecture
 * (x86_64) and cannot be linked into a riscv64 target ("incompatible
 * with elf64lriscv"). The moon runtime only calls backtrace_create_state
 * and backtrace_pcinfo, so provide those (plus the rest of the public
 * API) backed by glibc backtrace()/dladdr() from the target sysroot.
 */
#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <execinfo.h>
#include <dlfcn.h>

struct backtrace_state {
  int dummy;
};

struct backtrace_moredata {
  int backtrace_version;
  void *backtrace_data;
  unsigned int backtrace_discriminator;
};

typedef void (*backtrace_error_callback)(void *data, const char *msg,
                                         int errnum);
typedef int (*backtrace_full_callback)(void *data, uintptr_t pc,
                                       const char *filename, int lineno,
                                       const char *function);
typedef int (*backtrace_simple_callback)(void *data, uintptr_t pc);
typedef void (*backtrace_syminfo_callback)(void *data, uintptr_t pc,
                                           const char *symname,
                                           uintptr_t symval,
                                           uintptr_t symsize);

static struct backtrace_state g_state;

struct backtrace_state *backtrace_create_state(
    const char *filename, int flags,
    backtrace_error_callback error_callback, void *data) {
  (void)filename;
  (void)flags;
  (void)error_callback;
  (void)data;
  return &g_state;
}

static void report_error(backtrace_error_callback error_callback, void *data,
                         const char *msg) {
  if (error_callback != NULL) {
    error_callback(data, msg, -1);
  }
}

static int symbolize_pc(uintptr_t pc, backtrace_full_callback callback,
                        void *data) {
  Dl_info info;
  const char *filename = NULL;
  const char *function = NULL;
  int lineno = 0;
  if (dladdr((void *)pc, &info) != 0) {
    filename = info.dli_fname;
    function = info.dli_sname;
  }
  return callback(data, pc, filename, lineno, function);
}

int backtrace_pcinfo(struct backtrace_state *state, uintptr_t pc,
                     backtrace_full_callback callback,
                     backtrace_error_callback error_callback, void *data) {
  (void)state;
  if (callback == NULL) {
    report_error(error_callback, data, "no callback");
    return 0;
  }
  return symbolize_pc(pc, callback, data);
}

int backtrace_full(struct backtrace_state *state, int skip,
                   backtrace_full_callback callback,
                   backtrace_error_callback error_callback, void *data) {
  (void)state;
  if (callback == NULL) {
    report_error(error_callback, data, "no callback");
    return 0;
  }
  void *frames[128];
  int count = backtrace(frames, 128);
  for (int i = skip + 2; i < count; i++) {
    if (symbolize_pc((uintptr_t)frames[i], callback, data) != 0) {
      break;
    }
  }
  return 1;
}

int backtrace_simple(struct backtrace_state *state, int skip,
                     backtrace_simple_callback callback,
                     backtrace_error_callback error_callback, void *data) {
  (void)state;
  if (callback == NULL) {
    report_error(error_callback, data, "no callback");
    return 0;
  }
  void *frames[128];
  int count = backtrace(frames, 128);
  for (int i = skip + 2; i < count; i++) {
    if (callback(data, (uintptr_t)frames[i]) != 0) {
      break;
    }
  }
  return 1;
}

void backtrace_syminfo(struct backtrace_state *state, uintptr_t addr,
                       backtrace_syminfo_callback callback,
                       backtrace_error_callback error_callback, void *data) {
  (void)state;
  if (callback == NULL) {
    report_error(error_callback, data, "no callback");
    return;
  }
  Dl_info info;
  const char *symname = NULL;
  uintptr_t symval = 0;
  uintptr_t symsize = 0;
  if (dladdr((void *)addr, &info) != 0) {
    symname = info.dli_sname;
    symval = (uintptr_t)info.dli_saddr;
  }
  callback(data, addr, symname, symval, symsize);
}

void backtrace_close(struct backtrace_state *state,
                     backtrace_error_callback error_callback, void *data) {
  (void)state;
  (void)error_callback;
  (void)data;
}

void *backtrace_alloc(struct backtrace_state *state, size_t size,
                      backtrace_error_callback error_callback, void *data) {
  (void)state;
  (void)error_callback;
  (void)data;
  return malloc(size);
}

void backtrace_free(struct backtrace_state *state, void *mem, size_t size,
                    backtrace_error_callback error_callback, void *data) {
  (void)state;
  (void)size;
  (void)error_callback;
  (void)data;
  free(mem);
}
