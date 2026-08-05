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
  let environment = @core.Environment::neutral()
    .with_locale("zh-CN")
    .with_text_scale(1.25)
  let updated = bridge.environment_with_system_theme(environment)
  assert_true(updated.color_scheme() == @core.ColorScheme::Dark)
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
  let runtime = host_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[@core.ActionCommand::new(intent=@core.CommandIntent::Copy)],
    on_message=_ => copied.val = copied.val + 1,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let result = driver.dispatch(Event::Command(@core.CommandIntent::Copy))
  inspect(copied.val, content="1")
  inspect(result.redraw_requested, content="true")
  match Event::Command(@core.CommandIntent::Copy).to_core() {
    None => ()
    Some(_) => fail("host command should dispatch through runtime action map")
  }
}

///|
test "host driver applies theme change to runtime environment" {
  let runtime = host_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let result = driver.dispatch(Event::ThemeChanged(@core.ColorScheme::Dark))
  assert_true(runtime.environment().color_scheme() == @core.ColorScheme::Dark)
  assert_true(runtime.environment().theme.scheme == @core.ColorScheme::Dark)
  inspect(result.redraw_requested, content="true")
}

///|
