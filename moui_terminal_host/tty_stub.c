/*
 * 终端宿主 C 桥:当前 tty 的 raw mode、尺寸、读写与信号。
 *
 * 边界:C 只描述 fd 上的事实(termios / TIOCGWINSZ / poll / read / write /
 * 信号标记),不知道 cell、鼠标模式或帧。协议字节(alt screen、1000/1003/1006、
 * kitty push/pop)全部由 MoonBit 侧拼写,这样解码与编码逻辑都能在 `moon test`
 * 里对着字节流跑,不需要真终端。
 *
 * Unix(macOS/Linux)实现;其它平台提供返回失败的桩,保证链接与
 * MoonBit 侧的显式降级路径。
 */

#include <moonbit.h>

#ifndef _WIN32

#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

/* 单次 read 的上限:按键与鼠标 burst 远小于此,大段粘贴靠宿主循环再取。 */
#define MOOTTY_READ_CAP 4096

/*
 * 进入 raw mode 前保存的终端设置。只有一份:一个进程只有一个控制 tty,
 * 支持多份需要句柄表,而这里没有可重入的 raw mode 场景。
 */
static struct termios mootty_saved;
static int mootty_saved_valid = 0;
static volatile sig_atomic_t mootty_winch = 0;
static volatile sig_atomic_t mootty_terminate = 0;

/*
 * 把终端交回去。在信号处理器里调用 tcsetattr 不是 POSIX 认证的
 * async-signal-safe 操作,但 Ctrl-C 杀死进程前不做这件事,shell 会被留在
 * raw mode(输入不回显、行缓冲消失),用户只能靠 `reset` 恢复。
 * 两害相权取其一。
 */
static void mootty_restore_now(void) {
  if (mootty_saved_valid) {
    tcsetattr(STDIN_FILENO, TCSANOW, &mootty_saved);
    mootty_saved_valid = 0;
  }
}

static void mootty_on_winch(int sig) {
  (void)sig;
  /* 只置位:尺寸要在主循环里查,signal handler 里不能调 ioctl。 */
  mootty_winch = 1;
}

/*
 * 第一个退出信号只置位:alt screen、鼠标与 kitty 模式要由主循环的 shutdown
 * 关闭,在处理器里 tcsetattr 救得了 termios,救不了这层协议状态。
 * 第二个信号按老办法立即还原 termios 并用默认处置自杀——主循环已经卡死时,
 * 用户必须还有办法。
 */
static void mootty_on_fatal(int sig) {
  if (mootty_terminate) {
    mootty_restore_now();
    signal(sig, SIG_DFL);
    raise(sig);
    return;
  }
  mootty_terminate = 1;
}

int64_t mootty_isatty(int64_t fd) { return isatty((int)fd) ? 1 : 0; }

/*
 * 进入 raw mode:逐键、不回显、不翻译换行。
 *
 * 与 cfmakeraw 的差别只有一处:保留 ISIG。关掉它会让 Ctrl-C 变成普通字节
 * 0x03,于是「Ctrl-C 退出」这件事只能靠应用自己实现,而忘了实现的应用会把
 * 用户困在界面里;保留它则让上面 mootty_on_fatal 的还原逻辑有触发点。
 * 代价是应用收不到 Ctrl-C 按键事件,想占用它的应用必须自己换处置。
 */
int64_t mootty_enter_raw(int64_t fd) {
  struct termios t;
  if (tcgetattr((int)fd, &t) != 0) {
    return -1;
  }
  mootty_saved = t;
  mootty_saved_valid = 1;
  cfmakeraw(&t);
  t.c_lflag |= (tcflag_t)ISIG;
  if (tcsetattr((int)fd, TCSANOW, &t) != 0) {
    mootty_saved_valid = 0;
    return -2;
  }
  return 0;
}

/* 回到进入前的终端设置;没进过 raw mode 时是空操作。 */
int64_t mootty_leave_raw(int64_t fd) {
  if (!mootty_saved_valid) {
    return 0;
  }
  int rc = tcsetattr((int)fd, TCSANOW, &mootty_saved);
  mootty_saved_valid = 0;
  return rc == 0 ? 0 : -1;
}

/* 打包返回:低 32 位 = 列,高 32 位 = 行;失败 -1。 */
int64_t mootty_winsize(int64_t fd) {
  struct winsize ws;
  memset(&ws, 0, sizeof(ws));
  if (ioctl((int)fd, TIOCGWINSZ, &ws) != 0) {
    return -1;
  }
  if (ws.ws_col == 0 || ws.ws_row == 0) {
    return -1;
  }
  return ((int64_t)ws.ws_row << 32) | (int64_t)ws.ws_col;
}

