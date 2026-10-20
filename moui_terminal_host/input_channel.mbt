///|
/// 三条输入通道:终端事实 → 宿主事件,一条都不吞。
///
/// 分工按「谁可能知道这个事实」切开:
/// - `decode` 只报终端能表达的:cell 坐标、滚轮一格、原始按钮号、修饰键位;
/// - 这里只补终端不知道的:cell→逻辑像素、按钮编号对照、宿主事件外壳;
/// - 派发时机在 `terminal_host`:每条事实立刻走一次 update→present,
///   所以「按下即响应」不依赖 Enter 或提交。
///
/// 键名与文本分两条事件,和桌面端「按键 + IME 提交」同形:键盘通道只报哪个键、
/// 什么状态,插入只由文本通道报。两边都带文本会让焦点文本框把同一个字符插两遍
/// (它读 `event.text`,见 `moui/views/text/text_input_event_handlers.mbt:234`)。
pub struct TerminalInput {
  input : @window_input.InputState
  surface : @window_input.SurfaceState
  cell : @tui_renderer.CellBox
}

///|
/// SGR 的「无键移动」按钮号:1003 模式下拖动位置位、按钮号为 3,
/// 表示当前没有键按下,不是第 4 个按钮。
const NO_SGR_BUTTON : Int32 = 3

///|
/// 按钮编号对照:终端是 0 左 1 中 2 右,MoUI 核心是 0 左 1 右 2 中
/// (`moui/backend/common/input/window_event_decode.mbt:127`)。
/// 直接透传会把中键和右键互换。
fn sgr_button_to_core(button : Int32) -> Int32 {
  match button {
    1 => 2
    2 => 1
    _ => button
  }
}

///|
/// 终端网格 → 逻辑像素视口。终端没有 DPR,缩放恒为 1:再乘一层只会让
/// 「一格滚轮」和「一格点击」变成需要解释的东西。
fn grid_metrics(
  cols : Int32,
  rows : Int32,
  cell : @tui_renderer.CellBox,
) -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(
      width=cols.to_double() * cell.width,
      height=rows.to_double() * cell.height,
    ),
    scale_factor=1.0,
  )
}

///|
/// 建立输入通道。`cols`/`rows` 来自 `Tty::grid`,所以构造即已知视口尺寸;
/// 宿主必须先用 `metrics` 造 HostSurface,再去绑渲染器——尺寸为 0 的 surface
/// 会被共享的 bind gate 拒绝。
pub fn TerminalInput::new(
  cols~ : Int32,
  rows~ : Int32,
  cell~ : @tui_renderer.CellBox = @tui_renderer.CellBox::default(),
) -> TerminalInput {
  {
    input: @window_input.InputState::new(
      // raw mode 期间本进程独占键盘,没有「窗口失焦」这种事实可报,
      // 所以文本通道从第一步就放行;焦点落在哪个控件由运行时决定。
      focused=true,
      contract=@backend_host.HostInputContract::new(
        capabilities=@backend_host.HostInputCapabilities::new(
          pointer=true,
          scroll=true,
          keyboard=true,
          focus=false,
          text_input=true,
        ),
        coordinates=@backend_host.HostCoordinatePolicy::logical(
          description="Cell centres scaled by the current cell box.",
        ),
      ),
    ),
    surface: @window_input.SurfaceState::new(
      metrics=grid_metrics(cols, rows, cell),
      owns_surface=true,
    ),
    cell,
  }
}

///|
/// 当前视口度量:宿主用它建 HostSurface,并在 resize 后交给渲染会话重排。
pub fn TerminalInput::metrics(self : TerminalInput) -> @core.SurfaceMetrics {
  self.surface.metrics
}

///|
/// 尺寸通道:一次 resize 产出一条新的视口事实。宿主拿到它之后还要做两件事
/// ——让渲染会话按新度量重画,让运行时走完整的 update→layout→present。
pub fn TerminalInput::resize(
  self : TerminalInput,
  cols : Int32,
  rows : Int32,
) -> @backend_host.Event {
  self.surface.resize(grid_metrics(cols, rows, self.cell))
}

///|
/// cell 坐标 → 逻辑像素,取格心。取左上角会让「正好落在格子边界」的盒差一格;
/// 格心恒在自己量化盒内部,末行末列也不会越出视口。
pub fn TerminalInput::point_of(
  self : TerminalInput,
  position : CellPosition,
) -> @core.Point {
  @core.Point::new(
    x=(position.col.to_double() + 0.5) * self.cell.width,
    y=(position.row.to_double() + 0.5) * self.cell.height,
  )
}

///|
/// 一条终端事实换算成宿主事件。`None` 只发生在「这条事实不该进入应用」:
/// 按钮号与相位矛盾(无键却报按下/释放),或能力表关掉了某条通道。
pub fn TerminalInput::to_host(
  self : TerminalInput,
  event : TerminalEvent,
) -> @backend_host.Event? {
  match event {
    Key(key) => self.keyboard(key)
    Text(text) => self.input.text_event(text)
    Mouse(mouse) => self.pointer(mouse)
    Wheel(wheel) => Some(self.wheel(wheel))
  }
}

///|
fn TerminalInput::keyboard(
  self : TerminalInput,
  key : @core.KeyboardEvent,
) -> @backend_host.Event? {
  // 修饰键是这一次按键的事实,而 `keyboard_event` 盖的是当前状态,所以先落地。
  self.input.set_modifiers(key.modifiers)
  self.input.keyboard_event(key=key.key, pressed=key.pressed, repeat=key.repeat)
}

///|
fn TerminalInput::pointer(
  self : TerminalInput,
  mouse : MouseReport,
) -> @backend_host.Event? {
  let position = self.point_of(mouse.position)
  let modifiers = mouse.modifiers
  match mouse.phase {
    Drag =>
      // 拖动只报「位置变了」,是否算拖拽由运行时的指针捕获状态决定;
      // 桌面端也这么发(window_event_decode.mbt:223)。
      Some(Pointer(@core.PointerEvent::new(position~, phase=Move, modifiers~)))
    Press if mouse.button != NO_SGR_BUTTON =>
      Some(
        Pointer(
          @core.PointerEvent::new(
            position~,
            phase=Down,
            button=sgr_button_to_core(mouse.button),
            modifiers~,
          ),
        ),
      )
    Release if mouse.button != NO_SGR_BUTTON =>
      Some(
        Pointer(
          @core.PointerEvent::new(
            position~,
            phase=Up,
            button=sgr_button_to_core(mouse.button),
            modifiers~,
          ),
        ),
      )
    _ => None
  }
}

///|
fn TerminalInput::wheel(
  self : TerminalInput,
  wheel : WheelReport,
) -> @backend_host.Event {
  // 一格滚轮 = 一行:增量按当前 cell 高度换算。不走 `Scroll` 包装,因为那条线
  // 把行高写死成 40 像素并丢掉修饰键(`moui/backend/input_host_state.mbt:150`),
  // 而终端两个事实都要保住。正向 y 让内容下移(`text_area_viewport.mbt:88`),
  // 所以向上滚给正增量。
  let step = if wheel.up { self.cell.height } else { -self.cell.height }
  Pointer(
    @core.PointerEvent::new(
      position=self.point_of(wheel.position),
      phase=Move,
      wheel_delta=@core.Point::new(x=0.0, y=step),
      modifiers=wheel.modifiers,
    ),
  )
}
