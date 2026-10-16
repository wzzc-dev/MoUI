///|
/// 终端宿主:raw mode 会话、三条输入通道的派发时机、帧泵与还原。
///
/// 生命周期只有这一处状态机:`probe → attach → raw → modes → pump → shutdown`。
/// `tty.mbt` 只管 fd 上的事实,`decode.mbt` 只管字节到事实,
/// `input_channel.mbt` 只管事实到宿主事件;这里管「什么时候派发」。
/// 每条输入都立刻走完 dispatch→render_frame,所以「按下即响应」不需要应用
/// 自己找时机重画。
///
/// 残影与清屏:投影器每帧只写脏行(逐行绝对定位 + `ESC[2K`),resize 让整屏
/// 标脏并一次 `ESC[2J` 重建。宿主因此不能在任何两帧之间打印自己的文字——
/// 那会被下一次逐行定位覆盖成残影。所有宿主侧文本都攒在 `TerminalExit` 里,
/// 由调用方在离开 alt screen 之后打印。
priv struct TerminalState {
  mut driver : @runtime.HostRuntimeDriver?
  mut session : @render.RendererSession?
  mut input : TerminalInput?
  mut decoder : TerminalDecoder?
  mut tty : Tty?
  mut modes_active : Bool
  mut needs_render : Bool
  mut close_requested : Bool
  mut surface_generation : Int
  mut next_sequence : Int
  mut write_failure : String?
}

///|
/// 一个进程只有一个控制终端,所以宿主状态是单例(与 wechat 后端同形)。
/// 再次 `run_*` 会把上一轮的还原跳掉,不支持。
let state : TerminalState = {
  driver: None,
  session: None,
  input: None,
  decoder: None,
  tty: None,
  modes_active: false,
  needs_render: false,
  close_requested: false,
  surface_generation: 0,
  next_sequence: 1,
  write_failure: None,
}

///|
/// 协议字节。C 桥不知道这些存在:全部在 MoonBit 侧拼写,才能用字节流单测。
///
/// - `?1049` alt screen:进入即清屏,离开即把主屏与原光标位置交还 shell。
/// - `?1000` 按钮事件、`?1003` 任意移动(拖动/悬停)、`?1006` SGR 坐标编码。
/// - `>3u` kitty 键盘协议:flag 1 消歧(方向键不再与 ESC 前缀混淆),
///   flag 2 上报事件类型(press/repeat/release 可区分)。不支持的终端忽略它并
///   退回 legacy 编码,解码器两条都认。
/// - `?25l` 隐藏光标:投影器逐行绝对定位,残留光标会闪。
const ENTER_ALT_SCREEN : String = "\u{1b}[?1049h"

///|
const LEAVE_ALT_SCREEN : String = "\u{1b}[?1049l"

///|
const ENABLE_MOUSE : String = "\u{1b}[?1000h\u{1b}[?1003h\u{1b}[?1006h"

///|
const DISABLE_MOUSE : String = "\u{1b}[?1006l\u{1b}[?1003l\u{1b}[?1000l"

///|
const PUSH_KEYBOARD : String = "\u{1b}[>3u"

///|
const POP_KEYBOARD : String = "\u{1b}[<u"

///|
const HIDE_CURSOR : String = "\u{1b}[?25l"

///|
const SHOW_CURSOR : String = "\u{1b}[?25h"

///|
const RESET_SGR : String = "\u{1b}[0m"

///|
/// 进入会话时一次写完的开启序列。合成一条写而不是逐条发:每次 write 都是一次
/// 系统调用,分开还会在 alt screen 与鼠标模式之间留出一个能被打断的空隙。
const ENTER_MODES : String = ENTER_ALT_SCREEN +
  HIDE_CURSOR +
  RESET_SGR +
  ENABLE_MOUSE +
  PUSH_KEYBOARD

///|
const EXIT_MODES : String = DISABLE_MOUSE +
  POP_KEYBOARD +
  SHOW_CURSOR +
  RESET_SGR +
  LEAVE_ALT_SCREEN

///|
/// 一轮等待输入的最长时间(毫秒)。它同时是裸 ESC 的消歧窗口:太长会让 Escape
/// 键按起来没反应,太短会把跨两次 read 送达的序列拆成两条事实。
/// 50ms 落在「人手达不到、终端拆包够得着」的折中点。
const DEFAULT_IDLE_TIMEOUT_MS : Int = 50