/* 1 = 可读,0 = 超时(宿主据此结算裸 ESC),-1 = 错误。 */
int64_t mootty_poll(int64_t fd, int64_t timeout_ms) {
  struct pollfd pfd;
  int rc;
  pfd.fd = (int)fd;
  pfd.events = POLLIN;
  pfd.revents = 0;
  for (;;) {
    rc = poll(&pfd, 1, (int)timeout_ms);
    if (rc >= 0) {
      return (int64_t)rc;
    }
    if (errno == EINTR) {
      /* SIGWINCH/SIGINT 打断等待:此时行缓冲里可能一个字节都没有,但必须回主循环
       * 去查尺寸或结算退出标志,所以按「本轮没有数据」返回,而不是继续死等。 */
      if (mootty_winch || mootty_terminate) {
        return 0;
      }
      continue;
    }
    return -1;
  }
}

/* 取走当前可读字节;空 Bytes 表示没有数据或对端已关闭。 */
moonbit_bytes_t mootty_read(int64_t fd) {
  unsigned char buf[MOOTTY_READ_CAP];
  ssize_t n;
  for (;;) {
    n = read((int)fd, buf, sizeof(buf));
    if (n >= 0) {
      break;
    }
    if (errno == EINTR) {
      continue;
    }
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      return moonbit_make_bytes(0, 0);
    }
    return moonbit_make_bytes(0, 0);
  }
  if (n <= 0) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)n, 0);
  memcpy(out, buf, (size_t)n);
  return out;
}

/* 写完全部字节,返回写入数;短写循环补写,失败返回 -1。 */
int64_t mootty_write(int64_t fd, unsigned char *data, int64_t len) {
  int64_t off = 0;
  while (off < len) {
    ssize_t n = write((int)fd, data + off, (size_t)(len - off));
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      return -1;
    }
    if (n == 0) {
      return -1;
    }
    off += (int64_t)n;
  }
  return off;
}

/* SIGWINCH 置 resize 标志,SIGINT/SIGTERM/SIGHUP 置退出标志。 */
int64_t mootty_install_signals(void) {
  struct sigaction act;
  memset(&act, 0, sizeof(act));
  /* 不给处理器加 SA_RESTART:poll 被打断后返回,主循环才能及时处理尺寸。 */
  act.sa_handler = mootty_on_winch;
  if (sigaction(SIGWINCH, &act, NULL) < 0) {
    return -1;
  }
  act.sa_handler = mootty_on_fatal;
  if (sigaction(SIGINT, &act, NULL) < 0) {
    return -2;
  }
  if (sigaction(SIGTERM, &act, NULL) < 0) {
    return -3;
  }
  if (sigaction(SIGHUP, &act, NULL) < 0) {
    return -4;
  }
  return 0;
}

/* 读取并清零 resize 标志。 */
int64_t mootty_take_winch(void) {
  int64_t pending = mootty_winch;
  mootty_winch = 0;
  return pending;
}

/* 查询退出标志,不清零:置位之后每一次轮询都要继续看到它。 */
int64_t mootty_terminate_pending(void) { return mootty_terminate; }

#else

/* Windows:当前 TUI 路线未覆盖 ConPTY,全部返回失败,由宿主显式报错。 */
#include <stdint.h>

int64_t mootty_isatty(int64_t fd) {
  (void)fd;
  return 0;
}
int64_t mootty_enter_raw(int64_t fd) {
  (void)fd;
  return -1;
}
int64_t mootty_leave_raw(int64_t fd) {
  (void)fd;
  return -1;
}
int64_t mootty_winsize(int64_t fd) {
  (void)fd;
  return -1;
}
int64_t mootty_poll(int64_t fd, int64_t timeout_ms) {
  (void)fd;
  (void)timeout_ms;
  return -1;
}
moonbit_bytes_t mootty_read(int64_t fd) {
  (void)fd;
  return moonbit_make_bytes(0, 0);
}
int64_t mootty_write(int64_t fd, unsigned char *data, int64_t len) {
  (void)fd;
  (void)data;
  (void)len;
  return -1;
}
int64_t mootty_install_signals(void) { return -1; }
int64_t mootty_take_winch(void) { return 0; }
int64_t mootty_terminate_pending(void) { return 0; }

#endif
