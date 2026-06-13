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
test "host async service queue tracks pending and completed responses" {
  let queue = HostServiceAsyncQueue::new()
  let first = match
    queue.submit(HostServiceRequest::OpenUrl("https://example.test")) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending open-url request")
  }
  inspect(first.value, content="1")
  inspect(queue.pending_count(), content="1")
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.outstanding_count(), content="1")
  inspect(queue.completed_count(), content="0")
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  inspect(queue.pending_count(), content="0")
  inspect(queue.in_flight_count(), content="1")
  assert_true(queue.complete(first, HostServiceResponse::UrlOpened))
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(first) {
    Some({ request: HostServiceRequest::OpenUrl(url), response, .. }) => {
      inspect(url, content="https://example.test")
      match response {
        HostServiceResponse::UrlOpened => ()
        _ => fail("expected completed open-url response")
      }
    }
    _ => fail("expected completed open-url response")
  }
  match pending[0].request {
    HostServiceRequest::OpenUrl(url) =>
      inspect(url, content="https://example.test")
    _ => fail("expected pending open-url request")
  }

  let second = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  assert_true(
    queue.complete(
      second,
      HostServiceResponse::FileDialogSelection(["/tmp/note.md"]),
    ),
  )
  inspect(queue.pending_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(second) {
    Some({ request: HostServiceRequest::FileDialog(_), response, .. }) =>
      match response {
        HostServiceResponse::FileDialogSelection(paths) =>
          inspect(paths[0], content="/tmp/note.md")
        _ => fail("expected completed file selection")
      }
    _ => fail("expected completed file-dialog response")
  }
  inspect(queue.completed_count(), content="0")
  inspect(
    queue.reject(HostServiceRequestId::new(404), "missing request"),
    content="false",
  )
}

///|
test "host async service queue rejects in-flight service requests" {
  let queue = HostServiceAsyncQueue::new()
  let request_id = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(kind=HostFileDialogKind::OpenFile),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  inspect(queue.in_flight_count(), content="1")
  assert_true(queue.reject(request_id, "file dialog canceled"))
  inspect(queue.in_flight_count(), content="0")
  inspect(queue.completed_count(), content="1")
  match queue.take_completed(request_id) {
    Some({ request: HostServiceRequest::FileDialog(_), response, .. }) =>
      match response {
        HostServiceResponse::Unavailable(message) =>
          inspect(message, content="file dialog canceled")
        _ => fail("expected rejected file-dialog response")
      }
    _ => fail("expected rejected file-dialog completion")
  }
}

///|
test "host async service queue invokes completion handlers" {
  let queue = HostServiceAsyncQueue::new()
  let delivered : Ref[HostCompletedServiceResponse?] = Ref(None)
  let request_id = match
    queue.submit(
      HostServiceRequest::FileDialog(
        HostFileDialogOptions::new(
          kind=HostFileDialogKind::OpenFile,
          title="Import files",
        ),
      ),
    ) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file-dialog request")
  }
  assert_true(
    queue.on_completed(request_id, completion => {
      delivered.val = Some(completion)
    }),
  )
  let pending = queue.drain_pending()
  inspect(pending.length(), content="1")
  assert_true(
    queue.complete(
      request_id,
      HostServiceResponse::FileDialogSelection(["/tmp/later.csv"]),
    ),
  )
  inspect(queue.completed_count(), content="0")
  match queue.take_completed(request_id) {
    Some(_) => fail("expected handled completion to be consumed")
    None => ()
  }
  match delivered.val {
    Some(
      { request: HostServiceRequest::FileDialog({ title, .. }), response, .. }
    ) => {
      inspect(title, content="Import files")
      match response {
        HostServiceResponse::FileDialogSelection(paths) =>
          inspect(paths[0], content="/tmp/later.csv")
        _ => fail("expected file dialog selection")
      }
    }
    _ => fail("expected completion handler to receive file dialog response")
  }
  assert_false(
    queue.on_completed(HostServiceRequestId::new(404), _completion => ()),
  )
  let delivered_late : Ref[HostCompletedServiceResponse?] = Ref(None)
  let late_id = match
    queue.submit(HostServiceRequest::OpenUrl("https://late.test")) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending URL request")
  }
  assert_true(queue.complete(late_id, HostServiceResponse::UrlOpened))
  inspect(queue.completed_count(), content="1")
  assert_true(
    queue.on_completed(late_id, completion => {
      delivered_late.val = Some(completion)
    }),
  )
  match delivered_late.val {
    Some({ request: HostServiceRequest::OpenUrl(url), response, .. }) => {
      inspect(url, content="https://late.test")
      assert_true(response is HostServiceResponse::UrlOpened)
    }
    _ => fail("expected late completion registration to consume record")
  }
  inspect(queue.completed_count(), content="0")
}

