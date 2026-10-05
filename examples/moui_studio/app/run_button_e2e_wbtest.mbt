///|
/// 假 TimerSource：捕获订阅回调，测试里手动泵帧。
fn fake_timer_source(
  sink : Ref[(@core.Frame) -> Unit],
  registered : Ref[Bool],
) -> @services.TimerSource {
  @services.TimerSource::new(start=fn(_interval, callback) {
    sink.val = callback
    registered.val = true
    None
  })
}

///|
/// 端到端复现：真实 program() 运行时里点顶栏「运行」——
/// 期望按钮翻转为「停止」且进入运行视图（ModeRun）。
test "click topbar run button starts the run (e2e)" {
  let sink : Ref[(@core.Frame) -> Unit] = Ref(fn(_frame) { () })
  let registered : Ref[Bool] = Ref(false)
  let studio_program = program(
    environment=@services.AppEnvironment::new(
      timer=Some(fake_timer_source(sink, registered)),
    ),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=studio_program,
    width=1280.0,
    height=800.0,
  )
  // 初始帧里应画着「运行」
  let commands = runtime.draw_commands()
  let mut run_frame : @core.Rect? = None
  for command in commands {
    match command {
      @core.DrawText(run) =>
        if run.text == "运行" {
          run_frame = Some(run.frame)
        }
      _ => ()
    }
  }
  guard run_frame is Some(frame) else {
    fail("初始视图没有「运行」按钮文本")
  }
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.Pointer(@core.PointerEvent::new(position=center, phase=@core.Down)),
  )
  runtime.dispatch_event(
    @core.Pointer(@core.PointerEvent::new(position=center, phase=@core.Up)),
  )
  // 点击后：按钮应翻转为「停止」（说明 RunStart 已派发并生效）
  let mut stop_seen = false
  let mut run_seen = false
  for command in runtime.draw_commands() {
    match command {
      @core.DrawText(run) => {
        if run.text == "停止" {
          stop_seen = true
        }
        if run.text == "运行" {
          run_seen = true
        }
      }
      _ => ()
    }
  }
  assert_true(stop_seen)
  assert_false(run_seen)
  // 关键验证：RunStart 后 30ms RunTick 订阅必须激活——否则程序永不推进，
  // 用户看到的就是「点了运行没反应」（按钮翻了但舞台冻结）。
  // 订阅必须已注册（假 timer 的 start 被调用 = 回调被捕获）
  assert_true(registered.val)
  // 泵 60 帧（30ms × 60 ≈ 2s）：解释轨应推进
  for index in 0..<60 {
    (sink.val)(
      @core.Frame::new(time_ms=index.to_double() * 30.0, delta_ms=30.0),
    )
  }
  // 运行视图出现（ModeRun 全屏页的标志文本）
  let mut in_run_view = false
  for command in runtime.draw_commands() {
    match command {
      @core.DrawText(run) =>
        if run.text.contains("运行") {
          in_run_view = true
        }
      _ => ()
    }
  }
  assert_true(in_run_view)
}

///|
/// 端到端复现用户报的两个运行页缺陷：
/// ① 「运行」**装填不执行**——运行页舞台是设计的初始值（标签为空），
///    点了舞台上的「点我」按钮标签才出现问候语；
/// ② 运行页底栏（AI 输入条）**铺满中心列整行**——全屏页没有左右栏，
///    底栏不能再按「扣掉左右栏」的 center_width 定宽（右侧留一条空白）。
test "run arms the stage with empty label; bottom bar spans the full width (e2e)" {
  let sink : Ref[(@core.Frame) -> Unit] = Ref(fn(_frame) { () })
  let registered : Ref[Bool] = Ref(false)
  let runtime = @runtime.new_program_with_dimensions(
    program=program(
      environment=@services.AppEnvironment::new(
        timer=Some(fake_timer_source(sink, registered)),
      ),
    ),
    width=1280.0,
    height=800.0,
  )
  let click_text = fn(runtime : @runtime.AppRuntime, needle : String) {
    let commands = runtime.draw_commands()
    let mut frame : @core.Rect? = None
    for command in commands {
      match command {
        // **精确匹配**：contains 会点到「运行审计」页签（它也含「运行」），
        // 顶栏按钮的文案就是整词「运行」。
        @core.DrawText(run) => if run.text == needle { frame = Some(run.frame) }
        _ => ()
      }
    }
    match frame {
      Some(rect) => {
        let center = @core.Point::new(
          x=rect.origin.x + rect.size.width / 2.0,
          y=rect.origin.y + rect.size.height / 2.0,
        )
        runtime.dispatch_event(
          @core.Pointer(
            @core.PointerEvent::new(position=center, phase=@core.Down),
          ),
        )
        runtime.dispatch_event(
          @core.Pointer(
            @core.PointerEvent::new(position=center, phase=@core.Up),
          ),
        )
        true
      }
      None => false
    }
  }
  let has_text = fn(runtime : @runtime.AppRuntime, needle : String) {
    let mut found = false
    for command in runtime.draw_commands() {
      match command {
        @core.DrawText(run) => if run.text.contains(needle) { found = true }
        _ => ()
      }
    }
    found
  }
  // 点顶栏「运行」→ 运行页
  assert_true(click_text(runtime, "运行"))
  // ① 装填不执行：舞台标签还是空的——问候语**尚未出现**
  assert_false(
    has_text(runtime, "你好，MoUI Studio！"),
    msg="the greeting must not appear before the button is clicked",
  )
  // ② 底栏铺满整行：底栏条带里有面板底色的矩形横贯（宽 ≥ 内容行的 95%）
  let panel = ide_panel()
  let commands = runtime.draw_commands()
  let mut bar_width = 0.0
  for command in commands {
    match command {
      @core.FillRect(rect, color) =>
        // 底栏条带：状态栏之上、内容区之下（y 取窗口下部 1/4）
        if color.r == panel.r &&
          color.g == panel.g &&
          color.b == panel.b &&
          rect.origin.y > 600.0 &&
          rect.size.width > bar_width {
          bar_width = rect.size.width
        }
      @core.FillRoundedRect(rounded, color) => {
        let rect = rounded.rect
        if color.r == panel.r &&
          color.g == panel.g &&
          color.b == panel.b &&
          rect.origin.y > 600.0 &&
          rect.size.width > bar_width {
          bar_width = rect.size.width
        }
      }
      // 容器底色走 brush 变体（与 shell_rects 同一教训：只收非 brush
      // 变体会让「底栏在哪」这类断言全部落空）。
      @core.FillRoundedRectBrush(rounded, @graphics.Brush::Solid(color)) => {
        let rect = rounded.rect
        if color.r == panel.r &&
          color.g == panel.g &&
          color.b == panel.b &&
          rect.origin.y > 600.0 &&
          rect.size.width > bar_width {
          bar_width = rect.size.width
        }
      }
      _ => ()
    }
  }
  assert_true(
    bar_width >= 1232.0 * 0.95,
    msg="bottom bar width=\{bar_width} should span the content row (1232)",
  )
  // 点舞台上的「点我」按钮 → 问候语出现（事件驱动的执行）
  assert_true(click_text(runtime, "点我"))
  // 泵几帧让派发的子程序跑完
  for index in 0..<10 {
    (sink.val)(
      @core.Frame::new(time_ms=index.to_double() * 30.0, delta_ms=30.0),
    )
  }
  assert_true(
    has_text(runtime, "你好，MoUI Studio！"),
    msg="clicking the stage button must show the greeting",
  )
}
