///|
/// `View::cursor` is a pure declaration: it must expose the style the app asked
/// for, stay transparent (no semantics, no focus stop, no capture), and degrade
/// `Inherit`/unknown values to the arrow at the host boundary.

///|
fn cursor_test_leaf() -> @core.View[Unit] {
  @core.View::from_node(ModTestNode::{
    kind: "cursor-test-leaf",
    size: @core.Size::new(width=8.0, height=8.0),
  })
}

///|
test "cursor defaults to Inherit when no style is declared" {
  let base = cursor_test_leaf()
  assert_eq(base.pointer_cursor(), @core.CursorStyle::Inherit)
}

///|
test "cursor exposes the declared style on the wrapped view" {
  let styled = cursor_test_leaf().cursor(
    @core.CursorStyle::Icon(@core.CursorIcon::CursorColResize),
  )
  assert_eq(
    styled.pointer_cursor(),
    @core.CursorStyle::Icon(@core.CursorIcon::CursorColResize),
  )
  // Nested declarations keep the innermost wrapper's style; resolution against
  // the hit chain is the runtime's job.
  let replaced = styled.cursor(@core.CursorStyle::Default)
  assert_eq(replaced.pointer_cursor(), @core.CursorStyle::Default)
}

///|
test "cursor is transparent for semantics and focus" {
  let base = cursor_test_leaf()
  let styled = base.cursor(
    @core.CursorStyle::Icon(@core.CursorIcon::CursorPointer),
  )
  assert_eq(styled.semantics(), base.semantics())
  assert_false(styled.accepts_focus())
}

///|
test "cursor style degrades Inherit and Default to the arrow icon" {
  assert_eq(@core.CursorStyle::Inherit.icon(), @core.CursorIcon::CursorDefault)
  assert_eq(@core.CursorStyle::Default.icon(), @core.CursorIcon::CursorDefault)
  assert_eq(
    @core.CursorStyle::Icon(@core.CursorIcon::CursorNotAllowed).icon(),
    @core.CursorIcon::CursorNotAllowed,
  )
}

///|
test "cursor distinguishes Inherit from an explicit Default" {
  assert_true(@core.CursorStyle::Inherit.is_inherit())
  assert_false(@core.CursorStyle::Default.is_inherit())
  assert_false(
    @core.CursorStyle::Icon(@core.CursorIcon::CursorGrab).is_inherit(),
  )
}
