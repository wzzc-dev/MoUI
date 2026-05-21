///|
test "cosmic text layout adapter measures caret positions" {
  let layout = measure_text_layout(
    @core.TextLayoutInput::new(
      text="abcd",
      font=@core.FontSpec::new(size=20.0),
      max_width=30.0,
    ),
  )
  inspect(layout.size.width, content="30")
  inspect(layout.size.height, content="25")
  inspect(layout.baseline, content="16")
  inspect(layout.caret_positions.length(), content="5")
  inspect(layout.caret_positions[4], content="30")
}

///|
test "cosmic text layout adapter uses shaped glyph advances" {
  let ascii = measure_text_layout(
    @core.TextLayoutInput::new(text="a", font=@core.FontSpec::new(size=20.0)),
  )
  let digit = measure_text_layout(
    @core.TextLayoutInput::new(text="1234", font=@core.FontSpec::new(size=20.0)),
  )
  let cjk = measure_text_layout(
    @core.TextLayoutInput::new(text="你", font=@core.FontSpec::new(size=20.0)),
  )
  inspect(ascii.caret_positions[1], content="20")
  inspect(digit.caret_positions[4], content="80")
  inspect(cjk.caret_positions[1], content="20")
}
