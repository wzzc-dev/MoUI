///|
/// PTY 宿主:openpty + posix_spawn 派生真实终端会话,经 RawFd 异步读写。
/// 仅支持 Unix(native)。
#borrow(shell)
#borrow(args)
extern "C" fn pty_spawn(
  shell : Bytes,
  shell_len : Int,
  args : Bytes,
  args_len : Int,
  cols : Int,
  rows : Int,
) -> Int64 = "moonpty_spawn"

///|
extern "C" fn pty_resize(fd : Int, cols : Int, rows : Int) -> Int64 = "moonpty_resize"

///|
extern "C" fn pty_reap(pid : Int) -> Int64 = "moonpty_reap"

///|
extern "C" fn pty_signal(pid : Int, sig : Int) -> Int64 = "moonpty_signal"

///|
extern "C" fn pty_wait(fd : Int, timeout_ms : Int) -> Int64 = "moonpty_wait"

///|
/// PTY 会话:master 端异步读写 + 原始 fd 用于 ioctl。
pub struct Pty {
  fd : Int
  pid : Int
  raw : @raw_fd.RawFd
}

///|
/// 派生一个运行 shell 的 PTY 会话。`args` 是传给可执行文件的命令行参数
/// (冒烟门用它开主题档等变体会话);空数组与旧行为完全一致。
pub async fn Pty::spawn(
  shell : String,
  cols : Int,
  rows : Int,
  args? : Array[String] = [],
) -> Pty? {
  let bytes = @utf8.encode(shell)
  let arr : Array[Byte] = []
  for i in 0..<bytes.length() {
    arr.push(bytes[i])
  }
  arr.push(b'\x00')
  let arg_bytes = @utf8.encode(args.join("\n"))
  let arg_arr : Array[Byte] = []
  for i in 0..<arg_bytes.length() {
    arg_arr.push(arg_bytes[i])
  }
  arg_arr.push(b'\x00')
  let packed = pty_spawn(
    Bytes::from_array(arr),
    bytes.length(),
    Bytes::from_array(arg_arr),
    arg_bytes.length(),
    cols,
    rows,
  )
  if packed < 0L {
    return None
  }
  let fd = packed.to_int() // 低 32 位
  let pid = (packed >> 32).to_int() // 高 32 位
  let raw = raw_fd_from_int(fd)
  Some({ fd, pid, raw, })
}

///|
/// 从原始 fd 整数构造 RawFd。
/// Unix:系统 fd 即整数,直接包装。
#cfg(not(platform="windows"))
async fn raw_fd_from_int(fd : Int) -> @raw_fd.RawFd {
  RawFd(fd)
}

///|
/// Windows 上 PTY 宿主不可用(moonpty_* C stub 仅非 Windows 提供实现)。
#cfg(platform="windows")
fn raw_fd_from_int(fd : Int) -> @raw_fd.RawFd {
  abort("pty_host: PTY is not supported on Windows, fd:" + fd.to_string())
}

///|
/// 子进程 pid。
pub fn Pty::pid(self : Pty) -> Int {
  self.pid
}

///|
/// master fd(调试用)。
pub fn Pty::fd(self : Pty) -> Int {
  self.fd
}

///|
/// 读输出到 buf,返回读取字节数(0 = EOF)。
pub async fn Pty::read_output(self : Pty, buf : FixedArray[Byte]) -> Int {
  self.raw.read(buf)
}

///|
/// master 端在 `timeout_ms` 内是否可读。驱动方必须有这条有界等待:
/// 只有阻塞读时,被测进程不回复的冒烟会挂住而不是红。
pub fn Pty::wait_readable(self : Pty, timeout_ms : Int) -> Bool {
  pty_wait(self.fd, timeout_ms) > 0L
}

///|
/// 写入输入(键盘/粘贴)。
pub async fn Pty::write_input(self : Pty, data : Bytes) -> Int {
  self.raw.write(data)
}

///|
/// 调整 PTY 尺寸(通知 shell 的 TIOCSWINSZ)。
pub fn Pty::resize(self : Pty, cols : Int, rows : Int) -> Unit {
  ignore(pty_resize(self.fd, cols, rows))
}

///|
/// 向子进程发送信号(1=SIGHUP,2=SIGINT,28=SIGWINCH)。
///
/// 驱动方必须能自己补发 SIGWINCH:`TIOCSWINSZ` 只通知「该 tty 的前台进程组」,
/// 而 posix_spawn(SETSID + dup2,无 TIOCSCTTY)派生的子进程没有控制终端,
/// kernel 因此不会替真终端发这个信号。补发之后被测进程走的仍然是同一条
/// SIGWINCH→重排通路,测的是宿主而不是内核。
pub fn Pty::signal(self : Pty, sig : Int) -> Unit {
  ignore(pty_signal(self.pid, sig))
}

///|
pub fn Pty::close(self : Pty) -> Unit {
  self.raw.close()
  // 非阻塞回收已退出的子进程,避免僵尸(重试数次覆盖回收竞争窗口);
  // 仍存活则发 SIGHUP 通知 shell 退出,再回收一次
  let mut reaped = false
  for _ in 0..<5 {
    let status = pty_reap(self.pid)
    if status != 0 {
      reaped = true
      break
    }
  }
  if !reaped {
    ignore(pty_signal(self.pid, 1)) // SIGHUP
    ignore(pty_reap(self.pid))
  }
}

///|
/// 输出读循环:持续读取 PTY 输出并以原始字节块 emit。
/// 在子进程退出(EOF)时结束;UTF-8 解码交给解析器(feed_bytes),
/// 避免多字节字符被 4096 块边界拆成替换符。
pub async fn pty_read_loop(pty : Pty, emit : (Bytes) -> Unit) -> Unit {
  let buf : FixedArray[Byte] = FixedArray::make(4096, 0)
  while true {
    let n = pty.read_output(buf)
    if n <= 0 {
      break
    }
    emit(buf.unsafe_reinterpret_as_bytes()[0:n].to_owned())
  }
}
