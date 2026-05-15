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