///|
/// 宿主退出原因。正常退出只有一种:应用自己请求关闭。
pub(all) enum TerminalExit {
  /// 应用请求关闭(运行时报 close_requested)。
  Closed
  /// stdin 或 stdout 不是终端:管道、CI、重定向。
  NotTerminal
  /// 是终端但读不到行列数(`TIOCGWINSZ` 报错或报 0)。
  NoGridSize
  /// 进入 raw mode、装信号处理或写协议字节失败,带原因。
  SetupFailed(String)
  /// 渲染器拒绝接管这个 surface(尺寸为 0 等),带原因。
  RendererRejected(String)
  /// 写终端失败(管道被关、EPIPE),带原因。
  WriteFailed(String)
} derive(Eq, Debug)

///|
pub extend TerminalExit with Eq::{not_equal, equal}

///|
pub extend TerminalExit with Debug::{to_repr}

///|
/// 给用户看的一句话。必须在离开 alt screen 之后打印,所以交回调用方输出。
pub fn TerminalExit::describe(self : TerminalExit) -> String {
  match self {
    Closed => ""
    NotTerminal =>
      "标准输入与输出都必须是终端;管道与重定向下无法进入 raw mode。"
    NoGridSize => "终端没有报告行列数,无法建立 cell 栅格。"
    SetupFailed(reason) => "终端初始化失败:" + reason
    RendererRejected(reason) =>
      "TUI 渲染器拒绝接管这个 surface:" + reason
    WriteFailed(reason) => "写终端失败:" + reason
  }
}

///|
/// 跑一个 Program:进入 alt screen 与 raw mode,直到应用请求关闭或终端不可用。
/// 返回前终端一定已经还原。
///
/// 渲染器在此显式声明为 `tui-ansi`,不走多渲染器择优:终端没有 GPU surface
/// 可回退,择优失败只会把原因藏起来。
pub fn[Model, Msg] run_program(
  program~ : @core.Program[Model, Msg],
  cell? : @tui_renderer.CellBox = @tui_renderer.CellBox::default(),
  idle_timeout_ms? : Int = DEFAULT_IDLE_TIMEOUT_MS,
) -> TerminalExit {
  match probe_tty() {
    Err(exit) => exit
    Ok((tty, cols, rows)) => {
      let input = TerminalInput::new(cols~, rows~, cell~)
      let runtime = @runtime.new_program(
        program~,
        size=input.metrics().logical_size,
      )
      run(tty, runtime, input, idle_timeout_ms)
    }
  }
}

///|
/// 跑一个根 View,给不需要 Program 的薄入口用。
pub fn[Msg] run_view(
  root~ : @core.View[Msg],
  cell? : @tui_renderer.CellBox = @tui_renderer.CellBox::default(),
  idle_timeout_ms? : Int = DEFAULT_IDLE_TIMEOUT_MS,
  on_message? : ((Msg) -> Unit)? = None,
) -> TerminalExit {
  match probe_tty() {
    Err(exit) => exit
    Ok((tty, cols, rows)) => {
      let input = TerminalInput::new(cols~, rows~, cell~)
      let runtime = @runtime.new_view(
        root~,
        size=input.metrics().logical_size,
        on_message~,
      )
      run(tty, runtime, input, idle_timeout_ms)
    }
  }
}

///|
fn probe_tty() -> Result[(Tty, Int, Int), TerminalExit] {
  let tty = Tty::current()
  if !tty.is_terminal() {
    Err(NotTerminal)
  } else {
    match tty.grid() {
      None => Err(NoGridSize)
      Some((cols, rows)) => Ok((tty, cols, rows))
    }
  }
}

///|
/// 装配 → 开协议 → 泵 → 还原。`attach` 在 raw mode 之前:绑定失败时终端
/// 从未被改过,还原路径因此是空操作而不是猜。
fn run(
  tty : Tty,
  runtime : @runtime.AppRuntime,
  input : TerminalInput,
  idle_timeout_ms : Int,
) -> TerminalExit {
  state.tty = Some(tty)
  state.input = Some(input)
  state.decoder = Some(TerminalDecoder::new())
  // 终端投影只读语义帧,而语义负载默认关闭:不开就是拿一个空帧。
  runtime.set_semantics_frames_enabled(true)
  state.driver = Some(
    @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
      state.needs_render = true
    }),
  )
  let exit = match state.attach(input, tty) {
    Some(reason) => RendererRejected(reason)
    None =>
      match state.open_session(tty) {
        Some(reason) => SetupFailed(reason)
        None => state.pump(idle_timeout_ms~)
      }
  }
  state.shutdown(tty)
  exit
}

