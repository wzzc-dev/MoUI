///|
test "live task scope delivers its completion" {
  let scope = @core.TaskScope::new()
  let task = @services.ServiceTask::succeed(
    key="scope:live",
    value=1,
    scope=Some(scope),
  )
  let result = Ref(None)
  ignore(task.start(value => result.val = Some(value)))
  match result.val {
    Some(Success(value)) => inspect(value, content="1")
    _ => fail("expected live scope completion")
  }
}

///|
test "cancelled task scope drops its completion" {
  let scope = @core.TaskScope::new()
  let task = @services.ServiceTask::succeed(
    key="scope:cancelled",
    value=1,
    scope=Some(scope),
  )
  scope.cancel()
  let result = Ref(None)
  ignore(task.start(value => result.val = Some(value)))
  assert_true(result.val is None)
}
