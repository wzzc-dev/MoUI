///|
/// Font header (head table)
#derive(Eq, Debug)
struct FontHead {
  units_per_em : Int32
  index_to_loc_format : Int32 // 0 = short, 1 = long
}

///|
pub extend FontHead with Debug::{to_repr}

///|
pub extend FontHead with Eq::{not_equal, equal}

///|
/// Horizontal header (hhea table)
#derive(Eq, Debug)
struct FontHhea {
  ascent : Int32
  descent : Int32
  line_gap : Int32
  num_h_metrics : Int32
}

///|
pub extend FontHhea with Debug::{to_repr}

///|
pub extend FontHhea with Eq::{not_equal, equal}

///|
/// Horizontal metrics
#derive(Eq, Debug)
struct LongHorMetric {
  advance_width : Int32
  lsb : Int32 // left side bearing
}

///|
pub extend LongHorMetric with Debug::{to_repr}

///|
pub extend LongHorMetric with Eq::{not_equal, equal}

///|
/// Simple glyph point
#derive(Eq, Debug)
struct GlyphPoint {
  x : Int32
  y : Int32
  on_curve : Bool
}

///|
pub extend GlyphPoint with Debug::{to_repr}

///|
pub extend GlyphPoint with Eq::{not_equal, equal}

///|
/// Glyph contour
#derive(Debug)
struct GlyphContour {
  points : Array[GlyphPoint]
}

///|
pub extend GlyphContour with Debug::{to_repr}

///|
/// Simple glyph data
#derive(Debug)
struct SimpleGlyph {
  contours : Array[GlyphContour]
  xmin : Int32
  ymin : Int32
  xmax : Int32
  ymax : Int32
}

///|
pub extend SimpleGlyph with Debug::{to_repr}

///|
/// A component of a composite glyph
#derive(Debug)
struct GlyphComponent {
  glyph_index : Int32
  x_offset : Int32
  y_offset : Int32
  scale_x : Double
  scale_y : Double
  scale_xy : Double
  scale_yx : Double
}

///|
pub extend GlyphComponent with Debug::{to_repr}

///|
/// Glyph data (simple or composite)
#derive(Debug)
enum GlyphData {
  Simple(SimpleGlyph)
  Composite(Array[GlyphComponent])
  Empty
}

///|
pub extend GlyphData with Debug::{to_repr}

///|
/// Table record in font file
#derive(Eq, Debug)
struct TableRecord {
  tag : String
  checksum : UInt32
  offset : UInt32
  length : UInt32
}

///|
pub extend TableRecord with Debug::{to_repr}

///|
pub extend TableRecord with Eq::{not_equal, equal}

///|
/// Kerning pair
#derive(Eq, Debug)
struct KernPair {
  left : Int32
  right : Int32
  value : Int32
}

///|
pub extend KernPair with Debug::{to_repr}

///|
pub extend KernPair with Eq::{not_equal, equal}

///|
/// Parsed font data.
///
/// Glyph outlines decode on demand (`glyph_memo`, `Font::get_glyph`): a CJK
/// face carries tens of thousands of glyphs and bulk-decoding them at parse
/// time cost hundreds of milliseconds per face, while a UI frame touches a
/// few dozen. Coverage (`cmap`) and metrics (`hmtx`/`loca`) still parse up
/// front, so fallback planning and layout see the whole face immediately.
#derive(Debug)
struct Font {
  head : FontHead
  hhea : FontHhea
  hmtx : Array[LongHorMetric]
  cmap : Map[Int32, Int32] // char code -> glyph index
  /// Pre-decoded outlines for hand-built fonts (tests). Parsed fonts leave
  /// this empty and decode outlines on demand through `glyph_memo`.
  glyphs : Array[GlyphData]
  data : Bytes
  glyf_offset : Int32
  loca : Array[Int32]
  glyph_memo : FixedArray[GlyphData?]
  glyph_count : Int32
  kern : Array[KernPair] // kerning pairs
}

///|
pub extend Font with Debug::{to_repr}

///|
/// Get font metrics
fn Font::get_metrics(self : Font) -> (Int32, Int32, Int32) {
  (self.hhea.ascent, self.hhea.descent, self.hhea.line_gap)
}

///|
/// Get units per em
fn Font::get_units_per_em(self : Font) -> Int32 {
  self.head.units_per_em
}

