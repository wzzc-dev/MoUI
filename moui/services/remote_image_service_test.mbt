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
