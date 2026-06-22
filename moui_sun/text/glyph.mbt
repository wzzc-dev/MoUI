///|
/// Glyph ID type (wraps Int)
struct GlyphId {
  id : Int
} derive(Eq, Debug)

///|
/// Create a glyph ID
pub fn GlyphId::new(id : Int) -> GlyphId {
  { id, }
}

///|
/// Get the underlying ID value
pub fn GlyphId::to_int(self : GlyphId) -> Int {
  self.id
}

///|
/// Glyph position with advance and offset
struct GlyphPosition {
  glyph_id : GlyphId
  x_advance : Int
  y_advance : Int
  x_offset : Int
  y_offset : Int
} derive(Eq, Debug)

///|
/// Create a glyph position
pub fn GlyphPosition::new(
  glyph_id~ : GlyphId,
  x_advance? : Int = 0,
  y_advance? : Int = 0,
  x_offset? : Int = 0,
  y_offset? : Int = 0,
) -> GlyphPosition {
  { glyph_id, x_advance, y_advance, x_offset, y_offset }
}

///|
/// Get the glyph id for this position.
pub fn GlyphPosition::get_glyph_id(self : GlyphPosition) -> GlyphId {
  self.glyph_id
}

///|
/// Get horizontal advance in font units.
pub fn GlyphPosition::get_x_advance(self : GlyphPosition) -> Int {
  self.x_advance
}

///|
/// Get vertical advance in font units.
pub fn GlyphPosition::get_y_advance(self : GlyphPosition) -> Int {
  self.y_advance
}

///|
/// Get horizontal offset in font units.
pub fn GlyphPosition::get_x_offset(self : GlyphPosition) -> Int {
  self.x_offset
}

///|
/// Get vertical offset in font units.
pub fn GlyphPosition::get_y_offset(self : GlyphPosition) -> Int {
  self.y_offset
}

///|
/// Glyph info with cluster mapping
struct GlyphInfo {
  glyph_id : GlyphId
  cluster : Int
} derive(Eq, Debug)

///|
/// Create glyph info
pub fn GlyphInfo::new(glyph_id~ : GlyphId, cluster~ : Int) -> GlyphInfo {
  { glyph_id, cluster }
}

///|
/// Get the shaped glyph id.
pub fn GlyphInfo::get_glyph_id(self : GlyphInfo) -> GlyphId {
  self.glyph_id
}

///|
/// Get the source cluster index.
pub fn GlyphInfo::get_cluster(self : GlyphInfo) -> Int {
  self.cluster
}

///|
/// Result of text shaping operation
struct ShapedText {
  glyphs : Array[GlyphInfo]
  positions : Array[GlyphPosition]
  width : Int
} derive(Debug)

///|
/// Get the total width of the shaped text
pub fn ShapedText::get_width(self : ShapedText) -> Int {
  self.width
}

///|
/// Get the glyph count
pub fn ShapedText::glyph_count(self : ShapedText) -> Int {
  self.glyphs.length()
}

///|
/// Get shaped glyph infos.
pub fn ShapedText::get_glyphs(self : ShapedText) -> Array[GlyphInfo] {
  copy_glyph_infos(self.glyphs)
}

///|
/// Get shaped glyph positions.
pub fn ShapedText::get_positions(self : ShapedText) -> Array[GlyphPosition] {
  copy_glyph_positions(self.positions)
}

///|
fn copy_glyph_infos(glyphs : Array[GlyphInfo]) -> Array[GlyphInfo] {
  let copied = []
  for glyph in glyphs {
    copied.push(glyph)
  }
  copied
}

///|
fn copy_glyph_positions(
  positions : Array[GlyphPosition],
) -> Array[GlyphPosition] {
  let copied = []
  for position in positions {
    copied.push(position)
  }
  copied
}