///|
/// Map character to glyph index
fn Font::char_to_glyph(self : Font, char_code : Int32) -> Int32 {
  match self.cmap.get(char_code) {
    Some(idx) => idx
    None => 0 // .notdef glyph
  }
}

///|
/// Return whether this font maps a Unicode codepoint to a drawable glyph.
fn Font::has_glyph_for_char(self : Font, char_code : Int32) -> Bool {
  self.char_to_glyph(char_code) > 0
}

///|
/// Get glyph data, resolving composite glyphs. Outlines decode on first
/// request and are memoized; a malformed outline degrades to `Empty` so one
/// bad glyph cannot take down the whole face.
fn Font::get_glyph(self : Font, glyph_id : Int32) -> GlyphData {
  guard glyph_id >= 0 && glyph_id < self.glyph_count else { return Empty }
  if self.glyphs.length() > 0 {
    return self.resolve_glyph(self.glyphs[glyph_id])
  }
  match self.glyph_memo[glyph_id] {
    Some(cached) => self.resolve_glyph(cached)
    None => {
      let decoded = match self.decode_glyph(glyph_id) {
        Ok(glyph) => glyph
        Err(_) => Empty
      }
      self.glyph_memo[glyph_id] = Some(decoded)
      self.resolve_glyph(decoded)
    }
  }
}

///|
/// Decode one glyph outline straight from the font bytes. Exposed for the
/// checked-parser tests: decode errors surface here instead of at parse time.
fn Font::decode_glyph(
  self : Font,
  glyph_id : Int32,
) -> Result[GlyphData, FontParseError] {
  let offset = self.loca[glyph_id]
  let next_offset = self.loca[glyph_id + 1]
  guard offset < next_offset else { return Ok(Empty) }
  parse_glyph_checked(
    self.data,
    self.glyf_offset + offset,
    next_offset - offset,
  )
}

///|
fn Font::resolve_glyph(self : Font, data : GlyphData) -> GlyphData {
  match data {
    Composite(components) => resolve_composite_glyph(self, components)
    _ => data
  }
}

///|
/// Resolve a composite glyph by combining component glyphs
fn resolve_composite_glyph(
  font : Font,
  components : Array[GlyphComponent],
) -> GlyphData {
  let all_contours = []

  for component in components {
    let glyph_data = font.get_glyph(component.glyph_index)
    match glyph_data {
      Simple(simple) =>
        // Transform and add contours
        for contour in simple.contours {
          let transformed_points = []
          for point in contour.points {
            let x = point.x.to_double() * component.scale_x +
              point.y.to_double() * component.scale_xy +
              component.x_offset.to_double()
            let y = point.x.to_double() * component.scale_yx +
              point.y.to_double() * component.scale_y +
              component.y_offset.to_double()
            transformed_points.push({
              x: x.to_int(),
              y: y.to_int(),
              on_curve: point.on_curve,
            })
          }
          all_contours.push({ points: transformed_points, })
        }
      _ => () // Skip empty or unresolved composite glyphs
    }
  }

  guard all_contours.length() > 0 else { return Empty }

  // Calculate bounding box from contours
  let mut xmin = all_contours[0].points[0].x
  let mut ymin = all_contours[0].points[0].y
  let mut xmax = xmin
  let mut ymax = ymin
  for contour in all_contours {
    for point in contour.points {
      if point.x < xmin {
        xmin = point.x
      }
      if point.y < ymin {
        ymin = point.y
      }
      if point.x > xmax {
        xmax = point.x
      }
      if point.y > ymax {
        ymax = point.y
      }
    }
  }

  Simple({ contours: all_contours, xmin, ymin, xmax, ymax, })
}

///|
/// Get horizontal metrics for a glyph
fn Font::get_h_metrics(self : Font, glyph_id : Int32) -> (Int32, Int32) {
  let idx = if glyph_id < self.hmtx.length() {
    glyph_id
  } else {
    self.hmtx.length() - 1
  }
  let m = self.hmtx[idx]
  (m.advance_width, m.lsb)
}

///|
/// Get kerning value between two glyphs
fn Font::get_kerning(
  self : Font,
  left_glyph : Int32,
  right_glyph : Int32,
) -> Int32 {
  for pair in self.kern {
    if pair.left == left_glyph && pair.right == right_glyph {
      return pair.value
    }
  }
  0
}
