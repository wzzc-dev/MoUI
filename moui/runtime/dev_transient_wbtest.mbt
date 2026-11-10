///|
test "dev transient round-trips a scroll offset" {
  let root : @core.View[Unit] = @views.scroll_view(
    @views.text("tall", width=20.0, height=200.0),
    width=20.0,
    height=40.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
  )
  ignore(runtime.layout())
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=-12.0),
      ),
    ),
  )
  let payload = runtime.capture_dev_transient()
  assert_true(payload.contains("slot "))
  let restored = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=20.0, height=40.0),
  )
  restored.restore_dev_transient(payload)
  ignore(restored.layout())
  inspect(restored.capture_dev_transient(), content=payload)
}

///|
test "dev transient round-trips the focused key" {
  let root : @core.View[Unit] = @views.column(
    [
      @views.button("A", width=80.0, height=30.0).key("a"),
      @views.button("B", width=80.0, height=30.0).key("b"),
    ],
    spacing=0.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=80.0),
  )
  ignore(runtime.layout())
  assert_true(runtime.focus_key("b"))
  let payload = runtime.capture_dev_transient()
  assert_true(payload.contains("focus "))
  let restored = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=80.0),
  )
  restored.restore_dev_transient(payload)
  ignore(restored.layout())
  inspect(restored.capture_dev_transient(), content=payload)
}

///|
test "dev transient round-trips the focused text caret" {
  let root : @core.View[Unit] = @views.text_field(
    "abcdef",
    on_input=_ => (),
    width=200.0,
    height=40.0,
  ).key("input")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=220.0, height=60.0),
  )
  ignore(runtime.layout())
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=60.0, y=20.0),
        phase=Down,
      ),
    ),
  )
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=60.0, y=20.0),
        phase=Up,
      ),
    ),
  )
  let before = runtime.focused_text_input()
  if !before.focused {
    fail("expected the text field to take focus")
  }
  let payload = runtime.capture_dev_transient()
  let restored = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=220.0, height=60.0),
  )
  restored.restore_dev_transient(payload)
  ignore(restored.layout())
  let after = restored.focused_text_input()
  inspect(after.focused, content="true")
  inspect(after.caret, content=before.caret.to_string())
}

///|
test "dev transient ignores malformed payloads" {
  let root : @core.View[Unit] = @views.text("stable")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=40.0),
  )
  ignore(runtime.layout())
  runtime.restore_dev_transient("not a transient payload")
  inspect(runtime.capture_dev_transient(), content="moui-dev-transient-v1\n")
}
