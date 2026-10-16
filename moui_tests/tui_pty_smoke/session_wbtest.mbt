///|
/// 一次真终端会话:派生被测 TUI,把它的输出攒成原始字节,按整段重放反解成栅格。
///
/// 会话与栅格分开是有意的:一个用例起一个进程,交互状态就不会跨用例泄漏;
/// 而栅格尺寸固定在会话开始时的行列,缩小窗口后才有「超出当前网格的区域有没有
/// 被写脏」这个参照系。
priv struct Session {
  pty : @pty.Pty
  cols : Int
  rows : Int
  raw : Array[Byte]
}

///|
/// SIGWINCH(macOS 与 Linux 都是 28)。
const SIGWINCH : Int = 28

///|
/// 一轮 settle 的安静窗口(毫秒):这么久没有新字节就认为这一帧发完了。
const QUIET_MS : Int = 250

///|
/// 会话第一个字节的等待上限(毫秒)。安静窗口回答的是「这一帧发完了没」,
/// 不能拿来回答「进程起床了没」:派生后 250ms 内没字节是正常启动耗时,
/// 用它等首帧会把空屏当成一帧读,整条冒烟就在第一个断言上随机红。
const FIRST_FRAME_MS : Int = 5000

///|
/// 排空循环的上限轮次。PTY 缓冲约 4KB,被测程序写满就阻塞在写帧上,
/// 所以必须边等边读;这个上限只用来兜住「程序无限刷屏」这种不该红的挂死。
const MAX_SETTLE_ROUNDS : Int = 512

///|
/// 同一进程里同时只允许一个会话活着。async 测试驱动会把用例并发起来
/// (最多 10 个协程),而 settle 判据是「250ms 没有新字节」这种时间事实:
/// 七个被测进程抢同一颗事件循环时,被饿过 250ms 的那一帧会被读成半帧。
/// 放弃的方案:把 QUIET_MS 提到 1s —— 只是把阈值推后,红还是随机红,
/// 而且慢七倍。串行之后每个会话独占 CPU,时间判据才成立。
let session_lock : @async.Mutex = @async.Mutex::Mutex()

///|
/// 派生会话并等首帧发完。`path` 必须是已经构建好的可执行文件。
/// 拿到锁的一刻到 `finish` 之间就是这个用例独享的终端。
async fn Session::open(path : String, cols~ : Int, rows~ : Int) -> Session {
  session_lock.acquire()
  match @pty.Pty::spawn(path, cols, rows) {
    None => {
      session_lock.release()
      abort("PTY 冒烟无法派生被测程序:" + path)
    }
    Some(pty) => {
      let session = { pty, cols, rows, raw: [], }
      session.settle()
      session
    }
  }
}

///|
/// 读到安静为止。用有界等待而不是固定读 N 次或固定 sleep:应用出错不回帧时,
/// 冒烟要红,不能挂在阻塞读上。
async fn Session::settle(self : Session) -> Unit {
  let buf : FixedArray[Byte] = FixedArray::make(65536, 0)
  let bytes = buf.unsafe_reinterpret_as_bytes()
  let mut rounds = 0
  while rounds < MAX_SETTLE_ROUNDS {
    rounds = rounds + 1
    let deadline = if self.raw.is_empty() { FIRST_FRAME_MS } else { QUIET_MS }
    if !self.pty.wait_readable(deadline) {
      return ()
    }
    let n = self.pty.read_output(buf)
    if n <= 0 {
      return ()
    }
    let mut i = 0
    while i < n {
      self.raw.push(bytes[i])
      i = i + 1
    }
  }
}

///|
/// 把整段输出重放成一个栅格。每次从头反解而不是增量维护:分块边界把 CJK 或
/// 制表符的 UTF-8 序列切开时,增量模型要猜半个字符,重放不用。
fn Session::screen(self : Session) -> Screen {
  let screen = screen_new(self.cols, self.rows)
  screen.feed(@utf8.decode_lossy(Bytes::from_array(self.raw)))
  screen
}

