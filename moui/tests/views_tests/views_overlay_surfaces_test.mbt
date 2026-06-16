///|
test "popover dropdown combobox and autocomplete compose menu surfaces" {
  let items = [
    @views.MenuItem::new(id="one", label="One", message=()),
    @views.MenuItem::new(id="two", label="Two", message=(), enabled=false),
  ]
  let dropdown_state = @views.DropdownState::new(expanded=true, selected="one")
  let root : @core.View[Unit] = @views.column([
    @views.popover(
      anchor=@views.button("Anchor", on_click=()),
      content=@views.text("Popover content", width=160.0),
      expanded=true,
    ),
    @views.dropdown("Mode", items, state=dropdown_state, on_toggle=()),
    @views.combobox(
      "O",
      on_input=_value => (),
      items,
      expanded=true,
      on_toggle=(),
    ),
    @views.autocomplete("T", on_input=_value => (), items, expanded=true),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=520.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Anchor"))
  assert_true(has_text(commands, "Popover content"))
  assert_true(has_text(commands, "Mode: One"))
  assert_true(has_text(commands, "One"))
  assert_true(has_text(commands, "Two"))
  assert_true(has_text(commands, "Open"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Mode: One") is Some(dropdown) else {
    fail("expected dropdown anchor semantics")
  }
  assert_true(dropdown.role == @core.SemanticsRole::Menu)
  assert_true(dropdown.state.expanded)
  assert_true(
    dropdown.actions.any(action => action == @core.SemanticsAction::Collapse),
  )
  guard find_semantics_label(semantics, "Mode options") is Some(options) else {
    fail("expected dropdown menu semantics")
  }
  assert_true(options.role == @core.SemanticsRole::Menu)
  guard find_semantics_label(semantics, "One") is Some(one) else {
    fail("expected selected dropdown option")
  }
  assert_true(one.state.selected)
  guard find_semantics_label(semantics, "Two") is Some(two) else {
    fail("expected disabled dropdown option")
  }
  assert_true(two.state.disabled)
}
