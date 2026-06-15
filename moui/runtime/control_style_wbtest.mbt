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
  assert_true(style.normal.border.unwrap().width == 1.0)
  assert_true(style.focused.border.unwrap().width == 2.0)
  assert_true(style.cursor_color == Theme::light().palette.primary)
}

///|
test "scalar control styles derive from theme tokens" {
  let accent = Color::rgba(r=0.86, g=0.18, b=0.42)
  let track = Color::rgba(r=0.12, g=0.16, b=0.22)
  let base = Theme::light()
  let palette = {
    ..base.palette,
    primary: accent,
    surface: track,
    surface_variant: track,
  }
  let radius_scale = { ..base.radius_scale, md: 14.0, pill: 42.0 }
  let danger = Color::rgba(r=0.92, g=0.18, b=0.28)
  let success = Color::rgba(r=0.16, g=0.72, b=0.38)
  let semantic_colors = { ..base.semantic_colors, danger, success }
  let theme = { ..base, palette, semantic_colors, radius_scale }
  let choice = ChoiceControlStyle::default(theme~)
  let progress = ProgressStyle::default(theme~)
  let slider = SliderStyle::default(theme~)
  assert_true(choice.selected_color == accent)
  assert_true(choice.foreground == palette.foreground)
  inspect(choice.control_size, content="20")
  assert_true(progress.foreground == accent)
  assert_true(progress.background == track)
  inspect(progress.radius, content="42")
  assert_true(slider.foreground == accent)
  assert_true(slider.thumb_color == accent)
  assert_true(slider.background == track)
  inspect(slider.track_height, content="6")
  let picker = PickerStyle::default(theme~)
  assert_true(picker.foreground == theme.foreground)
  assert_true(picker.background == Brush::solid(track))
  inspect(picker.radius, content="14")
  inspect(picker.popup_max_height, content="200")
  let feedback = FeedbackStyle::default(theme~)
  assert_true(feedback.success.foreground == success)
  assert_true(feedback.danger.border == danger.multiply_alpha(0.72))
  inspect(feedback.radius, content="14")
  let badge = BadgeStyle::default(theme~)
  assert_true(badge.success.background == success)
  inspect(badge.radius, content="42")
  let validation = FormValidationStyle::default(theme~)
  assert_true(validation.foreground == danger)
  assert_true(validation.background == danger.multiply_alpha(0.12))
  inspect(validation.radius, content="14")
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
      border: Some(BorderStyle::new(brush=gradient, width=2.0)),
      shadow: Some(
        ShadowStyle::new(
          color=shadow.color,
          offset=shadow.offset,
          blur_radius=shadow.blur_radius,
          spread=shadow.spread,
        ),
      ),
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
      command
      is DrawCommand::StrokeRoundedRectBrush(_, Brush::LinearGradient(_), 2.0)
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
      border: Some(BorderStyle::new(brush=gradient, width=1.0)),
      focused_border: Some(BorderStyle::new(brush=gradient, width=2.0)),
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
      command
      is DrawCommand::StrokeRoundedRectBrush(_, Brush::LinearGradient(_), 1.0)
    }),
  )
}
