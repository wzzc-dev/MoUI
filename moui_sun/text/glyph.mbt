///|
/// Glyph ID type (wraps Int)
struct GlyphId {
  id : Int32
} derive(Eq, Debug)

///|
pub extend GlyphId with Debug::{to_repr}

///|
pub extend GlyphId with Eq::{not_equal, equal}

///|
/// Create a glyph ID
pub fn GlyphId::new(id : Int32) -> GlyphId {
  { id, }
}

///|
/// Get the underlying ID value
pub fn GlyphId::to_int(self : GlyphId) -> Int32 {
  self.id
}

///|
/// Glyph position with advance and offset
struct GlyphPosition {
  glyph_id : GlyphId
  x_advance : Int32
  y_advance : Int32
  x_offset : Int32
  y_offset : Int32
} derive(Eq, Debug)

///|
pub extend GlyphPosition with Debug::{to_repr}

///|
pub extend GlyphPosition with Eq::{not_equal, equal}

///|
/// Create a glyph position
pub fn GlyphPosition::new(
  glyph_id~ : GlyphId,
  x_advance~ : Int32 = 0,
  y_advance~ : Int32 = 0,
  x_offset~ : Int32 = 0,
  y_offset~ : Int32 = 0,
) -> GlyphPosition {
  { glyph_id, x_advance, y_advance, x_offset, y_offset, }
}

///|
/// Get the glyph id for this position.
pub fn GlyphPosition::get_glyph_id(self : GlyphPosition) -> GlyphId {
  self.glyph_id
}

///|
/// Get horizontal advance in font units.
pub fn GlyphPosition::get_x_advance(self : GlyphPosition) -> Int32 {
  self.x_advance
}

///|
/// Get vertical advance in font units.
pub fn GlyphPosition::get_y_advance(self : GlyphPosition) -> Int32 {
  self.y_advance
}

///|
/// Get horizontal offset in font units.
pub fn GlyphPosition::get_x_offset(self : GlyphPosition) -> Int32 {
  self.x_offset
}

///|
/// Get vertical offset in font units.
pub fn GlyphPosition::get_y_offset(self : GlyphPosition) -> Int32 {
  self.y_offset
}

///|
/// Glyph info with cluster mapping
struct GlyphInfo {
  glyph_id : GlyphId
  cluster : Int32
} derive(Eq, Debug)

///|
pub extend GlyphInfo with Debug::{to_repr}

///|
pub extend GlyphInfo with Eq::{not_equal, equal}

///|
/// Create glyph info
pub fn GlyphInfo::new(glyph_id~ : GlyphId, cluster~ : Int32) -> GlyphInfo {
  { glyph_id, cluster, }
}

///|
/// Get the shaped glyph id.
pub fn GlyphInfo::get_glyph_id(self : GlyphInfo) -> GlyphId {
  self.glyph_id
}

///|
/// Get the source cluster index.
pub fn GlyphInfo::get_cluster(self : GlyphInfo) -> Int32 {
  self.cluster
}

///|
/// Result of text shaping operation
struct ShapedText {
  glyphs : Array[GlyphInfo]
  positions : Array[GlyphPosition]
  width : Int32
} derive(Debug)

///|
pub extend ShapedText with Debug::{to_repr}

///|
/// Get the total width of the shaped text
pub fn ShapedText::get_width(self : ShapedText) -> Int32 {
  self.width
}

///|
/// Get the glyph count
pub fn ShapedText::glyph_count(self : ShapedText) -> Int32 {
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
