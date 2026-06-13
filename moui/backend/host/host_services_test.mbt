///|
test "host service bridge gates typed platform requests by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(_)) => HostServiceResponse::ClipboardWritten
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("copied")
        ShowMenu(commands) =>
          if commands.length() > 0 {
            HostServiceResponse::MenuCommand(commands[0].intent)
          } else {
            HostServiceResponse::Unavailable("empty menu")
          }
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("not implemented")
      }
    },
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::ReadText),
    ) {
    HostServiceResponse::ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard text")
  }
  match
    bridge.dispatch(
      HostServiceRequest::ShowMenu([
        @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      ]),
    ) {
    HostServiceResponse::MenuCommand(@core.CommandIntent::Copy) => ()
    _ => fail("expected selected menu command")
  }
  match
    bridge.dispatch(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file dialog")
  }
  match
    bridge.dispatch(
      HostServiceRequest::TextFile(HostTextFileRequest::ReadText("/tmp/a.md")),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="text file service is unavailable")
    _ => fail("expected unavailable text file service")
  }
  match
    bridge.dispatch(
      HostServiceRequest::BinaryFile(
        HostBinaryFileRequest::ReadBytes("/tmp/a.pdf"),
      ),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="binary file service is unavailable")
    _ => fail("expected unavailable binary file service")
  }
}

///|
test "host service bridge applies system theme to runtime environment" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(system_theme=true),
    handle=request => {
      match request {
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  match bridge.query_system_theme() {
    Some(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  let environment = @core.Environment::default()
    .with_locale("zh-CN")
    .with_text_scale(1.25)
  let updated = bridge.environment_with_system_theme(environment)
  assert_true(updated.color_scheme == @core.ColorScheme::Dark)
  assert_true(updated.theme.scheme == @core.ColorScheme::Dark)
  inspect(updated.locale, content="zh-CN")
  inspect(updated.text_scale, content="1.25")

  let unavailable = HostServiceBridge::unavailable()
  let unchanged = unavailable.environment_with_system_theme(environment)
  assert_true(unchanged == environment)
}

///|
test "host driver dispatches command intents through runtime action map" {
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
  let result = driver.dispatch(HostEvent::Command(@core.CommandIntent::Copy))
  inspect(copied.val, content="1")
  inspect(result.redraw_requested, content="true")
  match HostEvent::Command(@core.CommandIntent::Copy).to_core() {
    None => ()
    Some(_) => fail("host command should dispatch through runtime action map")
  }
}

///|
test "host driver applies theme change to runtime environment" {
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let result = driver.dispatch(HostEvent::ThemeChanged(@core.ColorScheme::Dark))
  assert_true(runtime.environment().color_scheme == @core.ColorScheme::Dark)
  assert_true(runtime.environment().theme.scheme == @core.ColorScheme::Dark)
  inspect(result.redraw_requested, content="true")
}

///|
test "host driver skips context menu without focused text input" {
  let submitted = Ref(0)
  let saw_menu = Ref(false)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Submit,
          label="Submit",
        ),
        handle=() => submitted.val = submitted.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          saw_menu.val = true
          HostServiceResponse::MenuCommand(commands[0].intent)
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(driver.show_context_menu(services))
  inspect(saw_menu.val, content="false")
  inspect(submitted.val, content="0")
}

///|
test "host driver shows marked document context menu commands without text focus" {
  let new_document = Ref(0)
  let open_document = Ref(0)
  let runtime = host_test_runtime(
    root=@core.View::empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="New Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="n",
              modifiers=@core.KeyModifiers::new(meta=true),
            ),
          ),
        ),
        handle=() => new_document.val = new_document.val + 1,
      ),
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="New Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="n",
              modifiers=@core.KeyModifiers::new(control=true),
            ),
          ),
        ),
        handle=() => new_document.val = new_document.val + 1,
      ),
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="Open Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="o",
              modifiers=@core.KeyModifiers::new(meta=true),
            ),
          ),
        ),
        handle=() => open_document.val = open_document.val + 1,
      ),
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="Open Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="o",
              modifiers=@core.KeyModifiers::new(control=true),
            ),
          ),
        ),
        handle=() => open_document.val = open_document.val + 1,
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let seen_labels : Array[String] = []
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
          }
          HostServiceResponse::MenuAction(commands[1])
        }
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  ignore(driver.show_context_menu(services))
  inspect(seen_labels.length(), content="2")
  inspect(seen_labels[0], content="New Document")
  inspect(seen_labels[1], content="Open Document")
  inspect(new_document.val, content="0")
  inspect(open_document.val, content="1")
}

