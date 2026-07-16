///|
test "checkbox exposes role value and checked on the control node" {
  let box : @core.View[Unit] = checkbox("Accept", checked=true, on_change=_value => {
    ()
  })
  let info = box.semantics()
  assert_true(info.role == @core.SemanticsRole::Checkbox)
  assert_true(info.checked is Some(true))
  inspect(info.value, content="true")
  inspect(info.label, content="Accept")
}

///|
test "toggle and radio wrap checkbox with public semantics roles" {
  let switch : @core.View[Unit] = toggle("Dark mode", true, on_change=_value => {
    ()
  })
  assert_true(switch.semantics().role == @core.SemanticsRole::Switch)
  assert_true(switch.identity().kind.contains("SemanticsRole"))
  assert_true(switch.children().length() == 1)
  let switch_child = switch.children()[0].semantics()
  assert_true(switch_child.role == @core.SemanticsRole::Checkbox)
  assert_true(switch_child.checked is Some(true))

  let option : @core.View[Unit] = radio("Option A", true, on_change=_value => ())
  assert_true(option.semantics().role == @core.SemanticsRole::Radio)
  assert_true(option.children().length() == 1)
  let option_child = option.children()[0].semantics()
  assert_true(option_child.role == @core.SemanticsRole::Checkbox)
  assert_true(option_child.checked is Some(true))
}
