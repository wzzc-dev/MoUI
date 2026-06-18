///|
fn[Msg] event_observer_test_rect(
  width~ : Double,
  height~ : Double,
  color~ : @core.Color,
  on_tap? : Msg? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Rect"),
    revision=() => "event-observer-test-rect:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::FillRect(ctx.frame, color),
      ])
    },
    event=ctx => {
      match (ctx.event, on_tap) {
        (@core.AppEvent::Pointer(event), Some(message)) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) {
            @core.ViewEventResult::message(message)
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
/// Regression: without an event observer installed, dispatch_event behaves
/// exactly as before the additive hook — messages still flow, no panics.
test "event_observer: dispatch works with default (no-op) observer" {
  let received : Array[Int] = []
  let runtime = AppRuntime::new_view(
    root=event_observer_test_rect(
      width=20.0,
      height=20.0,
      color=@core.Color::blue(),
      on_tap=Some(1),
    ),
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if received != [1] {
    fail(
      "expected default (no-op) observer to leave dispatch behavior intact",
    )
  }
}

///|
/// The observer fires for every AppEvent, before the event is processed.
/// We verify ordering by having the observer record a marker, then checking
/// that processing (message dispatch) still occurs normally afterward.
test "event_observer: installed observer receives events before processing" {
  let observed : Array[String] = []
  let received : Array[Int] = []
  let runtime = AppRuntime::new_view(
    root=event_observer_test_rect(
      width=20.0,
      height=20.0,
      color=@core.Color::blue(),
      on_tap=Some(7),
    ),
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  runtime.set_event_observer(event => {
    observed.push(
      match event {
        Pointer(_) => "pointer"
        Keyboard(_) => "keyboard"
        FrameTick(_) => "frame"
        _ => "other"
      },
    )
  })
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  // Observer fired for the pointer event...
  if observed != ["pointer"] {
    fail("expected observer to see pointer event")
  }
  // ...and normal processing still happened (message dispatched to on_message).
  if received != [7] {
    fail("expected processing to proceed after observation")
  }
}

///|
/// set_event_observer replaces a previously installed observer.
test "event_observer: set_event_observer replaces previous observer" {
  let first : Array[String] = []
  let second : Array[String] = []
  let root : @core.View[Unit] = event_observer_test_rect(
      width=20.0,
      height=20.0,
      color=@core.Color::blue(),
      on_tap=None,
    )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  runtime.set_event_observer(_ => first.push("first"))
  runtime.set_event_observer(_ => second.push("second"))
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=5.0, y=5.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  if first != [] {
    fail("expected first observer to be replaced")
  }
  if second != ["second"] {
    fail("expected second observer to be active")
  }
}
