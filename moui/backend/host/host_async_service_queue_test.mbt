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
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
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
