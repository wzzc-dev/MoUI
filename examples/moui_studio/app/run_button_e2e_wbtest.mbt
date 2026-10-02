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
    environment=@services.AppEnvironment::new(timer=Some(
      fake_timer_source(sink, registered),
    )),
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
    (sink.val)(@core.Frame::new(time_ms=index.to_double() * 30.0, delta_ms=30.0))
  }
  // 运行视图出现（ModeRun 全屏页的标志文本）
  let mut in_run_view = false
  for command in runtime.draw_commands() {
    match command {
      @core.DrawText(run) => if run.text.contains("运行") { in_run_view = true }
      _ => ()
    }
  }
  assert_true(in_run_view)
}
