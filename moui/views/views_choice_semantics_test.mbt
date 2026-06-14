///|
test "grouped choice controls compose selections and chips" {
  let choices = [
    @views.choice_item("native", "Native"),
    @views.choice_item("web", "Web"),
    @views.choice_item("test", "Test"),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.radio_group(choices, selected="native", on_select=_id => ()),
    @views.checkbox_group(choices, selected=["native", "test"], on_change=(
      _id,
      _checked,
    ) => ()),
    @views.segmented_control(choices, selected="web", on_select=_id => ()),
    @views.row([
      @views.chip("Stable", selected=true),
      @views.tag("Tag"),
      @views.filter_chip("Filter", selected=false, on_change=_value => ()),
      @views.choice_chip("Choice", selected=true, on_select=()),
    ]),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=560.0, height=360.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Native"))
  assert_true(has_text(commands, "Web"))
  assert_true(has_text(commands, "Test"))
  assert_true(has_text(commands, "Stable"))
  assert_true(has_text(commands, "Tag"))
  assert_true(has_text(commands, "Filter"))
  assert_true(has_text(commands, "Choice"))
}

///|
test "component semantics expose selection validation and expanded states" {
  let choices = [
    @views.choice_item("native", "Native"),
    @views.choice_item("web", "Web"),
  ]
  let tree_items = [
    @views.tree_item(id="root", label="Root", children=[
      @views.tree_item(id="leaf", label="Leaf"),
    ]),
  ]
  let commands = [
    @views.MenuItem::new(id="save", label="Save", message=()),
    @views.MenuItem::new(id="open", label="Open", message=()),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.form_field(
      label="Email",
      child=@views.text_field("", on_input=_value => ()),
      error="Email required",
      required=true,
    ),
    @views.segmented_control(choices, selected="web", on_select=_id => ()),
    @views.tree_view(tree_items, expanded=["root"], selected="leaf"),
    @views.button_group(commands, selected="save"),
    @views.button("Pressed action").semantics_pressed(),
    @views.button("Disabled action").disabled(),
    @views.inline_error("Sync failed"),
  ])
  let semantics = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=520.0),
  ).semantics()
  guard find_semantics_label(semantics, "Email, invalid, Email required")
    is Some(email) else {
    fail("expected email form field semantics")
  }
  assert_true(email.role == @core.SemanticsRole::FormField)
  assert_true(email.state.invalid)
  assert_true(email.state.required)
  inspect(email.description, content="Email required")
  guard find_semantics_label(semantics, "Web") is Some(web) else {
    fail("expected selected segment semantics")
  }
  assert_true(web.role == @core.SemanticsRole::Tab)
  assert_true(web.state.selected)
  guard find_semantics_label(semantics, "Root") is Some(root_item) else {
    fail("expected root tree item semantics")
  }
  assert_true(root_item.role == @core.SemanticsRole::TreeItem)
  assert_true(root_item.state.expanded)
  guard find_semantics_label(semantics, "Leaf") is Some(leaf_item) else {
    fail("expected leaf tree item semantics")
  }
  assert_true(leaf_item.state.selected)
  guard find_semantics_label(semantics, "Save") is Some(save) else {
    fail("expected button group selected item")
  }
  assert_true(save.state.selected)
  guard find_semantics_label(semantics, "Pressed action") is Some(pressed) else {
    fail("expected pressed semantics")
  }
  assert_true(pressed.state.pressed)
  guard find_semantics_label(semantics, "Disabled action") is Some(disabled) else {
    fail("expected disabled semantics")
  }
  assert_true(disabled.state.disabled)
  guard find_semantics_label(semantics, "Error: Sync failed")
    is Some(inline_error) else {
    fail("expected inline error semantics")
  }
  assert_true(inline_error.role == @core.SemanticsRole::Group)
  assert_true(inline_error.state.invalid)
}
