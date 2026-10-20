///|
/// 一次真终端会话:派生被测 TUI,把它的输出攒成原始字节,按整段重放反解成栅格。
///
/// 会话与栅格分开是有意的:一个用例起一个进程,交互状态就不会跨用例泄漏;
/// 而栅格尺寸固定在会话开始时的行列,缩小窗口后才有「超出当前网格的区域有没有
/// 被写脏」这个参照系。
priv struct Session {
  pty : @pty.Pty
  cols : Int32
  rows : Int32
  raw : Array[Byte]
}

///|
/// SIGWINCH(macOS 与 Linux 都是 28)。
const SIGWINCH : Int32 = 28

///|
/// 确认窗(毫秒):等到内容或响应之后,这么久没有新字节才认为这一帧发完了。
/// 它不再是完成判据 —— 判据是断言的 needle(`await_frame`)或「应用起码回了
/// 一次话」(`await_reply`);安静窗降级为把这一帧的尾巴刷干净。会话锁保证
/// 单进程独占 CPU 之后,60ms 内漏帧只剩进程自身调度一种来源,而这正是
/// 内容锚点兜底的:needle 没到就一直轮询,不靠猜。
const CONFIRM_MS : Int32 = 60

///|
/// 轮询步长(毫秒):needle 未命中时每轮最多等这么久。
const POLL_MS : Int32 = 25

///|
/// 等内容的总预算(毫秒),包含被测进程派生与首帧延迟。超时不挂死也不判过:
/// 让调用方的断言拿着整屏 dump 红,红得可复现(旧的 FIRST_FRAME_MS 是判据,
/// 这里它只是失败上限)。
const WAIT_BUDGET_MS : Int32 = 5000

///|
/// 等「应用起码回了一次话」的上限:用于只能靠「画面没变」来证明的断言
/// (点命中盒外面、dead-zone 散焦)。首字节到了就转确认窗;整段预算没有动静
/// 就按「确实没重绘」放行。
const REPLY_BUDGET_MS : Int32 = 1500

///|
/// 排空循环的上限轮次。PTY 缓冲约 4KB,被测程序写满就阻塞在写帧上,
/// 所以必须边等边读;这个上限只用来兜住「程序无限刷屏」这种不该红的挂死。
const MAX_SETTLE_ROUNDS : Int32 = 512

///|
/// 同一进程里同时只允许一个会话活着:一个会话独占 CPU,确认窗才不用把
/// 「被别的测试饿死」误读成「这帧发完了」。放弃的方案:把安静窗提到 1s ——
/// 只是把阈值推后;needle 锚定之后,串行仍然保留,因为会话之间的 CPU 竞争
/// 依然是任何时间判据的敌人。
let session_lock : @async.Mutex = @async.Mutex::Mutex()

///|
/// 派生会话。首帧不在这里等:每个用例用 `await_frame` 等内容 needle,
/// 启动等待自然被 `WAIT_BUDGET_MS` 覆盖。`path` 必须是已构建好的可执行文件;
/// 拿到锁的一刻到 `finish` 之间就是这个用例独享的终端。
async fn Session::open(
  path : String,
  cols~ : Int32,
  rows~ : Int32,
  args~ : Array[String] = [],
) -> Session {
  session_lock.acquire()
  match @pty.Pty::spawn(path, cols, rows, args~) {
    None => {
      session_lock.release()
      abort("PTY 冒烟无法派生被测程序:" + path)
    }
    Some(pty) => { pty, cols, rows, raw: [], }
  }
}

///|
/// 一轮有界读:最多等 `timeout_ms` 拿新字节。返回是否真的读到了东西。
async fn Session::drain_once(self : Session, timeout_ms : Int32) -> Bool {
  let buf : FixedArray[Byte] = FixedArray::make(65536, 0)
  let bytes = buf.unsafe_reinterpret_as_bytes()
  if !self.pty.wait_readable(timeout_ms) {
    return false
  }
  let n = self.pty.read_output(buf)
  if n <= 0 {
    return false
  }
  let mut i = 0
  while i < n {
    self.raw.push(bytes[i])
    i = i + 1
  }
  true
}

