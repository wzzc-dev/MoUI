///|
test "theme helper customizes core theme tokens" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let motion : @core.MotionScale = {
    fast_ms: 80.0,
    normal_ms: 140.0,
    slow_ms: 220.0,
    easing: @core.Easing::EaseOut,
  }
  let theme = @views.theme(
    base=@core.Theme::dark(),
    accent~,
    spacing=14.0,
    corner_radius=10.0,
    motion~,
  )
  assert_true(theme.scheme == @core.ColorScheme::Dark)
  assert_true(theme.palette.primary == accent)
  inspect(theme.spacing_scale.sm, content="14")
  inspect(theme.radius_scale.md, content="10")
  inspect(theme.motion.normal_ms, content="140")
}

///|
test "scalar controls can resolve colors from theme" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let theme = @views.theme(accent~)
  let runtime = test_runtime(
    @views.column([
      @views.checkbox(
        "Themed checkbox",
        checked=true,
        on_change=_value => (),
        theme~,
      ),
      @views.progress(0.4, theme~, width=160.0),
      @views.slider(0.6, theme~, width=160.0),
      @views.toggle("Themed toggle", true, on_change=_value => (), theme~),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, accent))
  assert_true(has_text(draw, "Themed toggle"))
}

///|
test "picker controls can resolve surface style from theme" {
  let surface = @core.Color::rgba(r=0.14, g=0.18, b=0.24)
  let base = @core.Theme::light()
  let theme = @views.theme(
    base~,
    palette={ ..base.palette, surface, },
    corner_radius=18.0,
  )
  let items = [
    @views.picker_item("native", "Native"),
    @views.picker_item("web", "Web"),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.picker(items, selected="native", on_select=_value => (), theme~),
      @views.datepicker(
        selected=@core.DateValue::new(year=2026, month=5, day=21),
        on_select=_value => (),
        theme~,
      ),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, surface))
}
