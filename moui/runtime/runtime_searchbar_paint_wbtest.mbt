///|
test "searchbar paints vector icons instead of font fallback glyphs" {
  let query = State::new("abc")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::SearchBarSpec({
      key: None,
      query: query.binding(),
      placeholder: "Search",
      font: FontSpec::new(size=14.0, weight=400),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: Brush::solid(Color::white()),
      border: None,
      focused_border: None,
      cursor_color: Color::blue(),
      corner_radius: 8.0,
      on_submit: None,
      on_clear: None,
    }),
    size=Size::new(width=240.0, height=44.0),
  )
  let commands = runtime.draw_commands()
  assert_false(has_draw_text(commands, "?"))
  assert_true(commands.any(command => command is DrawCommand::DrawPath(_)))
  assert_true(
    commands.any(command => command is DrawCommand::StrokeRoundedRect(_, _, _)),
  )
}
