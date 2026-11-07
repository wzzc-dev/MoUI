/* iOS stub: spawning a process with a working directory is not permitted. */
#include <errno.h>
int ios_stub_spawn_file_actions_addchdir(void *actions, const char *path) {
  (void)actions;
  (void)path;
  return ENOSYS;
}
