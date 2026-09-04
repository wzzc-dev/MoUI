///|
test "ascii fast path matches the fallback boundary walk" {
  let samples : Array[String] = [
    "", "a", "\n", "\r", "\r\n", "\r\r\n\n", "line one\r\nline two\r\n",
    "tabs\tand\tcontrols\u{1}\u{2}", "mixed ascii \u{D}x", "ends in CR\r",
  ]
  for text in samples {
    let chars = text.to_array()
    let expected : Array[Int] = [0]
    if chars.length() > 0 {
      let mut index = 1
      let mut last_boundary = 0
      while index < chars.length() {
        if fallback_grapheme_should_break(chars, last_boundary, index) {
          expected.push(index)
          last_boundary = index
        }
        index = index + 1
      }
      expected.push(chars.length())
    }
    assert_eq(
      TextGraphemeBoundaries::new(text~).boundaries(),
      expected,
    )
  }
}
