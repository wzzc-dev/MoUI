///|
/// 终端 fd 层:raw mode、尺寸、读写字节与信号。
///
/// 这里只有「fd 上发生了什么」,没有协议:不拼 ESC,不认键,不算 cell 尺寸。
/// 分成两层是为了让 `moon test` 能对着字节流测解码,也为了让宿主在退出时
/// 只依赖一处还原逻辑。
#borrow(bytes)
extern "C" fn c_write(fd : Int32, bytes : Bytes, len : Int32) -> Int64 = "mootty_write"

///|
extern "C" fn c_isatty(fd : Int32) -> Int64 = "mootty_isatty"

///|
extern "C" fn c_enter_raw(fd : Int32) -> Int64 = "mootty_enter_raw"

///|
extern "C" fn c_leave_raw(fd : Int32) -> Int64 = "mootty_leave_raw"

///|
extern "C" fn c_winsize(fd : Int32) -> Int64 = "mootty_winsize"

///|
extern "C" fn c_poll(fd : Int32, timeout_ms : Int32) -> Int64 = "mootty_poll"

///|
extern "C" fn c_read(fd : Int32) -> Bytes = "mootty_read"

///|
extern "C" fn c_install_signals() -> Int64 = "mootty_install_signals"

///|
extern "C" fn c_take_winch() -> Int64 = "mootty_take_winch"

///|
extern "C" fn c_terminate_pending() -> Int64 = "mootty_terminate_pending"

///|
fn fd_is_a_terminal(fd : Int32) -> Bool {
  c_isatty(fd) == 1L
}

///|
/// `wait` 的结果。`Timeout` 不是错误:它就是「这一轮没有更多字节」的事实,
/// 解码器据此把裸 ESC 结算成 Escape 键。
pub enum PollState {
  Ready
  Timeout
  Unavailable
} derive(Eq, Debug)

///|
pub extend PollState with Eq::{not_equal, equal}

///|
pub extend PollState with Debug::{to_repr}

///|
/// 控制终端:输入固定在 fd 0,输出固定在 fd 1(终端会话的约定)。
///
/// 两个 fd 分开存,是因为「stdin 是管道」(测试里常见)和「stdout 被重定向到
/// 文件」是两种不同的失败,合在一起报会让用户不知道该改哪一边。
pub struct Tty {
  in_fd : Int32
  out_fd : Int32
}

///|
/// 当前进程的控制终端。这里不检查它是不是 tty:调用方先用 `is_terminal`
/// 判断,才能在非 tty 环境(管道、CI)里给出人话错误而不是 raw mode 失败码。
pub fn Tty::current() -> Tty {
  { in_fd: 0, out_fd: 1, }
}

///|
pub fn Tty::is_terminal(self : Tty) -> Bool {
  fd_is_a_terminal(self.in_fd) && fd_is_a_terminal(self.out_fd)
}

///|
/// 保存终端设置并进入 raw mode。进入后必须成对调用 `restore`,
/// 否则 shell 会被留在 raw mode。
///
/// 失败用返回值而不是 `raise`:`Unit raise` 的错误类型是擦除的,宿主拿回的
/// 是一个 `Error` 而不是这里写的那句话,而终端宿主必须把 raw mode 失败、信号
/// 安装失败、写失败分别映射成 `TerminalExit` 的不同格子。返回值也让
/// `TuiSink::write`(要求纯函数)那条出口路径不用 try/catch。
pub fn Tty::enter_raw(self : Tty) -> String? {
  let rc = c_enter_raw(self.in_fd)
  if rc == 0L {
    None
  } else {
    Some(
      "无法进入 raw mode(终端不可用或被其它程序占用),code=" +
      rc.to_string(),
    )
  }
}

///|
/// 还原进入 raw mode 之前的终端设置。没进过 raw mode 时是空操作,
/// 因此可以放在清理路径上无条件调用。
pub fn Tty::restore(self : Tty) -> Unit {
  let _ = c_leave_raw(self.in_fd)
}

///|
/// 终端网格尺寸(列, 行)。非 tty、或尺寸报 0 时返回 None。
pub fn Tty::grid(self : Tty) -> (Int32, Int32)? {
  let packed = c_winsize(self.in_fd)
  if packed < 0L {
    None
  } else {
    let cols = (packed & 0xffffffffL).to_int()
    let rows = (packed >> 32).to_int()
    Some((cols, rows))
  }
}

///|
/// 等待输入,最多 `timeout_ms` 毫秒。SIGWINCH 会打断等待并返回 `Timeout`,
/// 让宿主立刻去查新尺寸,而不是等下一个超时。
pub fn Tty::wait(self : Tty, timeout_ms~ : Int32) -> PollState {
  let rc = c_poll(self.in_fd, timeout_ms)
  if rc > 0L {
    Ready
  } else if rc == 0L {
    Timeout
  } else {
    Unavailable
  }
}

///|
/// 取走当前可读字节。空 `Bytes` 表示没有数据,或对端已关闭(EOF)。
pub fn Tty::take_input(self : Tty) -> Bytes {
  c_read(self.in_fd)
}

///|
/// 把字节写到终端。短写在 C 侧循环补全;写不进就返回原因,
/// 让宿主有机会先还原终端再退出。
pub fn Tty::emit(self : Tty, bytes : Bytes) -> String? {
  let rc = c_write(self.out_fd, bytes, bytes.length())
  if rc < 0L {
    Some("写入终端失败")
  } else {
    None
  }
}

///|
/// 把一段文本按 UTF-8 写到终端。协议字节和投影输出都走这一条,编码只在此处
/// 发生:`String::to_bytes` 已被标 deprecated,而 CJK 内容必须按 UTF-8 出去。
pub fn Tty::write_text(self : Tty, text : String) -> String? {
  self.emit(@utf8.encode(text[:], bom=false))
}

///|
/// 装 SIGWINCH(resize 标志)与 SIGINT/SIGTERM/SIGHUP(退出标志)。
/// 两类信号都只置位,处置权留在主循环:协议字节只能在正常退出路径上关闭。
pub fn Tty::install_signal_handlers(_self : Tty) -> String? {
  let rc = c_install_signals()
  if rc == 0L {
    None
  } else {
    Some("无法安装终端信号处理,code=" + rc.to_string())
  }
}

///|
/// 读取并清零 resize 信号:每次只报一次,宿主据此把 resize 当成一次完整重排。
pub fn Tty::take_resize_signal(_self : Tty) -> Bool {
  c_take_winch() != 0L
}

///|
/// 是否收到过退出信号。不清零:标志一旦置位,主循环每一轮都要继续看到它,
/// 直到走完还原。raw mode 有意保留 `ISIG`,所以 Ctrl-C 到不了按键通道,
/// 只能从这条路结算。
pub fn Tty::terminate_requested(_self : Tty) -> Bool {
  c_terminate_pending() != 0L
}
