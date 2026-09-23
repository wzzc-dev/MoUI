///|
test "host service bridge gates typed platform requests by capability" {
  let bridge = @backend.HostServiceBridge::new(
    capabilities=@backend.HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(_)) => ClipboardWritten
        Clipboard(ReadText) => ClipboardText("copied")
        ShowMenu(commands) =>
          if commands.length() > 0 {
            MenuCommand(commands[0].intent)
          } else {
            Unavailable("empty menu")
          }
        QuerySystemTheme => SystemTheme(Dark)
        _ => Unavailable("not implemented")
      }
    },
  )
  match bridge.dispatch(Clipboard(ReadText)) {
    ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard text")
  }
  match
    bridge.dispatch(
      ShowMenu([@core.ActionCommand::new(intent=Copy, label="Copy")]),
    ) {
    MenuCommand(Copy) => ()
    _ => fail("expected selected menu command")
  }
  match
    bridge.dispatch(
      FileDialog(@backend.HostFileDialogOptions::new(kind=OpenFile)),
    ) {
    Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file dialog")
  }
  match bridge.dispatch(TextFile(ReadText("/tmp/a.md"))) {
    Unavailable(message) =>
      inspect(message, content="text file service is unavailable")
    _ => fail("expected unavailable text file service")
  }
  match bridge.dispatch(BinaryFile(ReadBytes("/tmp/a.pdf"))) {
    Unavailable(message) =>
      inspect(message, content="binary file service is unavailable")
    _ => fail("expected unavailable binary file service")
  }
}

///|
test "host service bridge applies system theme to runtime environment" {
  let bridge = @backend.HostServiceBridge::new(
    capabilities=@backend.HostServiceCapabilities::new(system_theme=true),
    handle=request => {
      match request {
        QuerySystemTheme => SystemTheme(Dark)
        _ => Unavailable("unexpected request")
      }
    },
  )
  match bridge.query_system_theme() {
    Some(Dark) => ()
    _ => fail("expected dark system theme")
  }
  let environment = @core.Environment::neutral()
    .with_locale("zh-CN")
    .with_text_scale(1.25)
  let updated = bridge.environment_with_system_theme(environment)
  assert_true(updated.color_scheme() == Dark)
  assert_true(updated.theme.scheme == Dark)
  inspect(updated.locale, content="zh-CN")
  inspect(updated.text_scale, content="1.25")

  let unavailable = @backend.HostServiceBridge::unavailable()
  let unchanged = unavailable.environment_with_system_theme(environment)
  assert_true(unchanged == environment)
}

///|
test "host driver dispatches command intents through runtime action map" {
  let copied = Ref(0)
  let runtime = host_test_runtime_with_commands(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
    commands=[@core.ActionCommand::new(intent=Copy)],
    on_message=_ => copied.val = copied.val + 1,
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let result = driver.dispatch(Command(Copy))
  inspect(copied.val, content="1")
  inspect(result.redraw_requested, content="true")
  match @backend.Event::Command(Copy).to_core() {
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
  let result = driver.dispatch(ThemeChanged(Dark))
  assert_true(runtime.environment().color_scheme() == Dark)
  assert_true(runtime.environment().theme.scheme == Dark)
  inspect(result.redraw_requested, content="true")
}

///|
