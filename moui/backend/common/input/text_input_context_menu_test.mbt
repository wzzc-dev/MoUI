///|
test "host driver includes focused text commands in context menu" {
  let text = Ref("")
  let clipboard = Ref("")
  let saw_copy_command = Ref(false)
  let runtime = window_test_text_field_runtime(
    value=text,
    width=240.0,
    height=40.0,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          ClipboardWritten
        }
        Clipboard(ReadText) => ClipboardText(clipboard.val)
        ShowMenu(commands) => {
          saw_copy_command.val = commands.any(command => command.intent == Copy)
          MenuCommand(Copy)
        }
        _ => Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(driver.dispatch(TextInput(InsertText("hello"))))
  ignore(
    driver.dispatch(
      Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(saw_copy_command.val, content="true")
  inspect(clipboard.val, content="hello")
}

///|
test "host driver disables copy and cut context menu commands without selection" {
  let text = Ref("")
  let copy_enabled = Ref(true)
  let cut_enabled = Ref(true)
  let runtime = window_test_text_field_runtime(
    value=text,
    width=240.0,
    height=40.0,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            if command.intent == Copy {
              copy_enabled.val = command.enabled
            } else if command.intent == Cut {
              cut_enabled.val = command.enabled
            }
          }
          Unavailable("cancelled")
        }
        _ => Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(copy_enabled.val, content="false")
  inspect(cut_enabled.val, content="false")
}

///|
test "host driver enables copy and cut context menu commands with selection" {
  let text = Ref("")
  let copy_enabled = Ref(false)
  let cut_enabled = Ref(false)
  let runtime = window_test_text_field_runtime(
    value=text,
    width=240.0,
    height=40.0,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            if command.intent == Copy {
              copy_enabled.val = command.enabled
            } else if command.intent == Cut {
              cut_enabled.val = command.enabled
            }
          }
          Unavailable("cancelled")
        }
        _ => Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(driver.dispatch(TextInput(InsertText("hello"))))
  ignore(
    driver.dispatch(
      Keyboard(
        @core.KeyboardEvent::new(
          key="a",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(copy_enabled.val, content="true")
  inspect(cut_enabled.val, content="true")
}

///|
test "host driver context menu pastes unicode into focused text input" {
  let text = Ref("")
  let clipboard = Ref("你🙂")
  let saw_paste_command = Ref(false)
  let runtime = window_test_text_field_runtime(
    value=text,
    width=240.0,
    height=40.0,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
    ),
    handle=request => {
      match request {
        Clipboard(ReadText) => ClipboardText(clipboard.val)
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          ClipboardWritten
        }
        ShowMenu(commands) => {
          saw_paste_command.val = commands.any(command => {
            command.intent == Paste
          })
          MenuCommand(Paste)
        }
        _ => Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=Down,
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(saw_paste_command.val, content="true")
  inspect(text.val, content="你🙂")
  inspect(driver.focused_text_input().caret, content="2")
}
