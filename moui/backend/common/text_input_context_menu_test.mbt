///|
test "host driver includes focused text commands in context menu" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let saw_copy_command = Ref(false)
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
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
        @backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::WriteText(value)
        ) => {
          clipboard.val = value
          @backend_host.HostServiceResponse::ClipboardWritten
        }
        @backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::ReadText
        ) => @backend_host.HostServiceResponse::ClipboardText(clipboard.val)
        @backend_host.HostServiceRequest::ShowMenu(commands) => {
          saw_copy_command.val = commands.any(command => {
            command.intent == @core.CommandIntent::Copy
          })
          @backend_host.HostServiceResponse::MenuCommand(
            @core.CommandIntent::Copy,
          )
        }
        _ =>
          @backend_host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::Keyboard(
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
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        @backend_host.HostServiceRequest::ShowMenu(commands) => {
          for command in commands {
            if command.intent == @core.CommandIntent::Copy {
              copy_enabled.val = command.enabled
            } else if command.intent == @core.CommandIntent::Cut {
              cut_enabled.val = command.enabled
            }
          }
          @backend_host.HostServiceResponse::Unavailable("cancelled")
        }
        _ =>
          @backend_host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::Pointer(
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
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        @backend_host.HostServiceRequest::ShowMenu(commands) => {
          for command in commands {
            if command.intent == @core.CommandIntent::Copy {
              copy_enabled.val = command.enabled
            } else if command.intent == @core.CommandIntent::Cut {
              cut_enabled.val = command.enabled
            }
          }
          @backend_host.HostServiceResponse::Unavailable("cancelled")
        }
        _ =>
          @backend_host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::TextInput(@core.TextInputEvent::InsertText("hello")),
    ),
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::Keyboard(
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
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
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
        @backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::ReadText
        ) => @backend_host.HostServiceResponse::ClipboardText(clipboard.val)
        @backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::WriteText(value)
        ) => {
          clipboard.val = value
          @backend_host.HostServiceResponse::ClipboardWritten
        }
        @backend_host.HostServiceRequest::ShowMenu(commands) => {
          saw_paste_command.val = commands.any(command => {
            command.intent == @core.CommandIntent::Paste
          })
          @backend_host.HostServiceResponse::MenuCommand(
            @core.CommandIntent::Paste,
          )
        }
        _ =>
          @backend_host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(
    driver.dispatch(
      @backend_host.Event::Pointer(
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