///|
test "host driver applies async clipboard read completion to focused text" {
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text.binding(), width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
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
  let queue = HostServiceAsyncQueue::new()
  let pending = match
    queue.submit(HostServiceRequest::Clipboard(HostClipboardRequest::ReadText)) {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending clipboard read")
  }
  assert_true(
    queue.complete(pending, HostServiceResponse::ClipboardText("later")),
  )
  match queue.take_completed(pending) {
    Some(completion) =>
      ignore(
        driver.dispatch_service_completion(
          completion,
          HostServiceBridge::unavailable(),
        ),
      )
    None => fail("expected completed clipboard read")
  }
  inspect(text.get(), content="later")
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

///|
test "host app services facade routes common platform requests" {
  let clipboard_written = Ref("")
  let opened_url = Ref("")
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(
      clipboard=true,
      menus=true,
      file_dialogs=true,
      file_access=true,
      open_url=true,
      system_theme=true,
    ),
    handle=request => {
      match request {
        Clipboard(WriteText(text)) => {
          clipboard_written.val = text
          HostServiceResponse::ClipboardWritten
        }
        Clipboard(ReadText) => HostServiceResponse::ClipboardText("copied")
        FileDialog({ kind: OpenFile, title, .. }) =>
          HostServiceResponse::FileDialogSelection([title + ":open"])
        TextFile(ReadText(path)) =>
          HostServiceResponse::TextFileContent(path, "file contents")
        TextFile(WriteText(path, _text)) =>
          HostServiceResponse::TextFileWritten(path)
        BinaryFile(ReadBytes(path)) =>
          HostServiceResponse::BinaryFileContent(path, b"%PDF")
        BinaryFile(WriteBytes(path, _bytes)) =>
          HostServiceResponse::BinaryFileWritten(path)
        OpenUrl(url) => {
          opened_url.val = url
          HostServiceResponse::UrlOpened
        }
        QuerySystemTheme =>
          HostServiceResponse::SystemTheme(@core.ColorScheme::Dark)
        ShowMenu(commands) =>
          HostServiceResponse::MenuCommand(commands[0].intent)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~)
  assert_true(services.capabilities().clipboard)
  match services.write_clipboard_text("hello") {
    HostServiceResponse::ClipboardWritten => ()
    _ => fail("expected clipboard write")
  }
  inspect(clipboard_written.val, content="hello")
  match services.read_clipboard_text() {
    HostServiceResponse::ClipboardText(text) => inspect(text, content="copied")
    _ => fail("expected clipboard read")
  }
  match services.open_file(title="Document") {
    HostServiceResponse::FileDialogSelection(paths) =>
      inspect(paths[0], content="Document:open")
    _ => fail("expected file dialog selection")
  }
  match services.read_text_file("/tmp/note.md") {
    HostServiceResponse::TextFileContent(path, text) => {
      inspect(path, content="/tmp/note.md")
      inspect(text, content="file contents")
    }
    _ => fail("expected text file content")
  }
  match services.write_text_file("/tmp/note.md", "updated") {
    HostServiceResponse::TextFileWritten(path) =>
      inspect(path, content="/tmp/note.md")
    _ => fail("expected text file write")
  }
  match services.read_binary_file("/tmp/note.pdf") {
    HostServiceResponse::BinaryFileContent(path, bytes) => {
      inspect(path, content="/tmp/note.pdf")
      inspect(bytes.length(), content="4")
    }
    _ => fail("expected binary file content")
  }
  match services.write_binary_file("/tmp/note.pdf", b"%PDF") {
    HostServiceResponse::BinaryFileWritten(path) =>
      inspect(path, content="/tmp/note.pdf")
    _ => fail("expected binary file write")
  }
  match services.open_url("https://example.test") {
    HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL open")
  }
  inspect(opened_url.val, content="https://example.test")
  match services.system_theme() {
    Some(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark theme")
  }
  match
    services.show_context_menu([
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit),
    ]) {
    HostServiceResponse::MenuCommand(@core.CommandIntent::Submit) => ()
    _ => fail("expected context menu command")
  }
}

///|
test "host app services facade reports unavailable service responses" {
  let services = HostAppServices::unavailable()
  assert_false(services.has_async_queue())
  match services.open_url("https://example.test") {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="open URL service is unavailable")
    _ => fail("expected unavailable open-url response")
  }
  match services.open_file(title="Missing") {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="file dialog service is unavailable")
    _ => fail("expected unavailable file-dialog response")
  }
  match services.read_binary_file("/tmp/missing.pdf") {
    HostServiceResponse::Unavailable(message) =>
      inspect(message, content="binary file service is unavailable")
    _ => fail("expected unavailable binary-file response")
  }
  inspect(services.pending_count(), content="0")
  inspect(services.drain_pending().length(), content="0")
  inspect(
    services.reject(HostServiceRequestId::new(404), "missing request"),
    content="false",
  )
}