///|
/// 打开会话:raw mode → 信号处理 → 协议字节。任一步失败就带着那一步的原因返回,
/// 后面的步骤不再做(尤其不要在没进 raw mode 的终端上写 alt screen)。
fn TerminalState::open_session(self : TerminalState, tty : Tty) -> String? {
  match tty.enter_raw() {
    Some(reason) => return Some(reason)
    None => ()
  }
  match tty.install_signal_handlers() {
    Some(reason) => return Some(reason)
    None => ()
  }
  // `modes_active` 只在写成功之后置位:退出时不对没开过的模式发关闭序列,
  // 也不对着没切过去的 alt screen 发离开序列。
  self.enter_modes(tty)
}

///|
/// 绑渲染会话。返回 `String?`:None 是成功,Some 是可直接展示的拒绝原因。
fn TerminalState::attach(
  self : TerminalState,
  input : TerminalInput,
  tty : Tty,
) -> String? {
  let sink = @tui_renderer.TuiSink::new(description="terminal stdout", write=text => {
    // 出口必须是纯函数,所以失败不抛出而是登记:主循环在帧末取出它,
    // 先还原终端再退出。丢在这里不报的原因,用户看到的是画面静止。
    match tty.write_text(text) {
      Some(reason) => self.write_failure = Some(reason)
      None => ()
    }
  })
  let surface = @render.HostSurface::new(
    surface_id="terminal",
    metrics=input.metrics(),
  )
  match @tui_renderer.ansi(sink~, cell=input.cell).bind_surface(surface) {
    Bound(session) => {
      match self.session {
        Some(previous) => previous.dispose()
        None => ()
      }
      self.session = Some(session)
      match self.driver {
        Some(driver) => driver.set_text_system(session.text_system())
        None => ()
      }
      self.needs_render = true
      self.surface_generation = self.surface_generation + 1
      self.next_sequence = 1
      None
    }
    Rejected(reason) => Some(reason)
  }
}

///|
/// 开启协议字节。`modes_active` 只在写成功之后置位:退出时不对没开过的模式
/// 发关闭序列,也不对着没切过去的 alt screen 发离开序列。
fn TerminalState::enter_modes(self : TerminalState, tty : Tty) -> String? {
  let failure = tty.write_text(ENTER_MODES)
  if failure is None {
    self.modes_active = true
  }
  failure
}

///|
/// 输入泵:等字节 → 解码 → 派发 → (resize?) → 重画,直到应用请求关闭、收到
/// 退出信号或终端不可用。三条都走同一个 `outcome`/`shutdown`,所以 Ctrl-C 与
/// 应用自关闭在「把终端交回去」这件事上没有区别。
fn TerminalState::pump(
  self : TerminalState,
  idle_timeout_ms~ : Int,
) -> TerminalExit {
  let tty = match self.tty {
    Some(tty) => tty
    None => return SetupFailed("终端宿主状态未初始化")
  }
  let decoder = match self.decoder {
    Some(decoder) => decoder
    None => return SetupFailed("输入解码器未初始化")
  }
  // 首帧在进入等待之前画:否则界面要等一个 idle 周期才出现。
  self.render_frame()
  let mut outcome : TerminalExit = Closed
  let mut running = true
  while running {
    match tty.wait(timeout_ms=idle_timeout_ms) {
      Ready => {
        let bytes = tty.take_input()
        if bytes.is_empty() {
          // poll 说可读而 read 给 0 字节:输入端已关闭(管道结束 / hangup)。
          running = false
        } else {
          for event in decoder.feed_bytes(bytes) {
            self.deliver(event)
          }
        }
      }
      Timeout =>
        // 数据流停了:把只能靠超时消歧的裸 ESC 结算成 Escape 键。
        match decoder.flush() {
          Some(event) => self.deliver(event)
          None => ()
        }
      Unavailable => running = false
    }
    // SIGWINCH 会在 poll 里把等待打断成 Timeout,也会在处理输入期间到达:
    // 两条都在这一次重排里生效,重画永远用新网格而不是旧布局。
    if tty.take_resize_signal() {
      self.reflow(tty)
    }
    self.render_frame()
    match self.write_failure {
      Some(reason) => {
        outcome = WriteFailed(reason)
        running = false
      }
      None => ()
    }
    // 退出信号走的是标志而不是按键:raw mode 有意保留 ISIG,所以 Ctrl-C 到不了
    // 解码器。放在写帧之后,保证最后一帧不会被跳过;放在 close_requested 之前,
    // 让还原路径始终是同一条 shutdown。
    if tty.terminate_requested() {
      running = false
    }
    if self.close_requested {
      running = false
    }
  }
  outcome
}