///|
test "host driver shows document actions in focused text context menu without selection" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  runtime.set_action_commands(
    @core.ActionCommandMap::new(bindings=[
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="New Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="n",
              modifiers=@core.KeyModifiers::new(meta=true),
            ),
          ),
        ),
        handle=() => (),
      ),
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="New Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="n",
              modifiers=@core.KeyModifiers::new(control=true),
            ),
          ),
        ),
        handle=() => (),
      ),
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="Open Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="o",
              modifiers=@core.KeyModifiers::new(meta=true),
            ),
          ),
        ),
        handle=() => (),
      ),
      @core.CommandBinding::new(
        command=@core.ActionCommand::new(
          intent=@core.CommandIntent::Activate,
          label="Open Document",
          context_menu=true,
          shortcut=Some(
            @core.KeyboardShortcut::new(
              key="o",
              modifiers=@core.KeyModifiers::new(control=true),
            ),
          ),
        ),
        handle=() => (),
      ),
    ]),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  let seen_labels : Array[String] = []
  let services = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(menus=true),
    handle=request => {
      match request {
        ShowMenu(commands) => {
          for command in commands {
            seen_labels.push(command.label)
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
  ignore(driver.show_context_menu(services))
  inspect(seen_labels.length(), content="2")
  assert_true(seen_labels.any(label => label == "New Document"))
  assert_true(seen_labels.any(label => label == "Open Document"))
  assert_false(seen_labels.any(label => label == "Copy"))
  assert_false(seen_labels.any(label => label == "Paste"))
}

///|
test "host service bridge routes typed platform channels" {
  let bridge = HostServiceBridge::unavailable()
  bridge.register_channel(
    PlatformChannelHandler::new(channel="clipboard.extra", handle=request => {
      if request.operation == "echo" {
        PlatformChannelResponse::Ok(request.payload)
      } else {
        PlatformChannelResponse::Error("unknown method")
      }
    }),
  )
  match
    bridge.dispatch_channel(
      PlatformChannelRequest::new(
        channel="clipboard.extra",
        operation="echo",
        payload="hello",
      ),
    ) {
    PlatformChannelResponse::Ok(value) => inspect(value, content="hello")
    _ => fail("expected platform channel response")
  }
  match
    bridge.dispatch_channel(
      PlatformChannelRequest::new(channel="missing", operation="echo"),
    ) {
    PlatformChannelResponse::Unavailable(message) =>
      inspect(message, content="platform channel is unavailable: missing")
    _ => fail("expected unavailable platform channel")
  }
}

///|
test "host service bridge routes registered typed services before fallback" {
  let fallback = Ref(0)
  let clipboard_written = Ref("")
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      fallback.val = fallback.val + 1
      HostServiceResponse::Unavailable(request.unavailable_message())
    },
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::ClipboardService, handle=request => {
      match request {
        Clipboard(WriteText(text)) => {
          clipboard_written.val = text
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("registered")
        _ => HostServiceResponse::Unavailable("wrong service")
      }
    }),
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::SystemThemeService, handle=_request => {
      HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
    }),
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::WriteText("hello")),
    ) {
    HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected registered clipboard service")
  }
  inspect(clipboard_written.val, content="hello")
  match bridge.dispatch(HostServiceRequest::QuerySystemTheme) {
    HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected registered theme service")
  }
  match bridge.dispatch(HostServiceRequest::OpenUrl("https://example.test")) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL service is unavailable")
    _ => fail("expected fallback service")
  }
  inspect(fallback.val, content="1")
}

///|
test "host service bridge gates registered services by capability" {
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::none(),
    handle=_request => HostServiceResponse::ClipboardWritten,
  )
  bridge.register_service(
    HostServiceHandler::new(kind=HostServiceKind::ClipboardService, handle=_request => {
      HostServiceResponse::ClipboardWritten
    }),
  )
  match
    bridge.dispatch(
      HostServiceRequest::Clipboard(HostClipboardRequest::WriteText("blocked")),
    ) {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected capability gate before registered service")
  }
}
