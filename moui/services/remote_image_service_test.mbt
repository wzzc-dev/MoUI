///|
test "remote image service forwards its completion listener" {
  let received = Ref("")
  let service = @services.RemoteImageService::new(set_completed_listener=listener => {
    listener("https://example.com/a.png", b"png")
  })
  assert_true(service.is_available())
  service.set_completed_listener((source, _bytes) => received.val = source)
  inspect(received.val, content="https://example.com/a.png")
}

///|
test "unavailable remote image service is inert" {
  let called = Ref(false)
  let service = @services.RemoteImageService::unavailable()
  assert_false(service.is_available())
  service.set_completed_listener((_source, _bytes) => called.val = true)
  assert_false(called.val)
}

///|
test "AppServices exposes the registered remote image service" {
  let service = @services.RemoteImageService::new(set_completed_listener=_listener => {
    ()
  })
  let services = @services.AppServices::new(remote_image=service)
  assert_true(services.remote_image().is_available())
}

///|
test "remote image service fetch returns a cancellable request handle" {
  let cancels = Ref(0)
  let service = @services.RemoteImageService::new(
    set_completed_listener=_listener => (),
    fetch=(_source, _on_complete) => {
      Some(
        @services.RemoteImageRequest::new(cancel=fn() {
          cancels.val = cancels.val + 1
        }),
      )
    },
  )
  let request = service
    .fetch(source="https://example.com/a.png", on_complete=_bytes => ())
    .unwrap()
  assert_false(request.is_cancelled())
  request.cancel()
  assert_true(request.is_cancelled())
  // Cancelling twice is inert: the host cancel callback runs once.
  request.cancel()
  inspect(cancels.val, content="1")
}

///|
test "unavailable remote image service rejects explicit fetches" {
  let service = @services.RemoteImageService::unavailable()
  let request = service.fetch(source="https://example.com/a.png", on_complete=_bytes => {
    ()
  })
  assert_true(request is None)
}
