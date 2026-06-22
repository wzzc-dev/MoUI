///|
test "GlyphId::new creates glyph id" {
  let id = GlyphId::new(42)
  assert_eq(id.to_int(), 42)
}

///|
test "GlyphPosition::new with defaults" {
  let pos = GlyphPosition::new(glyph_id=GlyphId::new(1))
  assert_eq(pos.get_x_advance(), 0)
  assert_eq(pos.get_y_advance(), 0)
  assert_eq(pos.get_x_offset(), 0)
  assert_eq(pos.get_y_offset(), 0)
}

///|
test "GlyphInfo::new creates glyph info" {
  let info = GlyphInfo::new(glyph_id=GlyphId::new(5), cluster=10)
  assert_eq(info.get_glyph_id().to_int(), 5)
  assert_eq(info.get_cluster(), 10)
}
