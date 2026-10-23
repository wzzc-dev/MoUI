///|
fn text_field_semantics_at(
  view : @core.View[Unit],
  depth~ : Int32,
) -> @core.ViewSemanticsInfo? {
  let info = view.semantics()
  if info.role == Some(TextField) {
    Some(info)
  } else if depth == 0 {
    None
  } else {
    let mut found : @core.ViewSemanticsInfo? = None
    for _index, child in view.children() {
      if found is None {
        found = text_field_semantics_at(child, depth=depth - 1)
      }
    }
    found
  }
}

///|
fn password_field_semantics(revealed~ : Bool) -> @core.ViewSemanticsInfo {
  let view : @core.View[Unit] = @controls.password_field(
    "hunter2",
    on_input=_text => (),
    revealed~,
    on_toggle_reveal=(),
  )
  text_field_semantics_at(view, depth=8).unwrap()
}

///|
test "masked password field declares protected content and only the mask" {
  let info = password_field_semantics(revealed=false)
  assert_true(info.password is Some(true))
  assert_eq(info.value, Some("*******"))
}

///|
test "revealed password field stops declaring protected content" {
  let info = password_field_semantics(revealed=true)
  assert_true(info.password is Some(false))
  assert_eq(info.value, Some("hunter2"))
}

///|
test "a plain text field declares no read-only or password intent" {
  let view : @core.View[Unit] = @text.text_field("hello", on_input=_text => ())
  let info = text_field_semantics_at(view, depth=8).unwrap()
  assert_true(info.password is None)
  assert_true(info.read_only is None)
  assert_true(info.multiline is Some(false))
}

///|
test "a plain text area declares no read-only or password intent" {
  let view : @core.View[Unit] = @text.text_area("hello", on_input=_text => ())
  let info = text_field_semantics_at(view, depth=8).unwrap()
  assert_true(info.password is None)
  assert_true(info.read_only is None)
  assert_true(info.multiline is Some(true))
}
