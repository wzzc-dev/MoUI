///|
test "service extension registers and returns its typed JSON task" {
  let extension = @services.ServiceExtension::new(
    id="db",
    version="2",
    capability_label="database",
    call=request => @services.ServiceTask::succeed(key="db:call", value=request),
  )
  let services = @services.AppServices::new(extensions=[extension])
  assert_true(services.extension("db") is Some(_))
  assert_true(services.extension("missing") is None)
  inspect(services.extension_capability_labels().length(), content="1")
  inspect(services.extension_capability_labels()[0], content="database")
  let result = Ref(None)
  ignore(
    extension
    .call(Json::string("ping"))
    .start(value => result.val = Some(value)),
  )
  match result.val {
    Some(Success(_)) => ()
    _ => fail("expected extension success")
  }
}

///|
test "unavailable service extension fails with a typed unavailable error" {
  let extension = @services.ServiceExtension::unavailable(id="printer")
  let result = Ref(None)
  ignore(extension.call(Json::null()).start(value => result.val = Some(value)))
  match result.val {
    Some(Failure(error)) => {
      inspect(error.code, content="unavailable")
      inspect(error.message, content="printer is unavailable")
    }
    _ => fail("expected unavailable extension failure")
  }
}
