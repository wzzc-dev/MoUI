///|
test "button styles expose expected variants" {
  let theme = Theme::light()
  let filled = ButtonStyle::filled(theme~)
  let outline = ButtonStyle::outline(theme~)
  let ghost = ButtonStyle::ghost(theme~)
  assert_true(filled.normal.background is Brush::Solid(_))
  assert_true(outline.normal.border is Some(_))
  assert_true(ghost.normal.border is None)
}

///|
test "text field styles expose focus colors" {
  let style = TextFieldStyle::filled(theme=Theme::light())
  assert_true(style.normal.border_width == 1.0)
  assert_true(style.focused.border_width == 2.0)
  assert_true(style.cursor_color == Theme::light().palette.primary)
}

///|
test "button paint preserves brush border and shadow commands" {
  let gradient = Brush::linear_gradient(
    start=Point::new(x=0.0, y=0.0),
    end=Point::new(x=100.0, y=0.0),
    start_color=Color::blue(),
    end_color=Color::white(),
  )
  let shadow = ShadowSpec::new(
    rect=RoundedRect::new(
      rect=Rect::new(x=0.0, y=0.0, width=100.0, height=40.0),
      radius=8.0,
    ),
    color=Color::rgba(r=0.0, g=0.0, b=0.0, a=0.2),
  )
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Brush",
      size: Size::new(width=100.0, height=40.0),
      font: FontSpec::new(),
      foreground: Color::white(),
      background: gradient,
      hovered_background: gradient,
      pressed_background: gradient,
      border: Some(gradient),
      border_width: 2.0,
      shadow: Some(shadow),
      corner_radius: 8.0,
      on_click: None,
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => {
      command is DrawCommand::FillRoundedRectBrush(_, Brush::LinearGradient(_))
    }),
  )
  assert_true(
    commands.any(command => {
      command is DrawCommand::StrokeRoundedRectBrush(_, Brush::LinearGradient(_), 2.0)
    }),
  )
  assert_true(commands.any(command => command is DrawCommand::DrawShadow(_)))
}

///|
test "text field paint preserves brush stroke commands" {
  let value = State::new("")
  let gradient = Brush::linear_gradient(
    start=Point::new(x=0.0, y=0.0),
    end=Point::new(x=120.0, y=0.0),
    start_color=Color::white(),
    end_color=Color::gray(),
  )
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::TextFieldSpec({
      key: None,
      value: value.binding(),
      placeholder: "Name",
      size: Size::new(width=120.0, height=40.0),
      font: FontSpec::new(),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: gradient,
      border: Some(gradient),
      focused_border: Some(gradient),
      border_width: 1.0,
      focused_border_width: 2.0,
      cursor_color: Color::blue(),
      corner_radius: 8.0,
      on_submit: None,
    }),
    size=Size::new(width=120.0, height=40.0),
  )
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => {
      command is DrawCommand::FillRoundedRectBrush(_, Brush::LinearGradient(_))
    }),
  )
  assert_true(
    commands.any(command => {
      command is DrawCommand::StrokeRoundedRectBrush(_, Brush::LinearGradient(_), 1.0)
    }),
  )
}
