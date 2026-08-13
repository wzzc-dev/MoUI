///|
test "checkbox exposes role value and checked state" {
  let box : @core.View[Unit] = checkbox("Accept", checked=true, on_change=_value => {
    ()
  })
  let info = box.semantics()
  assert_true(info.role == Some(@core.SemanticsRole::Checkbox))
  assert_true(info.checked is Some(@core.SemanticsCheckedState::Checked))
  assert_eq(info.value, Some("true"))
  assert_eq(info.label, Some("Accept"))
}

///|
test "unchecked checkbox reports checked false" {
  let box : @core.View[Unit] = checkbox("Opt-in", checked=false, on_change=_value => {
    ()
  })
  let info = box.semantics()
  assert_true(info.role == Some(@core.SemanticsRole::Checkbox))
  assert_true(info.checked is Some(@core.SemanticsCheckedState::Unchecked))
  assert_eq(info.value, Some("false"))
}

///|
test "toggle wraps checkbox with switch semantics" {
  let switch : @core.View[Unit] = toggle("Dark mode", true, on_change=_value => {
    ()
  })
  assert_true(switch.semantics().role == Some(@core.SemanticsRole::Switch))
  // Toggle wraps a checkbox as its child
  assert_true(switch.children().length() >= 1)
  let child = switch.children()[0].semantics()
  assert_true(child.role == Some(@core.SemanticsRole::Checkbox))
  assert_true(child.checked is Some(@core.SemanticsCheckedState::Checked))
}
