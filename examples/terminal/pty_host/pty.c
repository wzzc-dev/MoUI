/*
 * PTY 宿主 C 桥:openpty + posix_spawn 派生 shell,提供 master fd / resize ioctl。
 * 使用 posix_spawn 而非 forkpty:MoonBit async 运行时是多线程的,
 * fork 后子进程 exec 可能因线程池持有的锁而崩溃(SIGSEGV)。
 * 仅供 macOS/Linux(Unix) 使用。
 */
#ifndef _WIN32

#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <spawn.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <errno.h>

extern char **environ;

/* 部分 SDK 的 spawn.h 未定义该宏;缺失时降级为仅 SETSID。 */
#ifndef POSIX_SPAWN_CLOEXEC_DEFAULT
#define POSIX_SPAWN_CLOEXEC_DEFAULT 0
#endif

/* openpty 声明:macOS/Linux 头文件位置不统一,手动声明。 */
extern int openpty(int *amaster, int *aslave, char *name,
                   const struct termios *termp, const struct winsize *winp);

/*
 * 派生一个运行 shell 的 PTY 会话。
 * 返回 Int64:低 32 位 = master fd,高 32 位 = 子进程 pid;失败返回 -1。
 */
int64_t moonpty_spawn(unsigned char *shell, int64_t shell_len, int64_t cols,
                      int64_t rows) {
  struct winsize ws;
  char *cmd;
  char *argv[2];
  pid_t pid = -1;
  int master = -1;
  int slave = -1;
  int rc;

  ws.ws_row = (unsigned short)rows;
  ws.ws_col = (unsigned short)cols;
  ws.ws_xpixel = 0;
  ws.ws_ypixel = 0;

  cmd = (char *)malloc((size_t)shell_len + 1);
  if (cmd == NULL) {
    return -1;
  }
  memcpy(cmd, shell, (size_t)shell_len);
  cmd[shell_len] = '\0';
  if (openpty(&master, &slave, NULL, NULL, &ws) < 0) {
    free(cmd);
    return -1;
  }
  /* openpty 在 macOS 不设置 CLOEXEC;避免后台子进程继承 master。 */
  fcntl(master, F_SETFD, FD_CLOEXEC);

  posix_spawn_file_actions_t actions;
  posix_spawnattr_t attr;
  if (posix_spawn_file_actions_init(&actions) != 0) {
    close(master);
    close(slave);
    free(cmd);
    return -1;
  }
  if (posix_spawnattr_init(&attr) != 0) {
    posix_spawn_file_actions_destroy(&actions);
    close(master);
    close(slave);
    free(cmd);
    return -1;
  }
  rc = posix_spawn_file_actions_adddup2(&actions, slave, 0);
  if (rc == 0) {
    rc = posix_spawn_file_actions_adddup2(&actions, slave, 1);
  }
  if (rc == 0) {
    rc = posix_spawn_file_actions_adddup2(&actions, slave, 2);
  }
  /* slave 落在 0-2 时(宿主 stdio 已关闭)不 close,避免误关子进程 stdio */
  if (rc == 0 && slave > 2) {
    rc = posix_spawn_file_actions_addclose(&actions, slave);
  }
  /* stdio 重定向动作失败时清理并放弃派生 */
  if (rc != 0) {
    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attr);
    close(master);
    close(slave);
    free(cmd);
    return -1;
  }
  /* 让子进程成为新会话首进程,并关闭所有继承的宿主 fd(CLOEXEC_DEFAULT)。 */
  if (posix_spawnattr_setflags(
        &attr,
        POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT) != 0) {
    posix_spawn_file_actions_destroy(&actions);
    posix_spawnattr_destroy(&attr);
    close(master);
    close(slave);
    free(cmd);
    return -1;
  }

  argv[0] = cmd;
  argv[1] = NULL;
  rc = posix_spawn(&pid, cmd, &actions, &attr, argv, environ);
  posix_spawn_file_actions_destroy(&actions);
  posix_spawnattr_destroy(&attr);
  close(slave);
  free(cmd);
  if (rc != 0) {
    close(master);
    return -1;
  }
  return ((int64_t)pid << 32) | (uint32_t)master;
}

/*
 * 调整 PTY 窗口尺寸。
 */
int64_t moonpty_resize(int64_t fd, int64_t cols, int64_t rows) {
  struct winsize ws;
  ws.ws_row = (unsigned short)rows;
  ws.ws_col = (unsigned short)cols;
  ws.ws_xpixel = 0;
  ws.ws_ypixel = 0;
  return ioctl((int)fd, TIOCSWINSZ, &ws);
}

/*
 * 非阻塞回收子进程:返回 0=仍存活,>0=已回收子进程 pid,-1=无此子进程。
 * (返回 pid 而非 wait status,避免退出码 0 与"仍存活"混淆。)
 */
int64_t moonpty_reap(int64_t pid) {
  int status = 0;
  pid_t r = waitpid((pid_t)pid, &status, WNOHANG);
  if (r == 0) {
    return 0;
  }
  if (r < 0) {
    return -1;
  }
  return (int64_t)r;
}

/*
 * 向子进程发送信号(SIGHUP=1 等)。
 */
int64_t moonpty_signal(int64_t pid, int64_t sig) {
  return kill((pid_t)pid, (int)sig);
}

#endif /* _WIN32 */
