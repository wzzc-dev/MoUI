///|
test "web async host service descriptors drain and complete browser responses" {
  let queue = @window_services.ServiceAsyncQueue::new()
  let bridge = web_service_bridge(
    clipboard_read=true,
    file_dialog=true,
    async_queue=Some(queue),
  )
  match bridge.dispatch(Clipboard(ReadText)) {
    Pending(id) => inspect(id.value, content="1")
    _ => fail("expected pending clipboard read")
  }
  let file_id = match
    bridge.dispatch(
      FileDialog(
        @host.HostFileDialogOptions::new(kind=OpenFile, title="Open note"),
      ),
    ) {
    Pending(id) => {
      inspect(id.value, content="2")
      id
    }
    _ => fail("expected pending file dialog")
  }
  let requests = drain_web_async_host_service_requests(queue)
  inspect(requests.length(), content="2")
  inspect(queue.pending_count(), content="0")
  inspect(queue.in_flight_count(), content="2")
  assert_true(requests[0].kind == ClipboardReadText)
  inspect(requests[0].id.value, content="1")
  assert_true(requests[1].kind == FileDialogOpenFile)
  inspect(requests[1].id.value, content="2")
  inspect(requests[1].title, content="Open note")
  inspect(requests[1].kind.browser_code(), content="0")

  let file_completion : Ref[@host.HostCompletedServiceResponse?] = Ref(None)
  assert_true(
    queue.on_completed(file_id, completion => {
      file_completion.val = Some(completion)
    }),
  )
  set_web_async_host_service_queue(Some(queue))
  assert_true(web_complete_async_clipboard_read_text(1, true, "from browser"))
  assert_true(
    web_complete_async_file_dialog_selection_text(
      2, true, "note.md\nfolder/project.mbt",
    ),
  )
  let completed = queue.drain_completed()
  inspect(completed.length(), content="1")
  match completed[0].response {
    ClipboardText(text) => inspect(text, content="from browser")
    _ => fail("expected clipboard text completion")
  }
  match file_completion.val {
    Some({ response: FileDialogSelection(paths), .. }) => {
      inspect(paths.length(), content="2")
      inspect(paths[0], content="note.md")
      inspect(paths[1], content="folder/project.mbt")
    }
    _ => fail("expected file dialog completion")
  }
  set_web_async_host_service_queue(None)
}

///|
test "web async file open caches browser text for text-file reads" {
  let queue = @window_services.ServiceAsyncQueue::new()
  let bridge = web_service_bridge(
    file_dialog=true,
    file_access=true,
    async_queue=Some(queue),
  )
  let file_id = match
    bridge.dispatch(
      FileDialog(
        @host.HostFileDialogOptions::new(kind=OpenFile, title="Open Markdown"),
      ),
    ) {
    Pending(id) => id
    _ => fail("expected pending file dialog")
  }
  ignore(drain_web_async_host_service_requests(queue))
  let file_completion : Ref[@host.HostCompletedServiceResponse?] = Ref(None)
  assert_true(
    queue.on_completed(file_id, completion => {
      file_completion.val = Some(completion)
    }),
  )
  set_web_async_host_service_queue(Some(queue))
  assert_true(
    web_complete_async_file_open_text_values(
      file_id.value,
      true,
      "browser-note.md",
      "# Browser note\n\nImported from File.text().",
    ),
  )
  match file_completion.val {
    Some({ response: FileDialogSelection(paths), .. }) => {
      inspect(paths.length(), content="1")
      inspect(paths[0], content="browser-note.md")
    }
    _ => fail("expected file dialog selection")
  }
  match bridge.dispatch(TextFile(ReadText("browser-note.md"))) {
    TextFileContent(path, text) => {
      inspect(path, content="browser-note.md")
      inspect(text, content="# Browser note\n\nImported from File.text().")
    }
    _ => fail("expected cached Web text file content")
  }
  match bridge.dispatch(TextFile(WriteText("browser-note.md", "updated"))) {
    Pending(id) => inspect(id.value, content="2")
    _ => fail("expected pending Web text-file write")
  }
  let write_requests = drain_web_async_host_service_requests(queue)
  inspect(write_requests.length(), content="1")
  assert_true(write_requests[0].kind == TextFileWriteText)
  inspect(write_requests[0].path, content="browser-note.md")
  inspect(write_requests[0].text, content="updated")
  let write_completion : Ref[@host.HostCompletedServiceResponse?] = Ref(None)
  assert_true(
    queue.on_completed(@host.HostServiceRequestId::new(2), completion => {
      write_completion.val = Some(completion)
    }),
  )
  assert_true(
    web_complete_async_text_file_write_text(2, true, "browser-note.md"),
  )
  match write_completion.val {
    Some({ response: TextFileWritten(path), .. }) =>
      inspect(path, content="browser-note.md")
    _ => fail("expected Web text-file write completion")
  }
  match bridge.dispatch(TextFile(ReadText("browser-note.md"))) {
    TextFileContent(path, text) => {
      inspect(path, content="browser-note.md")
      inspect(text, content="updated")
    }
    _ => fail("expected updated cached Web text file content")
  }
  set_web_async_host_service_queue(None)
}

///|
test "web async text-file read fetches and caches static text" {
  let queue = @window_services.ServiceAsyncQueue::new()
  let bridge = web_service_bridge(file_access=true, async_queue=Some(queue))
  let read_id = match
    bridge.dispatch(TextFile(ReadText("docs/architecture.md"))) {
    Pending(id) => {
      inspect(id.value, content="1")
      id
    }
    _ => fail("expected pending Web text-file read")
  }
  let requests = drain_web_async_host_service_requests(queue)
  inspect(requests.length(), content="1")
  assert_true(requests[0].kind == TextFileReadText)
  inspect(requests[0].kind.browser_code(), content="-3")
  inspect(requests[0].path, content="docs/architecture.md")
  let read_completion : Ref[@host.HostCompletedServiceResponse?] = Ref(None)
  assert_true(
    queue.on_completed(read_id, completion => {
      read_completion.val = Some(completion)
    }),
  )
  set_web_async_host_service_queue(Some(queue))
  assert_true(
    web_complete_async_text_file_read_text(
      read_id.value,
      true,
      "# Architecture\n\nFetched by browser fetch().",
    ),
  )
  match read_completion.val {
    Some({ response: TextFileContent(path, text), .. }) => {
      inspect(path, content="docs/architecture.md")
      inspect(text, content="# Architecture\n\nFetched by browser fetch().")
    }
    _ => fail("expected fetched text-file content")
  }
  match bridge.dispatch(TextFile(ReadText("docs/architecture.md"))) {
    TextFileContent(path, text) => {
      inspect(path, content="docs/architecture.md")
      inspect(text, content="# Architecture\n\nFetched by browser fetch().")
    }
    _ => fail("expected cached static text content")
  }
  set_web_async_host_service_queue(None)
}
