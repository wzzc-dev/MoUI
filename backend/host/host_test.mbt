///|
test "host surface metrics tracks logical physical and dpr" {
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
    scale_factor=2.0,
  )
  assert_true(metrics.logical_size == @core.Size::new(width=120.0, height=80.0))
  assert_true(metrics.physical_size == @core.Size::new(width=240.0, height=160.0))
  inspect(metrics.scale_factor, content="2")
}

///|
test "host driver dispatches resize and deduplicates redraw requests" {
  let scheduled = Ref(0)
  let runtime = @backend.AppRuntime::new(
    root=@core.ViewNode::Empty,
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(
    runtime~,
    schedule_redraw=() => scheduled.val = scheduled.val + 1,
  )
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let first = driver.dispatch(HostEvent::Resized(metrics))
  let second = driver.dispatch(HostEvent::Resized(metrics))
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(first.redraw_requested, content="true")
  inspect(second.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(driver.dispatch(HostEvent::Resized(metrics)))
  inspect(scheduled.val, content="2")
}

///|
test "host driver maps focused text input through current core keyboard event" {
  let text = @core.State::new("")
  let runtime = @backend.AppRuntime::new(
    root=@core.ViewNode::TextField({
      value: text.binding(),
      placeholder: "Type",
      size: @core.Size::new(width=240.0, height=40.0),
      on_submit: None,
    }),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => ())
  ignore(driver.dispatch(HostEvent::TextInput("a")))
  inspect(text.get(), content="")
  ignore(
    driver.dispatch(
      HostEvent::PointerButton(
        @core.Point::new(x=10.0, y=10.0),
        @core.PointerPhase::Down,
        0,
      ),
    ),
  )
  let result = driver.dispatch(HostEvent::TextInput("a"))
  inspect(text.get(), content="a")
  inspect(result.redraw_requested, content="true")
}

///|
test "host event converts to current core event model" {
  let event = HostEvent::TextInput("x").to_core()
  match event {
    Some(@core.AppEvent::Keyboard(keyboard)) => {
      inspect(keyboard.key, content="x")
      match keyboard.text {
        Some(text) => inspect(text, content="x")
        None => fail("expected text")
      }
    }
    _ => fail("expected keyboard event")
  }
}
