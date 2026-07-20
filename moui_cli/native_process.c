#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <moonbit.h>

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <wchar.h>
#else
#include <fcntl.h>
#include <spawn.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#ifdef __APPLE__
#include <Availability.h>
#endif
#endif

#ifndef _WIN32
extern char **environ;
#endif

#ifdef _WIN32
static wchar_t *moui_cli_process_utf8_to_wide(const char *value) {
  int length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, NULL, 0);
  if (length <= 0) {
    return NULL;
  }
  wchar_t *wide = (wchar_t *)malloc((size_t)length * sizeof(wchar_t));
  if (wide == NULL) {
    return NULL;
  }
  if (MultiByteToWideChar(
          CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, wide, length) <= 0) {
    free(wide);
    return NULL;
  }
  return wide;
}
#endif

#ifndef _WIN32
static int moui_cli_process_spawn_addchdir(
    posix_spawn_file_actions_t *actions,
    const char *cwd) {
#if defined(__APPLE__) && defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && \
    __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
  return posix_spawn_file_actions_addchdir(actions, cwd);
#else
  return posix_spawn_file_actions_addchdir_np(actions, cwd);
#endif
}
#endif

/*
 * moui_cli_process_set_exit_code — write a 4-byte little-endian int32 into a
 * MoonBit Bytes buffer. Safe for unaligned buffers (uses memcpy).
 */
static void moui_cli_process_set_exit_code(
    moonbit_bytes_t buffer,
    int32_t value) {
  if (buffer != NULL) {
    memcpy(buffer, &value, sizeof(int32_t));
  }
}

/*
 * moui_cli_process_exec — run a child process with optional timeout, env
 * override, cwd override, and stdout/stderr redirection to files.
 *
 * Parameters:
 *   argv        MoonBit Array[Bytes] — each element is a nul-terminated C
 *               string. The first element is the executable (resolved via
 *               $PATH on POSIX, fully-qualified on Windows). Must contain at
 *               least one element.
 *   argc        Length of argv (must match MoonBit array length).
 *   env         MoonBit Array[Bytes] — each element is a nul-terminated
 *               "KEY=VALUE" string. If envc == 0, the child inherits the
 *               parent environment.
 *   envc        Length of env (must match MoonBit array length).
 *   cwd         Nul-terminated path; if the first byte is '\0', the child
 *               inherits the parent's working directory.
 *   stdout_path Nul-terminated path; if the first byte is '\0', the child
 *               inherits stdout (no redirection).
 *   stderr_path Nul-terminated path; if the first byte is '\0', the child
 *               inherits stderr (no redirection).
 *
 * stdin is always redirected to the null device so capture-mode children that
 * optionally read configuration from stdin (e.g. moui_skia/build.js via
 * fs.readFileSync(0)) do not hang waiting for a terminal that never closes.
 *   timeout_ms  Maximum runtime in milliseconds. 0 means no timeout.
 *   exit_code_buf
 *               MoonBit Bytes buffer of at least 4 bytes. When the return
 *               value is 0 or 1, the buffer is overwritten with the actual
 *               process exit code as a little-endian int32. On errors it is
 *               set to -1.
 *
 * Returns:
 *   0    Process exited normally with exit code 0.
 *   1    Process exited normally with non-zero code.
 *   101  Setup error (could not open output files or init spawn actions).
 *   102  Spawn error (posix_spawnp / CreateProcessW failed).
 *   103  Timeout — the process was killed after timeout_ms elapsed.
 */