///|
/// 刷帧尾:读到连续 `CONFIRM_MS` 没有新字节为止,轮次有界防挂死。
async fn Session::settle_quiet(self : Session) -> Unit {
  let mut rounds = 0
  while rounds < MAX_SETTLE_ROUNDS && self.drain_once(CONFIRM_MS) {
    rounds = rounds + 1
  }
}

///|
/// 确定性等待:轮询反解出的栅格直到 `pred` 命中,再把这一帧的尾巴刷干净。
///
/// 约束两条,都用错就会随机红或假绿:
/// - `pred` 必须锚在**新帧才会出现**的内容上(needle 从旧屏到新屏翻转);
///   锚在一直存在的内容上等于不等。
/// - `pred` 会被尚未发完的半帧求值,所以只能是纯读函数(`has`、计数、
///   `styled_count`),不许用会 abort 的 `int_or_fail` / `row_or_check`。
async fn Session::await_frame(self : Session, pred : (Screen) -> Bool) -> Unit {
  let mut waited = 0
  let mut hit = false
  while !hit && waited < WAIT_BUDGET_MS {
    if pred(self.screen()) {
      hit = true
    } else if !self.drain_once(POLL_MS) {
      waited = waited + POLL_MS
    }
  }
  self.settle_quiet()
}

///|
/// 等「应用起码回了一次话」:新字节到达即转确认窗;`REPLY_BUDGET_MS`
/// 内毫无动静则按「没有重绘」放行。用在只能靠画面不变来证明的断言前。
async fn Session::await_reply(self : Session) -> Unit {
  let start = self.raw.length()
  let mut waited = 0
  while waited < REPLY_BUDGET_MS {
    if self.raw.length() > start {
      break
    }
    if !self.drain_once(POLL_MS) {
      waited = waited + POLL_MS
    }
  }
  self.settle_quiet()
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
/// 写入一段输入(按键或鼠标序列)。不隐式等待:调用方紧接着用
/// `await_frame`/`await_reply` 说明「等什么」,等待才有内容判据。
async fn Session::send(self : Session, text : String) -> Unit {
  ignore(self.pty.write_input(@utf8.encode(text, bom=false)))
}

///|
/// 改窗口大小并触发重排;不隐式等待,调用方等 rebuild 计数翻上去。
///
/// 内核只在 tty 有控制终端时才替 `TIOCSWINSZ` 发 SIGWINCH,而 posix_spawn
/// (SETSID + dup2,不调 TIOCSCTTY)派生的子进程没有控制终端,所以这里由驱动
/// 补发那一个信号。被测进程走的仍然是同一条 SIGWINCH→重排通路:证的是宿主,
/// 不是内核的会话规则。
fn Session::resize_to(self : Session, cols : Int32, rows : Int32) -> Unit {
  self.pty.resize(cols, rows)
  self.pty.signal(SIGWINCH)
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
/// counter 的 terminal 入口:整屏只有三个按钮和一行 `Count:`,
/// 是「按钮标签画在哪一行」这件事最干净的载体 —— 双栏 demo 里标签都住在
/// 条目内部,行号偏移会被子节点的定位吃掉,测不出量化本身。
fn counter_binary() -> String? {
  smoke_env("MOUI_TUI_COUNTER_BIN")
}

///|
/// `examples/tui_layers` 的 terminal 入口:H5 之后它是唯一的双栏交互门,
/// 八条验收要求住在同一个 app 里;即时按键(状态行 `rows=` 随每一下按键
/// 下降)与 `only-visible` 这类「模型字段可直接配」的交互只有它有载体。
/// 未设置对应环境变量时用例整体跳过:这道门要点名才跑
/// (`scripts/tui-pty-smoke.sh` 一定设置它),普通 `moon test` 不该依赖构建产物。
fn layers_binary() -> String? {
  smoke_env("MOUI_TUI_LAYERS_BIN")
}

///|
/// 冒烟统一用 100x30:够宽放下两栏加分隔,够矮让 16 行列表溢出视口,
/// 于是滚动与裁剪才是可观察的。
const COLS : Int32 = 100

///|
const ROWS : Int32 = 30

///|
/// 起一个 S7 八项合一 demo 会话;门没开时给 None,调用方直接跳过。
async fn open_layers() -> Session? {
  match layers_binary() {
    None => None
    Some(path) => Some(Session::open(path, cols=COLS, rows=ROWS))
  }
}
