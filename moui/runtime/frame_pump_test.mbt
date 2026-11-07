///|
/// End-to-end coverage for the frame pump that delivers `AppEvent::FrameTick`
/// into animating subtrees, proven through scroll fling inertia: a release
/// with tracked velocity keeps advancing the authoritative offset — and
/// emitting `on_scroll` — one frame at a time until the decay runs out.
///
/// The pointer events are dispatched exactly as a host delivers them and the
/// clock only moves through `advance_time`, so a failure means the runtime or
/// the scroll container stopped pumping, not that a test helper moved an
/// offset behind the runtime's back. The app's `on_scroll` message is the
/// offset itself, so every assertion reads the authoritative value.

///|
/// Present one frame the way `HostRuntimeDriver` does and tick the clock: the
/// explicit redraw clears the flag, the frame tick re-dirties it only while
/// the animation latch is held.
fn fling_frame(runtime~ : @runtime.AppRuntime, time_ms~ : Double) -> Unit {
  runtime.dispatch_event(Redraw(Explicit))
  runtime.advance_time(time_ms)
  ignore(runtime.draw_frame())
}

///|
/// Down, a few clock-separated drag moves, and an Up: the shape every fling
/// test starts from. Moves are 20px per 16ms clock step, so the release
/// velocity is 1.25 px/ms in offset space (finger up, content forward).
fn fling_drag(runtime~ : @runtime.AppRuntime, x~ : Double = 50.0) -> Unit {
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(position=@core.Point::new(x~, y=90.0), phase=Down),
    ),
  )
  for index, y in [80.0, 60.0, 40.0] {
    runtime.advance_time(116.0 + index.to_double() * 16.0)
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Move),
      ),
    )
  }
  runtime.advance_time(156.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(position=@core.Point::new(x~, y=40.0), phase=Up),
    ),
  )
  // The release's paint pass is what observes the fling latch; a host reaches
  // it on the frame it is about to produce.
  ignore(runtime.draw_frame())
}

///|
fn fling_runtime(received~ : Array[Double]) -> @runtime.AppRuntime {
  let child : @core.View[Double] = @views.frame(
    (@views.text("") : @core.View[Double]),
    width=100.0,
    height=500.0,
  )
  let root : @core.View[Double] = @views.scroll_view(
    child,
    width=100.0,
    height=100.0,
    on_scroll=Some((offset : @core.Point) => offset.y),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  runtime
}

///|
test "a released fling keeps advancing the offset and emitting on_scroll" {
  let received : Array[Double] = []
  let runtime = fling_runtime(received~)
  fling_drag(runtime~)
  // The drag itself reported every clamped step; the last one is the
  // authoritative offset at release.
  assert_true(received.length() >= 1)
  let mut drag_messages = received.length()
  let mut last_offset = received[drag_messages - 1]
  assert_true(last_offset == 50.0)
  // Pump frames until the decay ends the fling; every tick must move the
  // offset forward, report it, and stay inside the clamp.
  let mut time_ms = 156.0
  let mut ticks = 0
  let mut moved_after_release = false
  while ticks < 40 && runtime.needs_redraw() {
    time_ms = time_ms + 200.0
    fling_frame(runtime~, time_ms~)
    if received.length() > drag_messages {
      moved_after_release = true
    }
    for index in drag_messages..<received.length() {
      let offset = received[index]
      assert_true(offset > last_offset)
      assert_true(offset <= 400.0)
      last_offset = offset
    }
    drag_messages = received.length()
    ticks = ticks + 1
  }
  assert_true(moved_after_release)
  // The decay terminates: the latch releases instead of ticking forever.
  assert_true(ticks < 40)
  assert_false(runtime.needs_redraw())
  // Settled: more clock produces no further offsets.
  fling_frame(runtime~, time_ms=time_ms + 500.0)
  assert_true(received.length() == drag_messages)
}

///|
test "a release without tracked velocity does not fling" {
  let received : Array[Double] = []
  let runtime = fling_runtime(received~)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=90.0),
        phase=Down,
      ),
    ),
  )
  // One slow move (7px — past the slop — over 200ms = 0.035 px/ms, under the
  // start threshold), then a lift well after the last tracked sample.
  runtime.advance_time(200.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=83.0),
        phase=Move,
      ),
    ),
  )
  runtime.advance_time(500.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=83.0),
        phase=Up,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  // The drag moved 7px; the offset settled there and no frame motion follows.
  assert_true(received.length() == 1)
  assert_true(received[0] == 7.0)
  for index in 0..<6 {
    ignore(index)
    fling_frame(runtime~, time_ms=500.0 + index.to_double() * 200.0 + 200.0)
  }
  assert_true(received.length() == 1)
  assert_false(runtime.needs_redraw())
}

