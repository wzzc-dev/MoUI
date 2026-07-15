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
#include <dirent.h>
#include <fcntl.h>
#include <spawn.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#ifdef __APPLE__
#include <Availability.h>
#endif
#endif

#ifndef _WIN32
extern char **environ;
#endif

#ifdef __linux__
#include <fcntl.h>
#include <sys/syscall.h>
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif
#endif

#ifdef _WIN32
static wchar_t *moui_cli_utf8_to_wide(const char *value) {
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

static int32_t moui_cli_move_path_windows(
    moonbit_bytes_t source,
    moonbit_bytes_t destination,
    DWORD flags) {
  wchar_t *source_wide = moui_cli_utf8_to_wide((const char *)source);
  wchar_t *destination_wide =
      moui_cli_utf8_to_wide((const char *)destination);
  if (source_wide == NULL || destination_wide == NULL) {
    free(source_wide);
    free(destination_wide);
    return -1;
  }
  BOOL moved = MoveFileExW(source_wide, destination_wide, flags);
  free(source_wide);
  free(destination_wide);
  return moved ? 0 : -1;
}

static int32_t moui_cli_remove_tree_windows(const wchar_t *path) {
  DWORD attributes = GetFileAttributesW(path);
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    return GetLastError() == ERROR_FILE_NOT_FOUND ||
                   GetLastError() == ERROR_PATH_NOT_FOUND
               ? 0
               : -1;
  }
  if ((attributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
    if ((attributes & FILE_ATTRIBUTE_READONLY) != 0) {
      SetFileAttributesW(path, attributes & ~FILE_ATTRIBUTE_READONLY);
    }
    return DeleteFileW(path) ? 0 : -1;
  }
  if ((attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    return RemoveDirectoryW(path) ? 0 : -1;
  }

  size_t length = wcslen(path);
  wchar_t *pattern =
      (wchar_t *)malloc((length + 3) * sizeof(wchar_t));
  if (pattern == NULL) {
    return -1;
  }
  memcpy(pattern, path, length * sizeof(wchar_t));
  pattern[length] = L'\\';
  pattern[length + 1] = L'*';
  pattern[length + 2] = L'\0';
  WIN32_FIND_DATAW entry;
  HANDLE search = FindFirstFileW(pattern, &entry);
  free(pattern);
  if (search != INVALID_HANDLE_VALUE) {
    do {
      if (wcscmp(entry.cFileName, L".") == 0 ||
          wcscmp(entry.cFileName, L"..") == 0) {
        continue;
      }
      size_t name_length = wcslen(entry.cFileName);
      wchar_t *child = (wchar_t *)malloc(
          (length + name_length + 2) * sizeof(wchar_t));
      if (child == NULL) {
        FindClose(search);
        return -1;
      }
      memcpy(child, path, length * sizeof(wchar_t));
      child[length] = L'\\';
      memcpy(
          child + length + 1,
          entry.cFileName,
          (name_length + 1) * sizeof(wchar_t));
      int32_t status = moui_cli_remove_tree_windows(child);
      free(child);
      if (status != 0) {
        FindClose(search);
        return status;
      }
    } while (FindNextFileW(search, &entry));
    FindClose(search);
  } else if (GetLastError() != ERROR_FILE_NOT_FOUND) {
    return -1;
  }
  return RemoveDirectoryW(path) ? 0 : -1;
}

static wchar_t *moui_cli_final_path_windows(const wchar_t *path) {
  HANDLE handle = CreateFileW(
      path,
      0,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
      NULL,
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS,
      NULL);
  if (handle == INVALID_HANDLE_VALUE) {
    return NULL;
  }
  DWORD length = GetFinalPathNameByHandleW(
      handle, NULL, 0, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
  if (length == 0) {
    CloseHandle(handle);
    return NULL;
  }
  wchar_t *result = (wchar_t *)malloc((length + 1) * sizeof(wchar_t));
  if (result == NULL) {
    CloseHandle(handle);
    return NULL;
  }
  DWORD written = GetFinalPathNameByHandleW(
      handle,
      result,
      length + 1,
      FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
  CloseHandle(handle);
  if (written == 0 || written > length) {
    free(result);
    return NULL;
  }
  return result;
}
#else
static int32_t moui_cli_remove_tree_posix(const char *path) {
  struct stat status;
  if (lstat(path, &status) != 0) {
    return errno == ENOENT ? 0 : -1;
  }
  if (!S_ISDIR(status.st_mode) || S_ISLNK(status.st_mode)) {
    return unlink(path) == 0 ? 0 : -1;
  }
  DIR *directory = opendir(path);
  if (directory == NULL) {
    return -1;
  }
  struct dirent *entry = NULL;
  while ((entry = readdir(directory)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 ||
        strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    size_t path_length = strlen(path);
    size_t name_length = strlen(entry->d_name);
    char *child = (char *)malloc(path_length + name_length + 2);
    if (child == NULL) {
      closedir(directory);
      return -1;
    }
    memcpy(child, path, path_length);
    child[path_length] = '/';
    memcpy(child + path_length + 1, entry->d_name, name_length + 1);
    int32_t child_status = moui_cli_remove_tree_posix(child);
    free(child);
    if (child_status != 0) {
      closedir(directory);
      return child_status;
    }
  }
  closedir(directory);
  return rmdir(path) == 0 ? 0 : -1;
}
#endif

MOONBIT_FFI_EXPORT int32_t moui_cli_rename_path(
    moonbit_bytes_t source,
    moonbit_bytes_t destination) {
#ifdef _WIN32
  return moui_cli_move_path_windows(
      source, destination, MOVEFILE_WRITE_THROUGH);
#elif defined(__APPLE__)
  return renamex_np(
      (const char *)source, (const char *)destination, RENAME_EXCL);
#elif defined(__linux__) && defined(SYS_renameat2)
  return (int32_t)syscall(
      SYS_renameat2,
      AT_FDCWD,
      (const char *)source,
      AT_FDCWD,
      (const char *)destination,
      RENAME_NOREPLACE);
#else
  struct stat status;
  if (lstat((const char *)destination, &status) == 0) {
    errno = EEXIST;
    return -1;
  }
  if (errno != ENOENT) {
    return -1;
  }
  return rename((const char *)source, (const char *)destination);
#endif
}

MOONBIT_FFI_EXPORT int32_t moui_cli_replace_path(
    moonbit_bytes_t source,
    moonbit_bytes_t destination) {
#ifdef _WIN32
  return moui_cli_move_path_windows(
      source,
      destination,
      MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
#else
  return rename((const char *)source, (const char *)destination);
#endif
}

MOONBIT_FFI_EXPORT int32_t moui_cli_path_is_executable(
    moonbit_bytes_t path) {
#ifdef _WIN32
  wchar_t *path_wide = moui_cli_utf8_to_wide((const char *)path);
  if (path_wide == NULL) {
    return 0;
  }
  DWORD attributes = GetFileAttributesW(path_wide);
  free(path_wide);
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
#else
  return access((const char *)path, X_OK) == 0;
#endif
}

MOONBIT_FFI_EXPORT int32_t moui_cli_remove_tree(moonbit_bytes_t path) {
#ifdef _WIN32
  wchar_t *path_wide = moui_cli_utf8_to_wide((const char *)path);
  if (path_wide == NULL) {
    return -1;
  }
  int32_t status = moui_cli_remove_tree_windows(path_wide);
  free(path_wide);
  return status;
#else
  return moui_cli_remove_tree_posix((const char *)path);
#endif
}

MOONBIT_FFI_EXPORT int32_t moui_cli_path_is_symlink(moonbit_bytes_t path) {
#ifdef _WIN32
  wchar_t *path_wide = moui_cli_utf8_to_wide((const char *)path);
  if (path_wide == NULL) {
    return 0;
  }
  DWORD attributes = GetFileAttributesW(path_wide);
  free(path_wide);
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
#else
  struct stat status;
  return lstat((const char *)path, &status) == 0 && S_ISLNK(status.st_mode);
#endif
}

MOONBIT_FFI_EXPORT int32_t moui_cli_path_resolves_within(
    moonbit_bytes_t root,
    moonbit_bytes_t candidate) {
#ifdef _WIN32
  wchar_t *root_wide = moui_cli_utf8_to_wide((const char *)root);
  wchar_t *candidate_wide =
      moui_cli_utf8_to_wide((const char *)candidate);
  if (root_wide == NULL || candidate_wide == NULL) {
    free(root_wide);
    free(candidate_wide);
    return 0;
  }
  wchar_t *root_final = moui_cli_final_path_windows(root_wide);
  wchar_t *candidate_final = moui_cli_final_path_windows(candidate_wide);
  free(root_wide);
  free(candidate_wide);
  if (root_final == NULL || candidate_final == NULL) {
    free(root_final);
    free(candidate_final);
    return 0;
  }
  size_t root_length = wcslen(root_final);
  int inside = _wcsnicmp(root_final, candidate_final, root_length) == 0 &&
               (candidate_final[root_length] == L'\0' ||
                candidate_final[root_length] == L'\\' ||
                candidate_final[root_length] == L'/');
  free(root_final);
  free(candidate_final);
  return inside ? 1 : 0;
#else
  char *root_final = realpath((const char *)root, NULL);
  char *candidate_final = realpath((const char *)candidate, NULL);
  if (root_final == NULL || candidate_final == NULL) {
    free(root_final);
    free(candidate_final);
    return 0;
  }
  size_t root_length = strlen(root_final);
  int inside = strncmp(root_final, candidate_final, root_length) == 0 &&
               (candidate_final[root_length] == '\0' ||
                candidate_final[root_length] == '/');
  free(root_final);
  free(candidate_final);
  return inside ? 1 : 0;
#endif
}

static int32_t moui_cli_doctor_probe_arguments(
    int32_t kind,
    const char **arguments,
    int32_t capacity) {
  if (capacity < 5) {
    return -1;
  }
  switch (kind) {
    case 1:
      arguments[0] = "-version";
      return 1;
    case 2:
      arguments[0] = "--version";
      return 1;
    case 3:
      arguments[0] = "swiftc";
      arguments[1] = "--version";
      return 2;
    case 4:
      arguments[0] = "--exists";
      arguments[1] = "wayland-client";
      arguments[2] = "wayland-cursor";
      arguments[3] = "wayland-protocols";
      return 4;
    case 5:
      arguments[0] = "-p";
      return 1;
    default:
      return -1;
  }
}

#ifdef _WIN32
static wchar_t *moui_cli_doctor_probe_command(
    const wchar_t *executable,
    const char **arguments,
    int32_t argument_count) {
  size_t length = wcslen(executable) + 3;
  for (int32_t index = 0; index < argument_count; ++index) {
    length += strlen(arguments[index]) + 1;
  }
  wchar_t *command = (wchar_t *)calloc(length + 1, sizeof(wchar_t));
  if (command == NULL) {
    return NULL;
  }
  wcscat(command, L"\"");
  wcscat(command, executable);
  wcscat(command, L"\"");
  for (int32_t index = 0; index < argument_count; ++index) {
    size_t argument_length = strlen(arguments[index]);
    wchar_t *wide = (wchar_t *)calloc(argument_length + 1, sizeof(wchar_t));
    if (wide == NULL) {
      free(command);
      return NULL;
    }
    for (size_t unit = 0; unit < argument_length; ++unit) {
      wide[unit] = (wchar_t)(unsigned char)arguments[index][unit];
    }
    wcscat(command, L" ");
    wcscat(command, wide);
    free(wide);
  }
  return command;
}
#endif

/*
 * Runs one fixed, read-only doctor probe without a command shell. Returns 0
 * for success, 1 for a non-zero tool exit, and 101/102 for setup/spawn errors.
 */
MOONBIT_FFI_EXPORT int32_t moui_cli_run_doctor_probe(
    moonbit_bytes_t executable,
    moonbit_bytes_t output_path,
    int32_t kind) {
  const char *arguments[5] = {NULL, NULL, NULL, NULL, NULL};
  int32_t argument_count =
      moui_cli_doctor_probe_arguments(kind, arguments, 5);
  if (argument_count < 0) {
    return 101;
  }
#ifdef _WIN32
  wchar_t *executable_wide =
      moui_cli_utf8_to_wide((const char *)executable);
  wchar_t *output_wide = moui_cli_utf8_to_wide((const char *)output_path);
  if (executable_wide == NULL || output_wide == NULL) {
    free(executable_wide);
    free(output_wide);
    return 101;
  }
  SECURITY_ATTRIBUTES security;
  ZeroMemory(&security, sizeof(security));
  security.nLength = sizeof(security);
  security.bInheritHandle = TRUE;
  HANDLE output_handle = CreateFileW(
      output_wide,
      GENERIC_WRITE,
      FILE_SHARE_READ,
      &security,
      CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL,
      NULL);
  free(output_wide);
  if (output_handle == INVALID_HANDLE_VALUE) {
    free(executable_wide);
    return 101;
  }
  wchar_t *command = moui_cli_doctor_probe_command(
      executable_wide, arguments, argument_count);
  if (command == NULL) {
    CloseHandle(output_handle);
    free(executable_wide);
    return 101;
  }
  STARTUPINFOW startup;
  PROCESS_INFORMATION process;
  ZeroMemory(&startup, sizeof(startup));
  ZeroMemory(&process, sizeof(process));
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = output_handle;
  startup.hStdError = output_handle;
  BOOL created = CreateProcessW(
      executable_wide,
      command,
      NULL,
      NULL,
      TRUE,
      CREATE_NO_WINDOW,
      NULL,
      NULL,
      &startup,
      &process);
  free(command);
  free(executable_wide);
  if (!created) {
    CloseHandle(output_handle);
    return 102;
  }
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD exit_code = 1;
  BOOL read_exit = GetExitCodeProcess(process.hProcess, &exit_code);
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  CloseHandle(output_handle);
  return read_exit && exit_code == 0 ? 0 : 1;
#else
  int output_fd = open(
      (const char *)output_path,
      O_WRONLY | O_CREAT | O_TRUNC,
      S_IRUSR | S_IWUSR);
  if (output_fd < 0) {
    return 101;
  }
  posix_spawn_file_actions_t actions;
  if (posix_spawn_file_actions_init(&actions) != 0) {
    close(output_fd);
    return 101;
  }
  if (posix_spawn_file_actions_adddup2(
          &actions, output_fd, STDOUT_FILENO) != 0 ||
      posix_spawn_file_actions_adddup2(
          &actions, output_fd, STDERR_FILENO) != 0) {
    posix_spawn_file_actions_destroy(&actions);
    close(output_fd);
    return 101;
  }
  char *argv[7] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL};
  argv[0] = (char *)executable;
  for (int32_t index = 0; index < argument_count; ++index) {
    argv[index + 1] = (char *)arguments[index];
  }
  pid_t child = 0;
  int spawn_status = posix_spawnp(
      &child, (const char *)executable, &actions, NULL, argv, environ);
  posix_spawn_file_actions_destroy(&actions);
  close(output_fd);
  if (spawn_status != 0) {
    return 102;
  }
  int status = 0;
  while (waitpid(child, &status, 0) < 0) {
    if (errno != EINTR) {
      return 102;
    }
  }
  return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : 1;
#endif
}

#ifdef _WIN32
static int32_t moui_cli_run_validation_command_windows(
    const wchar_t *cwd,
    HANDLE log_handle,
    const wchar_t *command) {
  size_t command_length = wcslen(command) + 1;
  wchar_t *mutable_command =
      (wchar_t *)malloc(command_length * sizeof(wchar_t));
  if (mutable_command == NULL) {
    return -1;
  }
  memcpy(mutable_command, command, command_length * sizeof(wchar_t));

  STARTUPINFOW startup;
  PROCESS_INFORMATION process;
  ZeroMemory(&startup, sizeof(startup));
  ZeroMemory(&process, sizeof(process));
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = log_handle;
  startup.hStdError = log_handle;
  BOOL created = CreateProcessW(
      NULL,
      mutable_command,
      NULL,
      NULL,
      TRUE,
      CREATE_NO_WINDOW,
      NULL,
      cwd,
      &startup,
      &process);
  free(mutable_command);
  if (!created) {
    return -1;
  }
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD exit_code = 1;
  BOOL read_exit = GetExitCodeProcess(process.hProcess, &exit_code);
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return read_exit && exit_code == 0 ? 0 : 1;
}
#else
static int moui_cli_spawn_addchdir(
    posix_spawn_file_actions_t *actions,
    const char *cwd) {
#if defined(__APPLE__) && defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && \
    __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
  return posix_spawn_file_actions_addchdir(actions, cwd);
#else
  return posix_spawn_file_actions_addchdir_np(actions, cwd);
#endif
}

static int32_t moui_cli_run_validation_command_posix(
    const char *cwd,
    int log_fd,
    char *const argv[]) {
  posix_spawn_file_actions_t actions;
  if (posix_spawn_file_actions_init(&actions) != 0) {
    return -1;
  }
  if (posix_spawn_file_actions_adddup2(&actions, log_fd, STDOUT_FILENO) != 0 ||
      posix_spawn_file_actions_adddup2(&actions, log_fd, STDERR_FILENO) != 0 ||
      moui_cli_spawn_addchdir(&actions, cwd) != 0) {
    posix_spawn_file_actions_destroy(&actions);
    return -1;
  }
  pid_t child = 0;
  int spawn_status = posix_spawnp(
      &child, argv[0], &actions, NULL, argv, environ);
  posix_spawn_file_actions_destroy(&actions);
  if (spawn_status != 0) {
    dprintf(log_fd, "could not start moon validation command: %s\n", strerror(spawn_status));
    return -1;
  }
  int status = 0;
  while (waitpid(child, &status, 0) < 0) {
    if (errno != EINTR) {
      return -1;
    }
  }
  if (!(WIFEXITED(status) && WEXITSTATUS(status) == 0)) {
    if (WIFEXITED(status)) {
      dprintf(log_fd, "moon validation command exited with code %d\n", WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
      dprintf(log_fd, "moon validation command terminated by signal %d\n", WTERMSIG(status));
    }
  }
  return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : 1;
}
#endif

/*
 * Returns 0 on success, 1..3 for the failed validation stage, and 101..103
 * when the corresponding process could not be started.
 */
MOONBIT_FFI_EXPORT int32_t moui_cli_validate_generated_project(
    moonbit_bytes_t cwd,
    moonbit_bytes_t log_path) {
#ifdef _WIN32
  wchar_t *cwd_wide = moui_cli_utf8_to_wide((const char *)cwd);
  wchar_t *log_wide = moui_cli_utf8_to_wide((const char *)log_path);
  if (cwd_wide == NULL || log_wide == NULL) {
    free(cwd_wide);
    free(log_wide);
    return 101;
  }
  SECURITY_ATTRIBUTES security;
  ZeroMemory(&security, sizeof(security));
  security.nLength = sizeof(security);
  security.bInheritHandle = TRUE;
  HANDLE log_handle = CreateFileW(
      log_wide,
      GENERIC_WRITE,
      FILE_SHARE_READ,
      &security,
      CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL,
      NULL);
  free(log_wide);
  if (log_handle == INVALID_HANDLE_VALUE) {
    free(cwd_wide);
    return 101;
  }

  DWORD previous_length =
      GetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", NULL, 0);
  wchar_t *previous = NULL;
  if (previous_length > 0) {
    previous = (wchar_t *)malloc(previous_length * sizeof(wchar_t));
    if (previous != NULL) {
      GetEnvironmentVariableW(
          L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", previous, previous_length);
    }
  }
  SetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", L"1");

  const wchar_t *commands[] = {
      L"moon update",
      L"moon check --target all --warn-list +73",
      L"moon info --target all",
  };
  int32_t result = 0;
  for (int32_t index = 0; index < 3; ++index) {
    int32_t status = moui_cli_run_validation_command_windows(
        cwd_wide, log_handle, commands[index]);
    if (status != 0) {
      result = status < 0 ? 101 + index : 1 + index;
      break;
    }
  }

  if (previous != NULL) {
    SetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", previous);
  } else {
    SetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", NULL);
  }
  free(previous);
  CloseHandle(log_handle);
  free(cwd_wide);
  return result;
#else
  int log_fd = open(
      (const char *)log_path,
      O_WRONLY | O_CREAT | O_TRUNC,
      S_IRUSR | S_IWUSR);
  if (log_fd < 0) {
    return 101;
  }
  const char *previous_env = getenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA");
  char *previous = previous_env == NULL ? NULL : strdup(previous_env);
  setenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA", "1", 1);
  char *update[] = {(char *)"moon", (char *)"update", NULL};
  char *check[] = {
      (char *)"moon",
      (char *)"check",
      (char *)"--target",
      (char *)"all",
      (char *)"--warn-list",
      (char *)"+73",
      NULL,
  };
  char *info[] = {
      (char *)"moon", (char *)"info", (char *)"--target", (char *)"all", NULL};
  char **commands[] = {update, check, info};
  int32_t result = 0;
  for (int32_t index = 0; index < 3; ++index) {
    int32_t status = moui_cli_run_validation_command_posix(
        (const char *)cwd, log_fd, commands[index]);
    if (status != 0) {
      result = status < 0 ? 101 + index : 1 + index;
      break;
    }
  }
  if (previous != NULL) {
    setenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA", previous, 1);
  } else {
    unsetenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA");
  }
  free(previous);
  close(log_fd);
  return result;
#endif
}

MOONBIT_FFI_EXPORT int32_t moui_cli_validate_generated_project_stage(
    moonbit_bytes_t cwd,
    moonbit_bytes_t log_path,
    int32_t stage,
    int32_t append) {
  if (stage < 1 || stage > 3) {
    return 100;
  }
#ifdef _WIN32
  wchar_t *cwd_wide = moui_cli_utf8_to_wide((const char *)cwd);
  wchar_t *log_wide = moui_cli_utf8_to_wide((const char *)log_path);
  if (cwd_wide == NULL || log_wide == NULL) {
    free(cwd_wide);
    free(log_wide);
    return 100 + stage;
  }
  SECURITY_ATTRIBUTES security;
  ZeroMemory(&security, sizeof(security));
  security.nLength = sizeof(security);
  security.bInheritHandle = TRUE;
  HANDLE log_handle = CreateFileW(
      log_wide,
      GENERIC_WRITE,
      FILE_SHARE_READ,
      &security,
      append ? OPEN_ALWAYS : CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL,
      NULL);
  free(log_wide);
  if (log_handle == INVALID_HANDLE_VALUE) {
    free(cwd_wide);
    return 100 + stage;
  }
  if (append) {
    SetFilePointer(log_handle, 0, NULL, FILE_END);
  }
  DWORD previous_length =
      GetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", NULL, 0);
  wchar_t *previous = NULL;
  if (previous_length > 0) {
    previous = (wchar_t *)malloc(previous_length * sizeof(wchar_t));
    if (previous != NULL) {
      GetEnvironmentVariableW(
          L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", previous, previous_length);
    }
  }
  SetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", L"1");
  const wchar_t *commands[] = {
      L"moon update",
      L"moon check --target all --warn-list +73",
      L"moon info --target all",
  };
  int32_t status = moui_cli_run_validation_command_windows(
      cwd_wide, log_handle, commands[stage - 1]);
  if (previous != NULL) {
    SetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", previous);
  } else {
    SetEnvironmentVariableW(L"MOUI_SKIA_DISABLE_PREBUILD_SKIA", NULL);
  }
  free(previous);
  CloseHandle(log_handle);
  free(cwd_wide);
  return status == 0 ? 0 : (status < 0 ? 100 + stage : stage);
#else
  int flags = O_WRONLY | O_CREAT | (append ? O_APPEND : O_TRUNC);
  int log_fd = open((const char *)log_path, flags, S_IRUSR | S_IWUSR);
  if (log_fd < 0) {
    return 100 + stage;
  }
  const char *previous_env = getenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA");
  char *previous = previous_env == NULL ? NULL : strdup(previous_env);
  setenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA", "1", 1);
  char *update[] = {(char *)"moon", (char *)"update", NULL};
  char *check[] = {
      (char *)"moon",
      (char *)"check",
      (char *)"--target",
      (char *)"all",
      (char *)"--warn-list",
      (char *)"+73",
      NULL,
  };
  char *info[] = {
      (char *)"moon", (char *)"info", (char *)"--target", (char *)"all", NULL};
  char **commands[] = {update, check, info};
  int32_t status = moui_cli_run_validation_command_posix(
      (const char *)cwd, log_fd, commands[stage - 1]);
  if (previous != NULL) {
    setenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA", previous, 1);
  } else {
    unsetenv("MOUI_SKIA_DISABLE_PREBUILD_SKIA");
  }
  free(previous);
  close(log_fd);
  return status == 0 ? 0 : (status < 0 ? 100 + stage : stage);
#endif
}
