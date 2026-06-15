///|
test "view gesture wrappers emit long double and drag messages" {
  let log = Ref("")
  let root : View[String] = View::primitive_container_view(
      child=Some(
        View::primitive_text_view(
          text="Gesture target",
          size=Size::new(width=180.0, height=44.0),
          font=FontSpec::new(size=14.0),
          color=Color::black(),
        ),
      ),
      size=Some(Size::new(width=180.0, height=80.0)),
      background=Some(Brush::solid(Color::gray())),
    )
    .on_long_press("long")
    .on_double_tap("double")
    .on_drag(event => event.phase.label())
  let runtime = RuntimeState::new_view(
    root~,
    size=Size::new(width=220.0, height=120.0),
    on_message=Some(message => log.val = log.val + message + ";"),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Down,
        time_ms=0.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Move,
        time_ms=520.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=12.0, y=12.0),
        phase=PointerPhase::Up,
        time_ms=560.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Down,
        time_ms=700.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=20.0, y=20.0),
        phase=PointerPhase::Up,
        time_ms=720.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=22.0, y=20.0),
        phase=PointerPhase::Down,
        time_ms=840.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=22.0, y=20.0),
        phase=PointerPhase::Up,
        time_ms=860.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=24.0, y=24.0),
        phase=PointerPhase::Down,
        time_ms=1000.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=40.0, y=24.0),
        phase=PointerPhase::Move,
        time_ms=1016.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=48.0, y=30.0),
        phase=PointerPhase::Move,
        time_ms=1032.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=50.0, y=32.0),
        phase=PointerPhase::Up,
        time_ms=1050.0,
      ),
    ),
  )
  inspect(log.val, content="long;double;Started;Changed;Ended;")
}

///|
test "disabled wrapper suppresses high level gesture activation" {
  let log = Ref("")
  let root : View[String] = View::primitive_container_view(
      size=Some(Size::new(width=120.0, height=80.0)),
      background=Some(Brush::solid(Color::gray())),
    )
    .on_long_press("long")
    .on_double_tap("double")
    .on_drag(event => event.phase.label())
    .disabled()
  let runtime = RuntimeState::new_view(
    root~,
    size=Size::new(width=160.0, height=120.0),
    on_message=Some(message => log.val = log.val + message + ";"),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
        time_ms=0.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=32.0, y=10.0),
        phase=PointerPhase::Move,
        time_ms=600.0,
      ),
    ),
  )
  runtime.dispatch_event(
    AppEvent::Pointer(
      PointerEvent::new(
        position=Point::new(x=32.0, y=10.0),
        phase=PointerPhase::Up,
        time_ms=620.0,
      ),
    ),
  )
  inspect(log.val, content="")
}
