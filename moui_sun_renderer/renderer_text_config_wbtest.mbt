///|
test "sun text layout config carries spacing and line height" {
  let font = @core.FontSpec::new(
    size=14.0,
    line_height=20.3,
    letter_spacing=-0.2,
  )
  let config = sun_text_layout_config(font, 120.0)
  assert_eq(config.line_height, 20.3)
  assert_eq(config.letter_spacing, -0.2)
  assert_eq(config.font_size, 14.0)
}

///|
test "sun text layout config keeps provider leading when unset" {
  let font = @core.FontSpec::new(size=14.0)
  let config = sun_text_layout_config(font, 120.0)
  assert_eq(config.line_height, 16.8)
  assert_eq(config.letter_spacing, 0.0)
}
