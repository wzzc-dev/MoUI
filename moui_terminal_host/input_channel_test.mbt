///|
/// 三条输入通道的表驱动测试:每条终端事实必须原样落到宿主事件里,一条都不许被吞。
///
/// 全部对着内存里的事件结构写,不需要真 TTY——`decode_test.mbt` 证明字节能解成
/// 事实,这里证明事实能变成应用看得见的事件。S3 判据里的三段各有归属:
/// - 键盘:`pressed`/`repeat`/`modifiers` 透传,且按键不带文本;
/// - 鼠标:SGR 按钮号对照 + cell→逻辑像素换算,矛盾事实才丢弃;
/// - 尺寸:resize 产出的是完整视口事实,不是内部重画。
fn make_input(
  cols~ : Int32,
  rows~ : Int32,
  cell~ : @tui_renderer.CellBox = @tui_renderer.CellBox::default(),
) -> @moui_terminal_host.TerminalInput {
  @moui_terminal_host.TerminalInput::new(cols~, rows~, cell~)
}

///|
/// 通道吞掉事实时直接失败,而不是让断言对着 `None` 报一个看不出原因的差异。
fn delivered(
  input : @moui_terminal_host.TerminalInput,
  event : @moui_terminal_host.TerminalEvent,
) -> @backend_host.Event {
  match input.to_host(event) {
    Some(event) => event
    None => abort("输入通道吞掉了这条事实")
  }
}

///|
fn keyboard_of(
  event : @backend_host.Event,
  context : String,
) -> @core.KeyboardEvent {
  match event {
    @backend_host.Keyboard(key) => key
    _ => abort("期望按键事件:" + context)
  }
}

///|
fn pointer_of(
  event : @backend_host.Event,
  context : String,
) -> @core.PointerEvent {
  match event {
    @backend_host.Pointer(pointer) => pointer
    _ => abort("期望指针事件:" + context)
  }
}

///|
fn key_event(
  key~ : String,
  text~ : String? = None,
  pressed~ : Bool = true,
  repeat~ : Bool = false,
  modifiers~ : @core.KeyModifiers = @core.KeyModifiers::none(),
) -> @moui_terminal_host.TerminalEvent {
  @moui_terminal_host.Key(
    @core.KeyboardEvent::new(key~, text~, pressed~, repeat~, modifiers~),
  )
}

///|
fn mouse_event(
  col~ : Int32,
  row~ : Int32,
  button~ : Int32,
  phase~ : @moui_terminal_host.MousePhase,
  modifiers~ : @core.KeyModifiers = @core.KeyModifiers::none(),
) -> @moui_terminal_host.TerminalEvent {
  @moui_terminal_host.Mouse({
    position: { col, row, },
    button,
    phase,
    modifiers,
  })
}

///|
fn wheel_event(
  col~ : Int32,
  row~ : Int32,
  up~ : Bool,
  modifiers~ : @core.KeyModifiers = @core.KeyModifiers::none(),
) -> @moui_terminal_host.TerminalEvent {
  @moui_terminal_host.Wheel({ position: { col, row, }, up, modifiers, })
}

///|
test "按键通道不携带文本,插入只由文本通道报一次" {
  let input = make_input(cols=80, rows=24)
  // 终端把可打印字符同时解成按键与文本(kitty 与 legacy 都如此),两条通道各取一半。
  let press = keyboard_of(
    delivered(input, key_event(key="a", text=Some("a"))),
    "可打印按键",
  )
  assert_eq(press.key, "a")
  assert_eq(press.pressed, true)
  // 两边都带文本会让焦点文本框把同一个字符插两遍(它读 event.text)。
  assert_eq(press.text, None)
  assert_eq(
    delivered(
      input,
      @moui_terminal_host.Text(@core.TextInputEvent::InsertText("a")),
    ),
    @backend_host.TextInput(@core.TextInputEvent::InsertText("a")),
  )
}

