///|
test "host driver includes focused text commands in context menu" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let saw_copy_command = Ref(false)
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true, menus=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        ShowMenu(commands) => {
          saw_copy_command.val = commands.any(command => {
            command.intent == @core.CommandIntent::Copy
          })
          HostServiceResponse::MenuCommand(@core.CommandIntent::Copy)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::Keyboard(
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
  let text = @core.State::new("")
  let copy_enabled = Ref(true)
  let cut_enabled = Ref(true)
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            if command.intent == @core.CommandIntent::Copy {
              copy_enabled.val = command.enabled
            } else if command.intent == @core.CommandIntent::Cut {
              cut_enabled.val = command.enabled
            }
          }
          HostServiceResponse::Unavailable("cancelled")
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
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
  let text = @core.State::new("")
  let copy_enabled = Ref(false)
  let cut_enabled = Ref(false)
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            if command.intent == @core.CommandIntent::Copy {
              copy_enabled.val = command.enabled
            } else if command.intent == @core.CommandIntent::Cut {
              cut_enabled.val = command.enabled
            }
          }
          HostServiceResponse::Unavailable("cancelled")
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      HostEvent::Keyboard(
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
  let text = @core.State::new("")
  let clipboard = Ref("你🙂")
  let saw_paste_command = Ref(false)
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true, menus=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        ShowMenu(commands) => {
          saw_paste_command.val = commands.any(command => {
            command.intent == @core.CommandIntent::Paste
          })
          HostServiceResponse::MenuCommand(@core.CommandIntent::Paste)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(driver.show_context_menu(bridge))
  inspect(saw_paste_command.val, content="true")
  inspect(text.get(), content="你🙂")
  inspect(driver.focused_text_input().caret, content="2")
}
