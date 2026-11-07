/*
 * thread_pool.c calls posix_spawn_file_actions_addchdir_np, which Apple marks
 * unavailable on iOS. The hosted apps never spawn a process with a working
 * directory on iOS: remap the call to an ENOSYS stub (see
 * ios_stub_spawn_addchdir.c). Force-included via -include for the runtime
 * sources compiled by `moui build ios`.
 */
#ifndef MOUI_COMPAT_SPAWN_ADDCHDIR_H
#define MOUI_COMPAT_SPAWN_ADDCHDIR_H
#include <spawn.h>
int ios_stub_spawn_file_actions_addchdir(void *actions, const char *path);
#define posix_spawn_file_actions_addchdir_np ios_stub_spawn_file_actions_addchdir
#endif
