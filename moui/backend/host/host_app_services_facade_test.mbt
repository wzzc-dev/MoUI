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
  inspect(diagnostic.path(), content="/tmp/report.pdf")
  inspect(diagnostic.operation(), content="write-bytes")
  inspect(diagnostic.byte_length(), content="4")

  match
    HostServiceResponse::BinaryFileContent(
      "/tmp/report.pdf",
      Bytes::make(32, b'\xff'),
    ).binary_file_diagnostic() {
    Some(summary) => {
      inspect(summary.path(), content="/tmp/report.pdf")
      inspect(summary.operation(), content="read-bytes")
      inspect(summary.byte_length(), content="32")
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
