///|
test "web async host service descriptors drain and complete browser responses" {
  let queue = @host.HostServiceAsyncQueue::new()
  let bridge = web_service_bridge(
    clipboard_read=true,
    file_dialog=true,
    async_queue=Some(queue),
  )
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Pending(id) => inspect(id.value, content="1")
    _ => fail("expected pending clipboard read")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::OpenFile,
          title="Open note",
        ),
      ),
    ) {
    @host.HostServiceResponse::Pending(id) => inspect(id.value, content="2")
    _ => fail("expected pending file dialog")
  }
  let requests = drain_web_async_host_service_requests(queue)
  inspect(requests.length(), content="2")
  inspect(queue.pending_count(), content="0")
  inspect(queue.in_flight_count(), content="2")
  assert_true(requests[0].kind == WebAsyncHostServiceKind::ClipboardReadText)
  inspect(requests[0].id.value, content="1")
  assert_true(requests[1].kind == WebAsyncHostServiceKind::FileDialogOpenFile)
  inspect(requests[1].id.value, content="2")
  inspect(requests[1].title, content="Open note")
  inspect(requests[1].kind.browser_code(), content="0")

  set_web_async_host_service_queue(Some(queue))
  assert_true(web_complete_async_clipboard_read_text(1, true, "from browser"))
  assert_true(
    web_complete_async_file_dialog_selection_text(
      2, true, "note.md\nfolder/project.mbt",
    ),
  )
  let completed = queue.drain_completed()
  inspect(completed.length(), content="2")
  match completed[0].response {
    @host.HostServiceResponse::ClipboardText(text) =>
      inspect(text, content="from browser")
    _ => fail("expected clipboard text completion")
  }
  match completed[1].response {
    @host.HostServiceResponse::FileDialogSelection(paths) => {
      inspect(paths.length(), content="2")
      inspect(paths[0], content="note.md")
      inspect(paths[1], content="folder/project.mbt")
    }
    _ => fail("expected file dialog completion")
  }
  set_web_async_host_service_queue(None)
}