///|
test "按下/重复/释放三态与修饰键原样进入应用" {
  let input = make_input(cols=80, rows=24)
  let press = keyboard_of(
    delivered(input, key_event(key="ArrowDown")),
    "按下",
  )
  assert_eq((press.pressed, press.repeat), (true, false))
  // 长按重复由终端在 kitty flag 2 下单独编码:与按下同键但 repeat=true,
  // 列表据此才能区分「一次跳一格」与「按住连跳」。
  let repeat = keyboard_of(
    delivered(input, key_event(key="ArrowDown", repeat=true)),
    "重复",
  )
  assert_eq((repeat.pressed, repeat.repeat), (true, true))
  // 释放同样送达:只报按下的通道会让按下/释放成对的控件停在按下态。
  let release = keyboard_of(
    delivered(input, key_event(key="ArrowDown", pressed=false)),
    "释放",
  )
  assert_eq((release.pressed, release.repeat), (false, false))
  // 修饰键是这一次按键的事实,必须覆盖通道里的当前状态。
  let alt = keyboard_of(
    delivered(
      input,
      key_event(key="ArrowDown", modifiers=@core.KeyModifiers::new(alt=true)),
    ),
    "Alt+方向键",
  )
  assert_eq(alt.modifiers, @core.KeyModifiers::new(alt=true))
  // 上一条的修饰键不该渗到下一条:无修饰的方向键仍是无修饰。
  let plain = keyboard_of(
    delivered(input, key_event(key="ArrowUp")),
    "后续无修饰按键",
  )
  assert_eq(plain.modifiers, @core.KeyModifiers::none())
}

///|
test "cell 坐标换算成格心,末行末列仍在视口内" {
  let input = make_input(cols=80, rows=24)
  // cell(11,3) → 逻辑像素格心:(11.5*8, 3.5*16)。
  let click = pointer_of(
    delivered(
      input,
      mouse_event(col=11, row=3, button=0, phase=@moui_terminal_host.Press),
    ),
    "点击",
  )
  assert_eq(click.position, @core.Point::new(x=92.0, y=56.0))
  assert_eq(click.phase, @core.PointerPhase::Down)
  // 取格心而不是左上角:正好落在最后一格时,左上角会差出一格、格心不会越出视口。
  let last = input.point_of({ col: 79, row: 23, })
  assert_eq(last, @core.Point::new(x=636.0, y=376.0))
  let metrics = input.metrics()
  assert_eq(
    last.x <= metrics.logical_size.width &&
    last.y <= metrics.logical_size.height,
    true,
  )
  // 视口度量就是 cell 栅格本身:渲染器数出的行列与点击换算用的是同一套尺寸。
  assert_eq(@tui_renderer.CellBox::default().cols_of(metrics), 80)
  assert_eq(@tui_renderer.CellBox::default().rows_of(metrics), 24)
}