///|
test "host binary file diagnostics summarize bytes without dumping payloads" {
  let request = HostBinaryFileRequest::WriteBytes("/tmp/report.pdf", b"%PDF")
  let diagnostic = request.diagnostic()
  inspect(diagnostic.path, content="/tmp/report.pdf")
  inspect(diagnostic.operation, content="write-bytes")
  inspect(diagnostic.byte_length, content="4")

  match
    HostServiceResponse::BinaryFileContent(
      "/tmp/report.pdf",
      Bytes::make(32, b'\xff'),
    ).binary_file_diagnostic() {
    Some(summary) => {
      inspect(summary.path, content="/tmp/report.pdf")
      inspect(summary.operation, content="read-bytes")
      inspect(summary.byte_length, content="32")
    }
    None => fail("expected binary content diagnostic summary")
  }
}

///|
test "host app services facade exposes pending completions" {
  let queue = HostServiceAsyncQueue::new()
  let file_dialog_completed = Ref(false)
  let bridge = HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true, file_dialogs=true),
    handle=request => {
      match request {
        Clipboard(ReadText) => queue.submit(request)
        FileDialog(_) => queue.submit(request)
        _ => HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = HostAppServices::new(bridge~, async_queue=Some(queue))
  assert_true(services.has_async_queue())
  let clipboard_id = match services.read_clipboard_text() {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending clipboard read")
  }
  let file_id = match services.open_file(title="Open") {
    HostServiceResponse::Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  assert_true(
    services.on_completed(file_id, completion => {
      match completion.response {
        HostServiceResponse::FileDialogSelection(paths) =>
          file_dialog_completed.val = paths.length() == 1
        _ => ()
      }
    }),
  )
  inspect(services.pending_count(), content="2")
  inspect(services.outstanding_count(), content="2")
  let pending = services.drain_pending()
  inspect(pending.length(), content="2")
  inspect(services.in_flight_count(), content="2")
  assert_true(
    services.complete(clipboard_id, HostServiceResponse::ClipboardText("later")),
  )
  assert_true(
    services.complete(
      file_id,
      HostServiceResponse::FileDialogSelection(["/tmp/file.txt"]),
    ),
  )
  inspect(file_dialog_completed.val, content="true")
  inspect(services.completed_count(), content="1")
  match services.take_completed(clipboard_id) {
    Some({ request: Clipboard(ReadText), response: ClipboardText(text), .. }) =>
      inspect(text, content="later")
    _ => fail("expected completed clipboard read")
  }
  let completed = services.drain_completed()
  inspect(completed.length(), content="0")
}