MOONBIT_FFI_EXPORT int32_t moui_cli_process_exec(
    moonbit_bytes_t *argv,
    int32_t argc,
    moonbit_bytes_t *env,
    int32_t envc,
    moonbit_bytes_t cwd,
    moonbit_bytes_t stdout_path,
    moonbit_bytes_t stderr_path,
    int32_t timeout_ms,
    moonbit_bytes_t exit_code_buf) {
  moui_cli_process_set_exit_code(exit_code_buf, -1);
  if (argv == NULL || argc <= 0) {
    return 101;
  }
  for (int32_t i = 0; i < argc; ++i) {
    if (argv[i] == NULL) {
      return 101;
    }
  }

#ifdef _WIN32
  /* ----- Windows: CreateProcessW + STARTF_USESTDHANDLES ----- */
  wchar_t *executable_wide =
      moui_cli_process_utf8_to_wide((const char *)argv[0]);
  if (executable_wide == NULL) {
    return 101;
  }

  /* Build the command line: "exe" arg1 arg2 ... */
  size_t command_length = wcslen(executable_wide) + 3;
  for (int32_t i = 1; i < argc; ++i) {
    command_length += strlen((const char *)argv[i]) + 3;
  }
  wchar_t *command_line =
      (wchar_t *)calloc(command_length + 1, sizeof(wchar_t));
  if (command_line == NULL) {
    free(executable_wide);
    return 101;
  }
  wcscat(command_line, L"\"");
  wcscat(command_line, executable_wide);
  wcscat(command_line, L"\"");
  for (int32_t i = 1; i < argc; ++i) {
    wcscat(command_line, L" ");
    const char *arg = (const char *)argv[i];
    size_t arg_length = strlen(arg);
    wchar_t *wide_arg =
        (wchar_t *)calloc(arg_length + 1, sizeof(wchar_t));
    if (wide_arg == NULL) {
      free(command_line);
      free(executable_wide);
      return 101;
    }
    for (size_t j = 0; j < arg_length; ++j) {
      wide_arg[j] = (wchar_t)(unsigned char)arg[j];
    }
    wcscat(command_line, wide_arg);
    free(wide_arg);
  }

  /* Build env block if envc > 0 */
  wchar_t *env_block = NULL;
  if (envc > 0 && env != NULL) {
    size_t total = 1;
    for (int32_t i = 0; i < envc; ++i) {
      total += strlen((const char *)env[i]) + 1;
    }
    env_block = (wchar_t *)calloc(total + 1, sizeof(wchar_t));
    if (env_block == NULL) {
      free(command_line);
      free(executable_wide);
      return 101;
    }
    size_t offset = 0;
    for (int32_t i = 0; i < envc; ++i) {
      const char *entry = (const char *)env[i];
      size_t entry_length = strlen(entry);
      for (size_t j = 0; j < entry_length; ++j) {
        env_block[offset + j] = (wchar_t)(unsigned char)entry[j];
      }
      offset += entry_length;
      env_block[offset++] = L'\0';
    }
    env_block[offset] = L'\0';
  }

  /* Resolve cwd */
  wchar_t *cwd_wide = NULL;
  if (cwd != NULL && ((const char *)cwd)[0] != '\0') {
    cwd_wide = moui_cli_process_utf8_to_wide((const char *)cwd);
    if (cwd_wide == NULL) {
      free(env_block);
      free(command_line);
      free(executable_wide);
      return 101;
    }
  }

  /* Open stdout handle */
  SECURITY_ATTRIBUTES security;
  ZeroMemory(&security, sizeof(security));
  security.nLength = sizeof(security);
  security.bInheritHandle = TRUE;

  HANDLE stdout_handle = GetStdHandle(STD_OUTPUT_HANDLE);
  int own_stdout = 0;
  if (stdout_path != NULL && ((const char *)stdout_path)[0] != '\0') {
    wchar_t *stdout_wide =
        moui_cli_process_utf8_to_wide((const char *)stdout_path);
    if (stdout_wide == NULL) {
      free(cwd_wide);
      free(env_block);
      free(command_line);
      free(executable_wide);
      return 101;
    }
    stdout_handle = CreateFileW(
        stdout_wide,
        GENERIC_WRITE,
        FILE_SHARE_READ,
        &security,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        NULL);
    free(stdout_wide);
    if (stdout_handle == INVALID_HANDLE_VALUE) {
      free(cwd_wide);
      free(env_block);
      free(command_line);
      free(executable_wide);
      return 101;
    }
    own_stdout = 1;
  }

  /* Open stderr handle */
  HANDLE stderr_handle = GetStdHandle(STD_ERROR_HANDLE);
  int own_stderr = 0;
  if (stderr_path != NULL && ((const char *)stderr_path)[0] != '\0') {
    wchar_t *stderr_wide =
        moui_cli_process_utf8_to_wide((const char *)stderr_path);
    if (stderr_wide == NULL) {
      if (own_stdout) {
        CloseHandle(stdout_handle);
      }
      free(cwd_wide);
      free(env_block);
      free(command_line);
      free(executable_wide);
      return 101;
    }
    stderr_handle = CreateFileW(
        stderr_wide,
        GENERIC_WRITE,
        FILE_SHARE_READ,
        &security,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        NULL);
    free(stderr_wide);
    if (stderr_handle == INVALID_HANDLE_VALUE) {
      if (own_stdout) {
        CloseHandle(stdout_handle);
      }
      free(cwd_wide);
      free(env_block);
      free(command_line);
      free(executable_wide);
      return 101;
    }
    own_stderr = 1;
  }

  /* Always feed children an immediate EOF on stdin. Captured spawns redirect
   * stdout/stderr to files and otherwise inherit the parent's open stdin —
   * tools like moui_skia/build.js then block forever on read(0). */
  HANDLE stdin_handle = CreateFileW(
      L"NUL",
      GENERIC_READ,
      FILE_SHARE_READ,
      &security,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      NULL);
  if (stdin_handle == INVALID_HANDLE_VALUE) {
    if (own_stdout) {
      CloseHandle(stdout_handle);
    }
    if (own_stderr) {
      CloseHandle(stderr_handle);
    }
    free(cwd_wide);
    free(env_block);
    free(command_line);
    free(executable_wide);
    return 101;
  }

  STARTUPINFOW startup;
  PROCESS_INFORMATION process;
  ZeroMemory(&startup, sizeof(startup));
  ZeroMemory(&process, sizeof(process));
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = stdin_handle;
  startup.hStdOutput = stdout_handle;
  startup.hStdError = stderr_handle;

  BOOL created = CreateProcessW(
      executable_wide,
      command_line,
      NULL,
      NULL,
      TRUE,
      CREATE_NO_WINDOW,
      env_block,
      cwd_wide,
      &startup,
      &process);

  free(command_line);
  free(executable_wide);
  free(env_block);
  free(cwd_wide);
  CloseHandle(stdin_handle);

  if (!created) {
    if (own_stdout) {
      CloseHandle(stdout_handle);
    }
    if (own_stderr) {
      CloseHandle(stderr_handle);
    }
    return 102;
  }

  DWORD wait_result;
  if (timeout_ms > 0) {
    wait_result = WaitForSingleObject(process.hProcess, (DWORD)timeout_ms);
  } else {
    wait_result = WaitForSingleObject(process.hProcess, INFINITE);
  }

  int32_t return_status = 0;
  DWORD code = 1;
  if (wait_result == WAIT_TIMEOUT) {
    TerminateProcess(process.hProcess, 1);
    WaitForSingleObject(process.hProcess, 500);
    return_status = 103;
  } else {
    BOOL read_exit = GetExitCodeProcess(process.hProcess, &code);
    if (!read_exit) {
      return_status = 102;
    } else {
      moui_cli_process_set_exit_code(exit_code_buf, (int32_t)code);
      return_status = (code == 0) ? 0 : 1;
    }
  }

  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  if (own_stdout) {
    CloseHandle(stdout_handle);
  }
  if (own_stderr) {
    CloseHandle(stderr_handle);
  }
  return return_status;
#else
  /* ----- POSIX: posix_spawnp + waitpid ----- */
  posix_spawn_file_actions_t actions;
  if (posix_spawn_file_actions_init(&actions) != 0) {
    return 101;
  }

  int stdout_fd = -1;
  int stderr_fd = -1;
  int own_stdout_fd = 0;
  int own_stderr_fd = 0;

  /* Always give children an immediate EOF on stdin. Without this, capture-
   * mode spawns keep the parent's open stdin (often a TTY), and tools that
   * optionally parse JSON from fd 0 — notably moui_skia/build.js — hang after
   * moon build finishes and the CLI looks "stuck".
   *
   * Keep stdin_fd open until after posix_spawnp: adddup2 stores the fd number
   * and performs the dup at spawn time, so closing early makes spawn fail. */
  int stdin_fd = open("/dev/null", O_RDONLY);
  if (stdin_fd < 0) {
    posix_spawn_file_actions_destroy(&actions);
    return 101;
  }
  if (posix_spawn_file_actions_adddup2(
          &actions, stdin_fd, STDIN_FILENO) != 0) {
    close(stdin_fd);
    posix_spawn_file_actions_destroy(&actions);
    return 101;
  }

  if (stdout_path != NULL && ((const char *)stdout_path)[0] != '\0') {
    stdout_fd = open(
        (const char *)stdout_path,
        O_WRONLY | O_CREAT | O_TRUNC,
        S_IRUSR | S_IWUSR);
    if (stdout_fd < 0) {
      close(stdin_fd);
      posix_spawn_file_actions_destroy(&actions);
      return 101;
    }
    own_stdout_fd = 1;
    if (posix_spawn_file_actions_adddup2(
            &actions, stdout_fd, STDOUT_FILENO) != 0) {
      close(stdout_fd);
      close(stdin_fd);
      posix_spawn_file_actions_destroy(&actions);
      return 101;
    }
  }

  if (stderr_path != NULL && ((const char *)stderr_path)[0] != '\0') {
    stderr_fd = open(
        (const char *)stderr_path,
        O_WRONLY | O_CREAT | O_TRUNC,
        S_IRUSR | S_IWUSR);
    if (stderr_fd < 0) {
      if (own_stdout_fd) {
        close(stdout_fd);
      }
      close(stdin_fd);
      posix_spawn_file_actions_destroy(&actions);
      return 101;
    }
    own_stderr_fd = 1;
    if (posix_spawn_file_actions_adddup2(
            &actions, stderr_fd, STDERR_FILENO) != 0) {
      close(stderr_fd);
      if (own_stdout_fd) {
        close(stdout_fd);
      }
      close(stdin_fd);
      posix_spawn_file_actions_destroy(&actions);
      return 101;
    }
  }

  if (cwd != NULL && ((const char *)cwd)[0] != '\0') {
    if (moui_cli_process_spawn_addchdir(&actions, (const char *)cwd) != 0) {
      if (own_stderr_fd) {
        close(stderr_fd);
      }
      if (own_stdout_fd) {
        close(stdout_fd);
      }
      close(stdin_fd);
      posix_spawn_file_actions_destroy(&actions);
      return 101;
    }
  }

  /* Build argv array (NULL-terminated) */
  char **argv_c = (char **)calloc((size_t)argc + 1, sizeof(char *));
  if (argv_c == NULL) {
    if (own_stderr_fd) {
      close(stderr_fd);
    }
    if (own_stdout_fd) {
      close(stdout_fd);
    }
    close(stdin_fd);
    posix_spawn_file_actions_destroy(&actions);
    return 101;
  }
  for (int32_t i = 0; i < argc; ++i) {
    argv_c[i] = (char *)argv[i];
  }
  argv_c[argc] = NULL;

  /* Build env array if envc > 0; otherwise pass environ to inherit */
  char **env_c = environ;
  char **env_alloc = NULL;
  if (envc > 0 && env != NULL) {
    env_alloc = (char **)calloc((size_t)envc + 1, sizeof(char *));
    if (env_alloc == NULL) {
      free(argv_c);
      if (own_stderr_fd) {
        close(stderr_fd);
      }
      if (own_stdout_fd) {
        close(stdout_fd);
      }
      close(stdin_fd);
      posix_spawn_file_actions_destroy(&actions);
      return 101;
    }
    for (int32_t i = 0; i < envc; ++i) {
      env_alloc[i] = (char *)env[i];
    }
    env_alloc[envc] = NULL;
    env_c = env_alloc;
  }

  pid_t child = 0;
  int spawn_status = posix_spawnp(
      &child, argv_c[0], &actions, NULL, argv_c, env_c);

  free(argv_c);
  free(env_alloc);
  posix_spawn_file_actions_destroy(&actions);
  if (own_stdout_fd) {
    close(stdout_fd);
  }
  if (own_stderr_fd) {
    close(stderr_fd);
  }
  close(stdin_fd);

  if (spawn_status != 0) {
    return 102;
  }

  int status = 0;
  int32_t return_status = 0;

  if (timeout_ms <= 0) {
    /* No timeout — wait until the child exits */
    while (waitpid(child, &status, 0) < 0) {
      if (errno != EINTR) {
        kill(child, SIGKILL);
        waitpid(child, NULL, 0);
        return 102;
      }
    }
  } else {
    /* Poll with WNOHANG until timeout */
    int32_t elapsed_ms = 0;
    const int32_t poll_interval_ms = 10;
    int settled = 0;
    while (elapsed_ms < timeout_ms) {
      pid_t result = waitpid(child, &status, WNOHANG);
      if (result == child) {
        settled = 1;
        break;
      }
      if (result < 0) {
        if (errno == EINTR) {
          continue;
        }
        kill(child, SIGKILL);
        waitpid(child, NULL, 0);
        return 102;
      }
      usleep(poll_interval_ms * 1000);
      elapsed_ms += poll_interval_ms;
    }
    if (!settled) {
      /* Timeout — send SIGTERM, wait 200ms, then SIGKILL */
      kill(child, SIGTERM);
      int32_t sigterm_elapsed = 0;
      while (sigterm_elapsed < 200) {
        pid_t r2 = waitpid(child, &status, WNOHANG);
        if (r2 == child) {
          settled = 1;
          break;
        }
        if (r2 < 0 && errno != EINTR) {
          break;
        }
        usleep(10 * 1000);
        sigterm_elapsed += 10;
      }
      if (!settled) {
        kill(child, SIGKILL);
        while (waitpid(child, &status, 0) < 0) {
          if (errno != EINTR) {
            break;
          }
        }
      }
      return 103;
    }
  }

  /* Process exited — extract exit code */
  if (WIFEXITED(status)) {
    int code = WEXITSTATUS(status);
    moui_cli_process_set_exit_code(exit_code_buf, code);
    return_status = (code == 0) ? 0 : 1;
  } else if (WIFSIGNALED(status)) {
    moui_cli_process_set_exit_code(exit_code_buf, -WTERMSIG(status));
    return_status = 1;
  } else {
    return_status = 1;
  }
  return return_status;
#endif
}