///|
test "SGR 按钮号与核心按钮号对照" {
  let input = make_input(cols=80, rows=24)
  // 终端 0 左 1 中 2 右,核心 0 左 1 右 2 中:直接透传会把中键与右键互换。
  let left = pointer_of(
    delivered(
      input,
      mouse_event(col=1, row=1, button=0, phase=@moui_terminal_host.Press),
    ),
    "左键按下",
  )
  assert_eq((left.button, left.phase), (0, @core.PointerPhase::Down))
  let middle = pointer_of(
    delivered(
      input,
      mouse_event(col=1, row=1, button=1, phase=@moui_terminal_host.Press),
    ),
    "中键按下",
  )
  assert_eq((middle.button, middle.phase), (2, @core.PointerPhase::Down))
  let right = pointer_of(
    delivered(
      input,
      mouse_event(col=1, row=1, button=2, phase=@moui_terminal_host.Press),
    ),
    "右键按下",
  )
  assert_eq((right.button, right.phase), (1, @core.PointerPhase::Down))
  let release = pointer_of(
    delivered(
      input,
      mouse_event(col=1, row=1, button=0, phase=@moui_terminal_host.Release),
    ),
    "左键释放",
  )
  assert_eq((release.button, release.phase), (0, @core.PointerPhase::Up))
  // 释放也要带上按下时的修饰键,否则 shift 拖动选区在抬起时失效。
  let shift_release = pointer_of(
    delivered(
      input,
      mouse_event(
        col=1,
        row=1,
        button=0,
        phase=@moui_terminal_host.Release,
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
    "Shift 左键释放",
  )
  assert_eq(shift_release.modifiers, @core.KeyModifiers::new(shift=true))
}

///|
test "拖动报位置变化,无键移动不报按下或释放" {
  let input = make_input(cols=80, rows=24)
  let drag = pointer_of(
    delivered(
      input,
      mouse_event(col=5, row=6, button=0, phase=@moui_terminal_host.Drag),
    ),
    "拖动",
  )
  // 是否算拖拽由运行时的指针捕获状态决定,和桌面端一致。
  assert_eq(drag.phase, @core.PointerPhase::Move)
  assert_eq(drag.position, @core.Point::new(x=44.0, y=104.0))
  // 1003 无键移动必须仍是 Move:悬停高亮只有这一个来源,吞掉它等于关掉整条鼠标通道。
  let hover = pointer_of(
    delivered(
      input,
      mouse_event(col=5, row=6, button=3, phase=@moui_terminal_host.Drag),
    ),
    "无键移动",
  )
  assert_eq(hover.phase, @core.PointerPhase::Move)
  assert_eq(hover.position, @core.Point::new(x=44.0, y=104.0))
  // 但 button=3 配按下/释放是矛盾事实:报成按下会让控件凭空进入按下态。
  assert_eq(
    input.to_host(
      mouse_event(col=5, row=6, button=3, phase=@moui_terminal_host.Press),
    ),
    None,
  )
  assert_eq(
    input.to_host(
      mouse_event(col=5, row=6, button=3, phase=@moui_terminal_host.Release),
    ),
    None,
  )
}

///|
test "滚轮一格等于一行,方向与修饰键保住" {
  let input = make_input(cols=80, rows=24)
  let up = pointer_of(
    delivered(input, wheel_event(col=4, row=8, up=true)),
    "向上滚",
  )
  assert_eq(up.phase, @core.PointerPhase::Move)
  assert_eq(up.position, @core.Point::new(x=36.0, y=136.0))
  // 正向 y 让内容下移(与 text_area_viewport 的约定一致),所以向上滚给正增量。
  assert_eq(up.wheel_delta, @core.Point::new(x=0.0, y=16.0))
  let down = pointer_of(
    delivered(input, wheel_event(col=4, row=8, up=false)),
    "向下滚",
  )
  assert_eq(down.wheel_delta, @core.Point::new(x=0.0, y=-16.0))
  // 不走 Scroll 包装:那条线把行高写死成像素常量并丢掉修饰键。
  let control = pointer_of(
    delivered(
      input,
      wheel_event(
        col=4,
        row=8,
        up=true,
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
    "Ctrl+滚轮",
  )
  assert_eq(control.modifiers, @core.KeyModifiers::new(control=true))
  // 滚轮一格按当前 cell 高度换算:cell 尺寸变了,一格就该是一行,而不是固定像素。
  let wide = make_input(
    cols=40,
    rows=20,
    cell=@tui_renderer.CellBox::new(width=10.0, height=20.0),
  )
  assert_eq(
    pointer_of(
      delivered(wide, wheel_event(col=0, row=0, up=true)),
      "宽 cell 滚轮",
    ).wheel_delta,
    @core.Point::new(x=0.0, y=20.0),
  )
}

///|
test "resize 产出完整视口事实并按新栅格换算" {
  let input = make_input(cols=80, rows=24)
  // resize 的载荷是新的 SurfaceMetrics:运行时据此走完整 update→layout→present,
  // 渲染会话据此重算行列——只报「内部重画」的事件类型做不到这件事。
  let event = input.resize(40, 10)
  match event {
    @backend_host.Resized(metrics) => {
      assert_eq(
        metrics.logical_size,
        @core.Size::new(width=320.0, height=160.0),
      )
      assert_eq(metrics.scale_factor, 1.0)
    }
    _ => abort("期望 Resized 事件")
  }
  // 通道自身记住新视口:后续点击仍按最新尺寸换算。
  let click = pointer_of(
    delivered(
      input,
      mouse_event(col=39, row=9, button=0, phase=@moui_terminal_host.Press),
    ),
    "resize 后的末格点击",
  )
  assert_eq(click.position, @core.Point::new(x=316.0, y=152.0))
  let metrics = input.metrics()
  assert_eq(@tui_renderer.CellBox::default().cols_of(metrics), 40)
  assert_eq(@tui_renderer.CellBox::default().rows_of(metrics), 10)
}
