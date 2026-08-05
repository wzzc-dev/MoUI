///|
test "host driver maps focused text input through core text input event" {
  let text = @core.State::new("")
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0, outlined=true),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  ignore(
    driver.dispatch(
      @backend_host.Event::TextInput(@core.TextInputEvent::InsertText("a")),
    ),
  )
  inspect(text.get(), content="")
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
  let result = driver.dispatch(
    @backend_host.Event::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.get(), content="a")
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver routes text clipboard commands through service bridge" {
  let text = @core.State::new("")
  let clipboard = Ref("")
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
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
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
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
test "host driver keyboard paste replaces selection with extended emoji" {
  let text = @core.State::new("")
  let clipboard = Ref("☕️👩‍💻")
  let runtime = window_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::ReadText
        ) => @backend_host.HostServiceResponse::ClipboardText(clipboard.val)
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
      @backend_host.Event::TextInput(
        @core.TextInputEvent::InsertText("replace"),
      ),
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
  let runtime = window_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[@core.ActionCommand::new(intent=@core.CommandIntent::Copy)],
    on_message=_ => copied.val = copied.val + 1,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
    handle=_request => @backend_host.HostServiceResponse::ClipboardWritten,
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
  let queue = ServiceAsyncQueue::new()
  let runtime = window_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[@core.ActionCommand::new(intent=@core.CommandIntent::Paste)],
    on_message=_ => pasted.val = pasted.val + 1,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = @backend_host.HostServiceBridge::new(
    capabilities=@backend_host.HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      match request {
        @backend_host.HostServiceRequest::Clipboard(
          @backend_host.HostClipboardRequest::ReadText
        ) => queue.submit(request)
        _ =>
          @backend_host.HostServiceResponse::Unavailable("unexpected request")
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
    queue.complete(
      pending[0].id,
      @backend_host.HostServiceResponse::ClipboardText("delayed"),
    ),
  )
  for completion in queue.drain_completed() {
    ignore(driver.dispatch_service_completion(completion, bridge))
  }
  inspect(pasted.val, content="1")
}
