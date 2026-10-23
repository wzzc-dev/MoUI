///|
/// End-to-end coverage for the frame-tick wake that lets a held pointer
/// complete a duration-based gesture.
///
/// `moui/core/gesture_wbtest.mbt` drives the recognizer with an explicit clock
/// per event. These tests prove the two runtime behaviors a real host has to
/// provide, because a finger that holds still produces no further pointer
/// sample at all:
///
/// - an armed long press claims the active-animation latch, so the runtime keeps
///   needing another frame; and
/// - each of those frames re-samples the pressed position as a `Move`, which is
///   the only clock sample the recognizer gets before its duration.
///
/// No test dispatches a `Move` between the `Down` and the deadline, so a failure
/// means the gesture stopped waking on elapsed time rather than the recognizer
/// being wrong.

///|
/// Present one frame the way `HostRuntimeDriver` does -- the explicit redraw
/// clears the redraw flag, the next frame tick re-dirties it only while the
/// animation latch is held -- and report whether the host has to produce another
/// frame.
///
/// The answer lags one frame behind a state change by design: the paint pass is
/// what observes the latch, so releasing a gesture becomes visible on the frame
/// that repaints it.
fn long_press_frame(runtime~ : @runtime.AppRuntime, time_ms~ : Double) -> Bool {
  runtime.dispatch_event(Redraw(Explicit))
  runtime.advance_time(time_ms)
  ignore(runtime.draw_frame())
  runtime.needs_redraw()
}

///|
fn long_press_press(
  runtime~ : @runtime.AppRuntime,
  x~ : Double = 10.0,
  y~ : Double = 10.0,
  phase~ : @core.PointerPhase = Down,
) -> Unit {
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~)),
  )
}

///|
fn long_press_runtime(received~ : Array[String]) -> @runtime.AppRuntime {
  let root : @core.View[String] = runtime_test_rect(
    width=100.0,
    height=40.0,
    color=@core.Color::blue(),
  ).on_long_press("long press")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  runtime
}

///|
/// A hold alone reaches the duration: the frame after the `Down` claims another,
/// the frames before the deadline are still quiet, the deadline delivers the
/// message exactly once, and the settled subtree stops asking.
test "runtime fires a long press from the frame tick without a pointer move" {
  let received : Array[String] = []
  let runtime = long_press_runtime(received~)
  long_press_press(runtime~)
  assert_true(received.is_empty())
  assert_true(long_press_frame(runtime~, time_ms=0.0))
  assert_true(long_press_frame(runtime~, time_ms=250.0))
  assert_true(received.is_empty())
  assert_true(long_press_frame(runtime~, time_ms=520.0))
  assert_eq(received, ["long press"])
  // Settled: the latch is released, and the still-held pointer has nothing left
  // to re-sample.
  assert_false(long_press_frame(runtime~, time_ms=900.0))
  assert_eq(received, ["long press"])
}

///|
/// Moving past the slop limit cancels the hold, and the cancelled subtree must
/// release the frame latch instead of ticking until the stale horizon.
test "runtime drops the long press wake when the hold leaves the slop limit" {
  let received : Array[String] = []
  let runtime = long_press_runtime(received~)
  long_press_press(runtime~)
  assert_true(long_press_frame(runtime~, time_ms=0.0))
  long_press_press(runtime~, x=60.0, phase=Move)
  // The repaint that observes the cancellation is the frame that releases it.
  assert_true(long_press_frame(runtime~, time_ms=250.0))
  assert_false(long_press_frame(runtime~, time_ms=520.0))
  assert_true(received.is_empty())
}

///|
/// Releasing the pointer revokes the pending wake: no re-sampled `Move` is
/// emitted, so a clock that passes the deadline finds nothing to evaluate and
/// the frame loop stops.
test "runtime stops the long press wake when the pointer is released" {
  let received : Array[String] = []
  let runtime = long_press_runtime(received~)
  long_press_press(runtime~)
  assert_true(long_press_frame(runtime~, time_ms=0.0))
  assert_true(long_press_frame(runtime~, time_ms=250.0))
  long_press_press(runtime~, phase=Up)
  assert_true(long_press_frame(runtime~, time_ms=520.0))
  assert_false(long_press_frame(runtime~, time_ms=600.0))
  assert_true(received.is_empty())
}

///|
/// A hold that drifted inside the slop limit keeps its wake and completes at the
/// deadline. This pins that an in-slop `Move` does not drop the pending wake; it
/// cannot pin that the synthesised sample follows the pointer, because a real
/// `Move` already re-evaluates the recognizer at its own position.
test "runtime keeps waking a long press that drifted inside the slop limit" {
  let received : Array[String] = []
  let runtime = long_press_runtime(received~)
  long_press_press(runtime~)
  assert_true(long_press_frame(runtime~, time_ms=0.0))
  // 6px: inside the 8px slop limit, so the hold stays armed.
  long_press_press(runtime~, x=16.0, phase=Move)
  assert_true(long_press_frame(runtime~, time_ms=250.0))
  assert_true(received.is_empty())
  assert_true(long_press_frame(runtime~, time_ms=520.0))
  assert_eq(received, ["long press"])
}

///|
/// A tree with no duration gesture must not fall into a frame loop: once the
/// press settles, an advancing clock leaves nothing for the host to present.
test "runtime frame ticks stay passive without an armed gesture" {
  let received : Array[String] = []
  let root : @core.View[String] = runtime_test_rect(
    width=100.0,
    height=40.0,
    color=@core.Color::blue(),
    on_tap=Some("tapped"),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=40.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  long_press_press(runtime~)
  assert_false(long_press_frame(runtime~, time_ms=0.0))
  long_press_press(runtime~, phase=Up)
  assert_false(long_press_frame(runtime~, time_ms=250.0))
  assert_false(long_press_frame(runtime~, time_ms=520.0))
  assert_eq(received, ["tapped"])
}
