///|
test "devtools sampler runs at the configured cadence" {
  let calls = Ref(0)
  let root : @core.View[Unit] = @views.text("hello")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=160.0, height=40.0),
  )
  runtime.set_devtools_sample_observer(Some(() => calls.val = calls.val + 1))
  runtime.advance_time(0.0)
  inspect(calls.val, content="0")
  runtime.advance_time(600.0)
  inspect(calls.val, content="1")
  runtime.advance_time(1000.0)
  inspect(calls.val, content="1")
  runtime.advance_time(1200.0)
  inspect(calls.val, content="2")
}
