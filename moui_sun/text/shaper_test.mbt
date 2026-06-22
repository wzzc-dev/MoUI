///|
test "ShapingBuffer::new creates buffer" {
  let font = FontData::new(b"fake_font_data")
  let buffer = ShapingBuffer::new("Hello", font_size=16.0)
  let shaped = buffer.shape(font)
  assert_eq(shaped.glyph_count(), 5) // "Hello" has 5 characters
}

///|
test "ShapingBuffer::shape calculates width" {
  let font = FontData::new(b"fake_font_data")
  let buffer = ShapingBuffer::new("Hi", font_size=10.0)
  let shaped = buffer.shape(font)
  // Each char is 10.0 * 0.6 = 6 pixels wide
  assert_eq(shaped.get_width(), 12)
}

///|
test "ShapingBuffer::shape keeps LTR clusters in logical order" {
  let font = FontData::new(b"fake_font_data")
  let buffer = ShapingBuffer::new(
    "abc",
    direction=TextDirection::left_to_right(),
    font_size=10.0,
  )
  let shaped = buffer.shape(font)
  let glyphs = shaped.get_glyphs()
  let positions = shaped.get_positions()
  assert_eq(glyphs[0].get_glyph_id().to_int(), 0)
  assert_eq(glyphs[0].get_cluster(), 0)
  assert_eq(glyphs[1].get_glyph_id().to_int(), 1)
  assert_eq(glyphs[1].get_cluster(), 1)
  assert_eq(glyphs[2].get_glyph_id().to_int(), 2)
  assert_eq(glyphs[2].get_cluster(), 2)
  assert_eq(positions[0].get_glyph_id().to_int(), 0)
}

///|
test "ShapingBuffer::shape reverses cluster order for basic RTL shaping" {
  let font = FontData::new(b"fake_font_data")
  let buffer = ShapingBuffer::new(
    "abc",
    direction=TextDirection::right_to_left(),
    font_size=10.0,
  )
  let shaped = buffer.shape(font)
  let glyphs = shaped.get_glyphs()
  let positions = shaped.get_positions()
  assert_eq(glyphs[0].get_glyph_id().to_int(), 2)
  assert_eq(glyphs[0].get_cluster(), 2)
  assert_eq(glyphs[1].get_glyph_id().to_int(), 1)
  assert_eq(glyphs[1].get_cluster(), 1)
  assert_eq(glyphs[2].get_glyph_id().to_int(), 0)
  assert_eq(glyphs[2].get_cluster(), 0)
  assert_eq(positions[0].get_glyph_id().to_int(), 2)
  assert_eq(shaped.get_width(), 18)
}

///|
test "ShapedText getters return isolated arrays" {
  let font = FontData::new(b"fake_font_data")
  let shaped = ShapingBuffer::new("abc", font_size=10.0).shape(font)

  let glyphs = shaped.get_glyphs()
  glyphs[0] = glyphs[2]
  glyphs.push(glyphs[1])

  let positions = shaped.get_positions()
  positions[0] = positions[2]
  positions.push(positions[1])

  assert_eq(shaped.glyph_count(), 3)
  assert_eq(shaped.get_width(), 18)
  let fresh_glyphs = shaped.get_glyphs()
  let fresh_positions = shaped.get_positions()
  assert_eq(fresh_glyphs.length(), 3)
  assert_eq(fresh_positions.length(), 3)
  assert_eq(fresh_glyphs[0].get_glyph_id().to_int(), 0)
  assert_eq(fresh_glyphs[0].get_cluster(), 0)
  assert_eq(fresh_positions[0].get_glyph_id().to_int(), 0)
}
