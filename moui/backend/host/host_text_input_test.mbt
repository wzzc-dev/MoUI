///|
test "host driver maps focused text input through core text input event" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(
      text.binding(),
      width=240.0,
      height=40.0,
      outlined=true,
    ),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(
    driver.dispatch(HostEvent::TextInput(@core.TextInputEvent::InsertText("a"))),
  )
  inspect(text.get(), content="")
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
  let result = driver.dispatch(
    HostEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.get(), content="a")
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver routes text clipboard commands through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
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
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Copy, bridge),
  )
  inspect(clipboard.val, content="hello")
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Cut, bridge),
  )
  inspect(text.get(), content="")
  clipboard.val = "world"
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Paste, bridge),
  )
  inspect(text.get(), content="world")
}

///|
test "host driver routes clipboard keyboard shortcuts through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(WriteText(value)) => {
          clipboard.val = value
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
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
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  inspect(clipboard.val, content="hello")
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="")
  clipboard.val = "world"
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="v",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="world")
}

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

///|
test "host driver keyboard paste replaces selection with extended emoji" {
  let text = @core.State::new("")
  let clipboard = Ref("☕️👩‍💻")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => HostServiceResponse::ClipboardText(clipboard.val)
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
      HostEvent::TextInput(@core.TextInputEvent::InsertText("replace")),
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
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="v",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
      bridge,
    ),
  )
  inspect(text.get(), content="☕️👩‍💻")
  inspect(driver.focused_text_input().caret, content="5")
}

///|
test "host driver falls back clipboard shortcuts to action commands" {
  let copied = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Copy),
        handle=() => copied.val = copied.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=_request => HostServiceResponse::ClipboardWritten,
  )
  ignore(
    driver.dispatch_keyboard_with_services(
      @core.KeyboardEvent::new(
        key="c",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
      bridge,
    ),
  )
  inspect(copied.val, content="1")
}

///|
test "host driver defers paste action command while clipboard read is pending" {
  let pasted = Ref(0)
  let queue = HostServiceAsyncQueue::new()
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(intent=@core.CommandIntent::Paste),
        handle=() => pasted.val = pasted.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch_command_with_services(@core.CommandIntent::Paste, bridge),
  )
  inspect(pasted.val, content="0")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(pending[0].id, HostServiceResponse::ClipboardText("delayed")),
  )
  for completion in queue.drain_completed() {
    ignore(driver.dispatch_service_completion(completion, bridge))
  }
  inspect(pasted.val, content="1")
}
