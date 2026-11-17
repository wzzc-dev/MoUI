///|
/// The cursor session is the exactly-once gate between the runtime's resolved
/// style and the native cursor call. These tests pin the dedupe rules: a stream
/// that stays inside one declaration must never reach the host twice, and a
/// window that never declares anything must never reach it at all.

///|
fn cursor_test_window(value : Int32) -> @backend_host.WindowId {
  @backend_host.WindowId::new(value)
}

///|
test "cursor session starts at the arrow the host already shows" {
  let session = @input.CursorSession::new()
  assert_eq(session.applied(cursor_test_window(1)), @core.CursorStyle::Default)
  // No declaration yet: nothing to push.
  assert_true(
    session.sync(cursor_test_window(1), @core.CursorStyle::Default) is None,
  )
}

///|
test "cursor session pushes only the transitions" {
  let session = @input.CursorSession::new()
  let window = cursor_test_window(7)
  let resize = @core.CursorStyle::Icon(@core.CursorIcon::CursorColResize)
  assert_eq(session.sync(window, resize), Some(resize))
  // Repeated samples inside the same declaration: silent.
  assert_true(session.sync(window, resize) is None)
  assert_true(session.sync(window, resize) is None)
  assert_eq(session.applied(window), resize)
  // Leaving the declaring region pushes the arrow back exactly once.
  assert_eq(
    session.sync(window, @core.CursorStyle::Default),
    Some(@core.CursorStyle::Default),
  )
  assert_true(session.sync(window, @core.CursorStyle::Default) is None)
}

///|
test "cursor session keeps windows independent and forgets on dispose" {
  let session = @input.CursorSession::new()
  let first = cursor_test_window(1)
  let second = cursor_test_window(2)
  let hand = @core.CursorStyle::Icon(@core.CursorIcon::CursorPointer)
  assert_eq(session.sync(first, hand), Some(hand))
  // A second window starts from its own arrow, not the first window's style.
  assert_true(session.sync(second, @core.CursorStyle::Default) is None)
  assert_eq(session.sync(second, hand), Some(hand))
  session.forget(first)
  // After dispose a recycled window id must not inherit the stale style.
  assert_eq(session.applied(first), @core.CursorStyle::Default)
  assert_eq(session.sync(first, hand), Some(hand))
}
