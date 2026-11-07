///|
/// End-to-end coverage for host-recognized gesture delivery: a trackpad
/// pinch/rotation/pan sample targets the content under the last known primary
/// pointer, the deepest `on_gesture` handler on the hit path claims it, and a
/// gesture that arrives before any pointer sample has no target at all.
///
/// The probe points account for the container's theme padding: the 40x40
/// observed rect sits inset inside its 100x100 container, so (50,50) is on
/// the rect and (95,95) is on the container's padding band.

///|
test "gesture samples target the content under the last pointer" {
  let received : Array[String] = []
  let last : Ref[@core.GestureEvent?] = Ref(None)
  let inner : @core.View[String] = runtime_test_rect(
    width=40.0,
    height=40.0,
    color=@core.Color::blue(),
  ).on_gesture(event => {
    last.val = Some(event)
    received.push("hit")
    "hit"
  })
  let root : @core.View[String] = @views.container(
    inner,
    width=100.0,
    height=100.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some((_ : String) => ()),
  )
  ignore(runtime.layout())
  // The cursor is over the observed rect: a pinch sample lands on the
  // handler with every field of the sample intact.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Gesture(@core.GestureEvent::new(kind=Pinch, phase=Moved, scale_delta=0.05)),
  )
  assert_true(received.length() == 1)
  let event = last.val.unwrap()
  assert_true(event.kind == Pinch)
  assert_true(event.phase == Moved)
  assert_true(event.scale_delta == 0.05)
  // The cursor moved onto the container's padding band, where no observer
  // lives: the same sample is dropped.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=95.0, y=95.0),
        phase=Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Gesture(
      @core.GestureEvent::new(kind=Rotate, phase=Moved, rotation_delta=0.25),
    ),
  )
  assert_true(received.length() == 1)
}

///|
test "the deepest gesture handler on the hit path claims the sample" {
  let received : Array[String] = []
  let inner : @core.View[String] = runtime_test_rect(
    width=40.0,
    height=40.0,
    color=@core.Color::blue(),
  ).on_gesture(_event => {
    received.push("inner")
    "inner"
  })
  let root : @core.View[String] = @views.container(
    inner,
    width=100.0,
    height=100.0,
  ).on_gesture(_event => {
    received.push("outer")
    "outer"
  })
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some((_ : String) => ()),
  )
  ignore(runtime.layout())
  // Over the inner rect: the innermost handler claims the gesture and the
  // outer observer sees nothing.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Gesture(
      @core.GestureEvent::new(
        kind=Pan,
        phase=Moved,
        pan_delta=@core.Point::new(x=4.0, y=0.0 - 2.0),
      ),
    ),
  )
  assert_true(received.length() == 1)
  assert_true(received[0] == "inner")
  // Over the container's padding band: the outer handler claims it.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=95.0, y=95.0),
        phase=Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Gesture(
      @core.GestureEvent::new(
        kind=Pan,
        phase=Ended,
        pan_delta=@core.Point::new(x=0.0, y=0.0),
      ),
    ),
  )
  assert_true(received.length() == 2)
  assert_true(received[1] == "outer")
}

///|
test "a gesture before any pointer sample has no target" {
  let received : Array[String] = []
  let root : @core.View[String] = runtime_test_rect(
    width=60.0,
    height=60.0,
    color=@core.Color::blue(),
  ).on_gesture(_event => {
    received.push("hit")
    "hit"
  })
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some((_ : String) => ()),
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    Gesture(@core.GestureEvent::new(kind=DoubleTap, phase=Started)),
  )
  assert_true(received.length() == 0)
}