///|
/// 一条终端事实立刻走完派发:不等下一批输入,所以「按下即响应」不依赖
/// Enter 或文本提交。`to_host` 给 None 表示这条事实不该进入应用(按钮号与
/// 相位矛盾、能力表关掉了某条通道)。
fn TerminalState::deliver(self : TerminalState, event : TerminalEvent) -> Unit {
  let host_event = match self.input {
    Some(input) => input.to_host(event)
    None => None
  }
  match (self.driver, host_event) {
    (Some(driver), Some(event)) => {
      let result = driver.dispatch(event)
      if result.needs_redraw {
        self.needs_render = true
      }
      if result.close_requested {
        self.close_requested = true
      }
    }
    _ => ()
  }
}

///|
/// 尺寸通道:一次 resize 做两件事——把新度量交给渲染会话重建栅格,把
/// `Resized` 交给运行时走完整 update→layout→present。只重画旧布局会留下
/// 错格的分栏边界,那只差一次重排而不是差一次渲染。
fn TerminalState::reflow(self : TerminalState, tty : Tty) -> Unit {
  match (self.input, self.session, self.driver, tty.grid()) {
    (Some(input), Some(session), Some(driver), Some((cols, rows))) => {
      let event = input.resize(cols, rows)
      session.resize(input.metrics())
      let result = driver.dispatch(event)
      if result.close_requested {
        self.close_requested = true
      }
      // 栅格换了行列,可视区之外的旧字符不会被任何增量写覆盖:整屏重画一次,
      // 清屏由 damage 的 full 分支(`ESC[2J` + 归位)做。
      self.needs_render = true
    }
    _ => ()
  }
}

///|
/// 帧泵:一次 redraw 一个 token,会话按 token 判断该画还是该跳过。
/// 零增量帧不写一个字节,这是增量通路生效的证据而不是失败。
fn TerminalState::render_frame(self : TerminalState) -> Unit {
  if !self.needs_render {
    return
  }
  self.needs_render = false
  match (self.driver, self.session) {
    (Some(driver), Some(session)) => {
      driver.begin_redraw()
      let frame = driver.draw_frame()
      let token = @render.FrameToken::new(
        surface_generation=self.surface_generation,
        sequence=self.next_sequence,
      )
      self.next_sequence = self.next_sequence + 1
      let _ = session.render_frame(
        @render.RenderFrameSubmission::new(token~, frame~),
      )
      driver.finish_redraw()
    }
    _ => ()
  }
}

///|
/// 还原:先关鼠标与键盘协议,再显示光标、退 alt screen,最后还原 termios。
/// 顺序反了会让 alt screen 恢复期间终端的回复(光标位置报告等)当成按键
/// 派发给已经不存在的应用。写失败在这里忽略:此刻唯一要紧的是把终端交回去,
/// stdout 已经关掉时也必须继续还原 termios,否则 shell 会被留在 raw mode。
fn TerminalState::shutdown(self : TerminalState, tty : Tty) -> Unit {
  if self.modes_active {
    self.modes_active = false
    let _ = tty.write_text(EXIT_MODES)
  }
  tty.restore()
  match self.session {
    Some(session) => session.dispose()
    None => ()
  }
  self.session = None
  self.driver = None
  self.input = None
  self.decoder = None
  self.tty = None
  self.needs_render = false
  self.close_requested = false
  self.write_failure = None
}
