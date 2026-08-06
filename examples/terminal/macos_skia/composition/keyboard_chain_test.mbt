///|
/// 键盘事件全链路(Program 模式):dispatch Ctrl+C 键盘事件 → keyboard 节点
/// 捕获 → 编码 \x03 → WriteInput 消息 → effect 入队 → 队列中出现
/// InputWork::Write("\u{3}")。
async test "ctrl-c keyboard event reaches input queue" {
  let dispatch_ref : Ref[((@app.Msg) -> Unit)?] = Ref(None)
  let input_queue : @async.Queue[InputWork] = @async.Queue(kind=Unbounded)
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let pty = match @pty.Pty::spawn("/bin/sh", 24, 6) {
    Some(value) => value
    None => return
  }
  let runtime = @runtime.AppRuntime::new_program(
    program=terminal_program(pty, dispatch_ref, input_queue, runtime_ref),
    size=@core.Size::new(width=864.0, height=520.0),
  )
  runtime_ref.val = Some(runtime)
  // 先点击终端区域:聚焦 keyboard 节点(与真实用户行为一致)
  let pos = @core.Point::new(x=400.0, y=300.0)
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=pos, phase=@core.PointerPhase::Down),
    ),
  )
  // Ctrl+C 键盘事件
  let ctrl = @core.KeyModifiers::new(control=true)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="c", modifiers=ctrl)),
  )
  // 出队验证
  let mut found = false
  for _ in 0..<8 {
    match (input_queue.try_get() catch { _ => None }) {
      Some(InputWork::Write(text)) => {
        if text == "\u{3}" {
          found = true
        }
        break
      }
      Some(InputWork::Shutdown) => break
      None => break
    }
  }
  inspect(found, content="true")
  pty.close()
}

///|
/// 未点击终端(无焦点)时,Ctrl+C 键盘事件不会到达 keyboard 节点:
/// 队列中不应出现 Write。这是"启动后直接按键无反应"的回归护栏。
async test "keyboard events without focus are not delivered" {
  let dispatch_ref : Ref[((@app.Msg) -> Unit)?] = Ref(None)
  let input_queue : @async.Queue[InputWork] = @async.Queue(kind=Unbounded)
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let pty = match @pty.Pty::spawn("/bin/sh", 24, 6) {
    Some(value) => value
    None => return
  }
  let runtime = @runtime.AppRuntime::new_program(
    program=terminal_program(pty, dispatch_ref, input_queue, runtime_ref),
    size=@core.Size::new(width=864.0, height=520.0),
  )
  runtime_ref.val = Some(runtime)
  let ctrl = @core.KeyModifiers::new(control=true)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="c", modifiers=ctrl)),
  )
  let mut found = false
  for _ in 0..<8 {
    match (input_queue.try_get() catch { _ => None }) {
      Some(InputWork::Write(text)) => {
        if text == "\u{3}" {
          found = true
        }
        break
      }
      Some(InputWork::Shutdown) => break
      None => break
    }
  }
  inspect(found, content="false")
  pty.close()
}

///|
/// 启动自动聚焦(等价于 on_ready 里的 focus_next):不点击终端,
/// Ctrl+C 键盘事件也能到达 keyboard 节点并入队。
async test "auto focus via focus_next enables ctrl-c without click" {
  let dispatch_ref : Ref[((@app.Msg) -> Unit)?] = Ref(None)
  let input_queue : @async.Queue[InputWork] = @async.Queue(kind=Unbounded)
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let pty = match @pty.Pty::spawn("/bin/sh", 24, 6) {
    Some(value) => value
    None => return
  }
  let runtime = @runtime.AppRuntime::new_program(
    program=terminal_program(pty, dispatch_ref, input_queue, runtime_ref),
    size=@core.Size::new(width=864.0, height=520.0),
  )
  runtime_ref.val = Some(runtime)
  // 先触发一次完整渲染(view 树构建;真实运行时 on_ready 时窗口已渲染过)
  let commands = runtime.draw_commands()
  inspect(commands.length() > 0, content="true")
  // 模拟 on_ready 的自动聚焦
  let focused = runtime.focus_next()
  inspect(focused, content="true")
  let ctrl = @core.KeyModifiers::new(control=true)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="c", modifiers=ctrl)),
  )
  let mut found = false
  for _ in 0..<8 {
    match (input_queue.try_get() catch { _ => None }) {
      Some(InputWork::Write(text)) => {
        if text == "\u{3}" {
          found = true
        }
        break
      }
      Some(InputWork::Shutdown) => break
      None => break
    }
  }
  inspect(found, content="true")
  pty.close()
}
