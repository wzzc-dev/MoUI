///|
test "enhanced input wrappers compose public controls" {
  let root : @core.View[Unit] = @views.form([
    @views.input_group(
      child=@views.text_field("Grouped", on_input=_value => ()),
      prefix=Some(@views.text("$", width=20.0, height=24.0)),
      suffix=Some(@views.text("USD", width=44.0, height=24.0)),
    ),
    @views.clearable_text_field("Search", on_input=_value => (), on_clear=()),
    @views.password_field(
      "secret",
      on_input=_value => (),
      revealed=false,
      on_toggle_reveal=(),
    ),
    @views.number_field("42", on_input=_value => (), on_step=Some(_delta => ())),
    @views.stepper(on_decrement=(), on_increment=(), label="Page"),
    @views.multiline_text_area_shell("Line one", on_input=_value => ()),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=380.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Grouped"))
  assert_true(has_text(commands, "USD"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Show"))
  assert_false(has_text(commands, "secret"))
  assert_true(has_text(commands, "******"))
  assert_true(has_text(commands, "42"))
  assert_true(has_text(commands, "Page"))
  assert_true(has_text(commands, "Line one"))
}