///|
/// 写入一段输入(按键或鼠标序列),然后等应用把这一帧发完。
async fn Session::send(self : Session, text : String) -> Unit {
  ignore(self.pty.write_input(@utf8.encode(text, bom=false)))
  self.settle()
}

///|
/// 改窗口大小并等重排落地。
///
/// 内核只在 tty 有控制终端时才替 `TIOCSWINSZ` 发 SIGWINCH,而 posix_spawn
/// (SETSID + dup2,不调 TIOCSCTTY)派生的子进程没有控制终端,所以这里由驱动
/// 补发那一个信号。被测进程走的仍然是同一条 SIGWINCH→重排通路:证的是宿主,
/// 不是内核的会话规则。
async fn Session::resize_to(self : Session, cols : Int, rows : Int) -> Unit {
  self.pty.resize(cols, rows)
  self.pty.signal(SIGWINCH)
  self.settle()
}

///|
/// 关掉 master:被测程序读到 EOF 后走正常还原路径退出,并交还会话锁。
fn Session::finish(self : Session) -> Unit {
  self.pty.close()
  session_lock.release()
}

///|
/// 落一份原始字节流,失败不影响结论。有 `MOUI_TUI_SMOKE_LOG` 时才写。
fn Session::save_log(self : Session) -> Unit {
  match smoke_env("MOUI_TUI_SMOKE_LOG") {
    None => ()
    Some(path) =>
      @fs.write_bytes_to_file(path, Bytes::from_array(self.raw)) catch {
        _ => ()
      }
  }
}

///|
/// 失败时给人看的栅格快照:断言只说「没有这行」不够定位,要看到整屏。
fn Session::dump(self : Session, label : String) -> Unit {
  println("=== \{label} (\{self.cols}x\{self.rows}) ===")
  println(self.screen().text())
}

///|
/// 读一个非空环境变量;空串按未设置处理。
fn smoke_env(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let clean = value.trim().to_owned()
      if clean == "" {
        None
      } else {
        Some(clean)
      }
    }
    None => None
  }
}

///|
/// 被测可执行文件路径。未设置时用例整体跳过:这道门要点名才跑
/// (`scripts/tui-pty-smoke.sh` 一定设置它),普通 `moon test` 不该依赖构建产物。
fn smoke_binary() -> String? {
  smoke_env("MOUI_TUI_SMOKE_BIN")
}

///|
/// counter 的 terminal 入口:整屏只有三个按钮和一行 `Count:`,
/// 是「按钮标签画在哪一行」这件事最干净的载体 —— 双栏 demo 里标签都住在
/// 条目内部,行号偏移会被子节点的定位吃掉,测不出量化本身。
fn counter_binary() -> String? {
  smoke_env("MOUI_TUI_COUNTER_BIN")
}

///|
/// `examples/tui_layers` 的 terminal 入口:八条验收要求住在同一个 app 里。
/// 即时按键(状态行的 `rows=` 随每一下按键下降)与 `only-visible` 这类
/// 「模型字段可直接配」的交互只有它才有载体,`tui_split` 的静态列表证明不了。
fn layers_binary() -> String? {
  smoke_env("MOUI_TUI_LAYERS_BIN")
}

///|
/// 冒烟统一用 100x30:够宽放下两栏加分隔,够矮让 16 行列表溢出视口,
/// 于是滚动与裁剪才是可观察的。
const COLS : Int = 100

///|
const ROWS : Int = 30

///|
/// 起一个双栏 demo 会话;门没开时给 None,调用方直接跳过。
async fn open_demo() -> Session? {
  match smoke_binary() {
    None => None
    Some(path) => Some(Session::open(path, cols=COLS, rows=ROWS))
  }
}

///|
/// 起一个 S7 八项合一 demo 会话;门没开时给 None,调用方直接跳过。
async fn open_layers() -> Session? {
  match layers_binary() {
    None => None
    Some(path) => Some(Session::open(path, cols=COLS, rows=ROWS))
  }
}
