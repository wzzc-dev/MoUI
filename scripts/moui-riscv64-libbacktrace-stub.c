/*
 * Minimal libbacktrace-compatible implementation for the MoUI Linux
 * RISC-V64 cross build.
 *
 * moon links the host-prebuilt ~/.moon/lib/libbacktrace.a into every
 * native executable; that archive is built for the host architecture
 * (x86_64) and cannot be linked into a riscv64 target ("incompatible
 * with elf64lriscv"). The moon runtime only calls backtrace_create_state
 * and backtrace_pcinfo, so provide those (plus the rest of the public
 * API) backed by _Unwind_Backtrace/dladdr, which are available in the
 * riscv64 sysroot.
 */
#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <unwind.h>
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

struct unwind_full_ctx {
  int skip;
  backtrace_full_callback callback;
  void *data;
};

static _Unwind_Reason_Code unwind_full_cb(struct _Unwind_Context *ctx,
                                          void *arg) {
  struct unwind_full_ctx *uc = (struct unwind_full_ctx *)arg;
  uintptr_t pc = (uintptr_t)_Unwind_GetIP(ctx);
  if (pc == 0) {
    return _URC_END_OF_STACK;
  }
  if (uc->skip > 0) {
    uc->skip--;
    return _URC_NO_REASON;
  }
  if (uc->callback(uc->data, pc, NULL, 0, NULL) != 0) {
    return _URC_END_OF_STACK;
  }
  return _URC_NO_REASON;
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
  struct unwind_full_ctx uc = {skip, callback, data};
  _Unwind_Backtrace(unwind_full_cb, &uc);
  return 1;
}

struct unwind_simple_ctx {
  int skip;
  backtrace_simple_callback callback;
  void *data;
};

static _Unwind_Reason_Code unwind_simple_cb(struct _Unwind_Context *ctx,
                                            void *arg) {
  struct unwind_simple_ctx *uc = (struct unwind_simple_ctx *)arg;
  uintptr_t pc = (uintptr_t)_Unwind_GetIP(ctx);
  if (pc == 0) {
    return _URC_END_OF_STACK;
  }
  if (uc->skip > 0) {
    uc->skip--;
    return _URC_NO_REASON;
  }
  if (uc->callback(uc->data, pc) != 0) {
    return _URC_END_OF_STACK;
  }
  return _URC_NO_REASON;
}

int backtrace_simple(struct backtrace_state *state, int skip,
                     backtrace_simple_callback callback,
                     backtrace_error_callback error_callback, void *data) {
  (void)state;
  if (callback == NULL) {
    report_error(error_callback, data, "no callback");
    return 0;
  }
  struct unwind_simple_ctx uc = {skip, callback, data};
  _Unwind_Backtrace(unwind_simple_cb, &uc);
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