///|
test "a fling into the clamp edge bounces without authoritative overshoot" {
  let received : Array[Double] = []
  let runtime = fling_runtime(received~)
  // A slow drag to mid-scroll first: the release is 300ms after the last
  // tracked move, so it takes the plain release instead of a fling.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=90.0),
        phase=Down,
      ),
    ),
  )
  for index, y in [70.0, 50.0] {
    runtime.advance_time(100.0 + index.to_double() * 300.0)
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=50.0, y~),
          phase=Move,
        ),
      ),
    )
  }
  runtime.advance_time(800.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Up,
      ),
    ),
  )
  assert_true(received.length() == 2)
  assert_true(received[1] == 40.0)
  // A fast downward flick from mid-scroll: offset-space velocity is negative,
  // so the fling glides toward the 0 clamp and hands the leftover speed to
  // the rebound band.
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Down,
      ),
    ),
  )
  runtime.advance_time(816.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=60.0),
        phase=Move,
      ),
    ),
  )
  runtime.advance_time(832.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=70.0),
        phase=Move,
      ),
    ),
  )
  runtime.advance_time(840.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=70.0),
        phase=Up,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  // The authoritative offset never leaves the clamp range, whatever the band
  // paints.
  let mut time_ms = 840.0
  for _ in 0..<12 {
    time_ms = time_ms + 100.0
    fling_frame(runtime~, time_ms~)
    for offset in received {
      assert_true(offset >= 0.0)
      assert_true(offset <= 400.0)
    }
  }
  // The glide moved the offset down to the clamp edge and stopped there.
  assert_true(received[received.length() - 1] == 0.0)
  // The bounce is paint-only, so it settles and the latch releases.
  fling_frame(runtime~, time_ms=time_ms + 300.0)
  assert_false(runtime.needs_redraw())
}

///|
test "a wheel step during a fling ends the glide" {
  let received : Array[Double] = []
  let runtime = fling_runtime(received~)
  fling_drag(runtime~)
  // Pump one fling tick so a glide is provably in flight.
  fling_frame(runtime~, time_ms=356.0)
  assert_true(received.length() > 1)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=0.0 - 30.0),
      ),
    ),
  )
  let wheel_messages = received.length()
  let wheel_offset = received[wheel_messages - 1]
  assert_true(wheel_offset > 50.0)
  // Further ticks must not resume the pre-wheel glide: the offset stays
  // where the wheel put it and no further on_scroll arrives.
  for index in 0..<8 {
    ignore(index)
    fling_frame(runtime~, time_ms=2000.0 + index.to_double() * 300.0)
  }
  assert_true(received.length() == wheel_messages)
  assert_true(received[received.length() - 1] == wheel_offset)
}

///|
test "a press during a fling grabs the surface and stops the glide" {
  let received : Array[Double] = []
  let runtime = fling_runtime(received~)
  fling_drag(runtime~)
  fling_frame(runtime~, time_ms=356.0)
  assert_true(received.length() > 1)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Up,
      ),
    ),
  )
  let grab_messages = received.length()
  for index in 0..<8 {
    ignore(index)
    fling_frame(runtime~, time_ms=2000.0 + index.to_double() * 300.0)
  }
  assert_true(received.length() == grab_messages)
  assert_false(runtime.needs_redraw())
}
