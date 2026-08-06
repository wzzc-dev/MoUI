///|
/// 端到端复制链路:注入屏幕内容 → 拖选 → ⌘+C → 剪贴板写入选中文本。
/// 测试结束恢复原剪贴板内容。
async test "drag select and cmd-c copies selection to clipboard" {
  let original = @macos_host.macos_clipboard_read_text()
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
  // 等 init effect 捕获 dispatch
  for _ in 0..<100 {
    if dispatch_ref.val is Some(_) {
      break
    }
    @async.sleep(5)
  }
  match dispatch_ref.val {
    Some(dispatch) => {
      // 注入屏幕内容(等价于 worker 读到的 shell 输出)
      dispatch(@app.Msg::Feed(@utf8.encode("hello world\r\n")))
      // 渲染一次(元素树/布局就绪)
      ignore(runtime.draw_commands())
      ignore(runtime.focus_next())
      // 拖选第一行 "hello world"(0,0)→(0,11)
      let down = @core.Point::new(x=5.0, y=10.0)
      let up = @core.Point::new(x=110.0, y=10.0)
      ignore(
        runtime.dispatch_pointer_input(
          @core.PointerEvent::new(position=down, phase=@core.PointerPhase::Down),
        ),
      )
      ignore(
        runtime.dispatch_pointer_input(
          @core.PointerEvent::new(position=up, phase=@core.PointerPhase::Move),
        ),
      )
      ignore(
        runtime.dispatch_pointer_input(
          @core.PointerEvent::new(position=up, phase=@core.PointerPhase::Up),
        ),
      )
      // ⌘+C:复制(不写入 PTY)
      let meta = @core.KeyModifiers::new(meta=true)
      runtime.dispatch_event(
        @core.AppEvent::Keyboard(
          @core.KeyboardEvent::new(key="c", modifiers=meta),
        ),
      )
      // PTY 不应收到任何输入
      let mut wrote_to_pty = false
      for _ in 0..<8 {
        match (input_queue.try_get() catch { _ => None }) {
          Some(InputWork::Write(_)) => wrote_to_pty = true
          Some(InputWork::Shutdown) => ()
          None => ()
        }
        if wrote_to_pty {
          break
        }
      }
      inspect(wrote_to_pty, content="false")
      // 剪贴板应包含选中文本
      match @macos_host.macos_clipboard_read_text() {
        Some(text) => inspect(text, content="hello world")
        None => fail("clipboard should contain text")
      }
    }
    None => fail("dispatch not captured")
  }
  // 恢复原剪贴板(原为空时写入空串清空)
  match original {
    Some(text) => ignore(@macos_host.macos_clipboard_write_text(text))
    None => ignore(@macos_host.macos_clipboard_write_text(""))
  }
  pty.close()
}

///|
/// ⌘+C 在无选择时不应产生任何效果(不写剪贴板、不写 PTY)。
async test "cmd-c without selection does not write clipboard" {
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
  let before = @macos_host.macos_clipboard_read_text()
  ignore(runtime.draw_commands())
  ignore(runtime.focus_next())
  let meta = @core.KeyModifiers::new(meta=true)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="c", modifiers=meta)),
  )
  let after = @macos_host.macos_clipboard_read_text()
  inspect(after == before, content="true")
  pty.close()
}
