///|
/// Smoke tests for picker, dropdown, combobox, autocomplete, datepicker, searchbar, command_palette.

///|
test "picker smoke" {
  let view : @core.View[Unit] = @views.picker(
    [@views.picker_item("a", "Option A")],
    selected="a",
    on_select=fn(_s) { () },
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "dropdown smoke" {
  let state = @views.DropdownState::new(selected="a")
  let view : @core.View[Unit] = @views.dropdown(
    "Select",
    [@views.MenuItem::new(id="a", label="Option A", message=())],
    state~,
    on_toggle=(),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "combobox smoke" {
  let view : @core.View[Unit] = @views.combobox(
    "",
    on_input=fn(_s) { () },
    [],
    expanded=false,
    on_toggle=(),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "autocomplete smoke" {
  let view : @core.View[Unit] = @views.autocomplete(
    "",
    on_input=fn(_s) { () },
    [],
    expanded=false,
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "datepicker smoke" {
  let view : @core.View[Unit] = @views.datepicker(
    selected=@core.DateValue::new(year=2024, month=1, day=1),
    on_select=fn(_d) { () },
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "searchbar smoke" {
  let view : @core.View[Unit] = @views.searchbar(query="", on_input=fn(_s) {
    ()
  })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "command_palette smoke" {
  let view : @core.View[Unit] = @views.command_palette([], on_select=fn(
    _intent,
  ) {
    ()
  })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
