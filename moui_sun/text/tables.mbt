///|
/// Font header (head table)
struct FontHead {
  units_per_em : Int
  index_to_loc_format : Int // 0 = short, 1 = long
} derive(Eq, Debug)

///|
/// Horizontal header (hhea table)
struct FontHhea {
  ascent : Int
  descent : Int
  line_gap : Int
  num_h_metrics : Int
} derive(Eq, Debug)

///|
/// Horizontal metrics
struct LongHorMetric {
  advance_width : Int
  lsb : Int // left side bearing
} derive(Eq, Debug)

///|
/// Simple glyph point
struct GlyphPoint {
  x : Int
  y : Int
  on_curve : Bool
} derive(Eq, Debug)

///|
/// Glyph contour
struct GlyphContour {
  points : Array[GlyphPoint]
} derive(Debug)

///|
/// Simple glyph data
struct SimpleGlyph {
  contours : Array[GlyphContour]
  xmin : Int
  ymin : Int
  xmax : Int
  ymax : Int
} derive(Debug)

///|
/// A component of a composite glyph
struct GlyphComponent {
  glyph_index : Int
  x_offset : Int
  y_offset : Int
  scale_x : Double
  scale_y : Double
  scale_xy : Double
  scale_yx : Double
} derive(Debug)

///|
/// Glyph data (simple or composite)
enum GlyphData {
  Simple(SimpleGlyph)
  Composite(Array[GlyphComponent])
  Empty
} derive(Debug)

///|
/// Table record in font file
struct TableRecord {
  tag : String
  checksum : UInt
  offset : UInt
  length : UInt
} derive(Eq, Debug)

///|
/// Kerning pair
struct KernPair {
  left : Int
  right : Int
  value : Int
} derive(Eq, Debug)

///|
/// Parsed font data
struct Font {
  head : FontHead
  hhea : FontHhea
  hmtx : Array[LongHorMetric]
  cmap : Map[Int, Int] // char code -> glyph index
  glyphs : Array[GlyphData]
  glyph_count : Int
  kern : Array[KernPair] // kerning pairs
} derive(Debug)

///|
/// Get font metrics
fn Font::get_metrics(self : Font) -> (Int, Int, Int) {
  (self.hhea.ascent, self.hhea.descent, self.hhea.line_gap)
}

///|
/// Get units per em
fn Font::get_units_per_em(self : Font) -> Int {
  self.head.units_per_em
}

///|
/// Map character to glyph index
fn Font::char_to_glyph(self : Font, char_code : Int) -> Int {
  match self.cmap.get(char_code) {
    Some(idx) => idx
    None => 0 // .notdef glyph
  }
}

///|
/// Return whether this font maps a Unicode codepoint to a drawable glyph.
fn Font::has_glyph_for_char(self : Font, char_code : Int) -> Bool {
  self.char_to_glyph(char_code) > 0
}

///|
/// Get glyph data, resolving composite glyphs
fn Font::get_glyph(self : Font, glyph_id : Int) -> GlyphData {
  guard glyph_id >= 0 && glyph_id < self.glyph_count else {
    return GlyphData::Empty
  }
  let data = self.glyphs[glyph_id]
  match data {
    GlyphData::Composite(components) =>
      resolve_composite_glyph(self, components)
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
      GlyphData::Simple(simple) =>
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
          all_contours.push({ points: transformed_points })
        }
      _ => () // Skip empty or unresolved composite glyphs
    }
  }

  guard all_contours.length() > 0 else { return GlyphData::Empty }

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

  GlyphData::Simple({ contours: all_contours, xmin, ymin, xmax, ymax })
}

///|
/// Get horizontal metrics for a glyph
fn Font::get_h_metrics(self : Font, glyph_id : Int) -> (Int, Int) {
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
fn Font::get_kerning(self : Font, left_glyph : Int, right_glyph : Int) -> Int {
  for pair in self.kern {
    if pair.left == left_glyph && pair.right == right_glyph {
      return pair.value
    }
  }
  0
}
