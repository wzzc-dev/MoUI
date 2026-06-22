///|
/// Font data (simplified representation)
struct FontData {
  data : Bytes
  font_index : Int
} derive(Debug)

///|
/// Create font data from bytes
pub fn FontData::new(data : Bytes, font_index? : Int = 0) -> FontData {
  { data, font_index }
}

///|
/// Get the raw font data
pub fn FontData::get_data(self : FontData) -> Bytes {
  self.data
}

///|
/// Get the face index inside a font collection.
pub fn FontData::get_font_index(self : FontData) -> Int {
  self.font_index
}

///|
/// Font metrics information
pub struct FontMetrics {
  units_per_em : Int
  ascent : Int
  descent : Int
  line_gap : Int
} derive(Eq, Debug)

///|
/// Create font metrics
pub fn FontMetrics::new(
  units_per_em~ : Int,
  ascent~ : Int,
  descent~ : Int,
  line_gap? : Int = 0,
) -> FontMetrics {
  { units_per_em, ascent, descent, line_gap }
}

///|
/// Get the line height (ascent - descent + line_gap)
pub fn FontMetrics::line_height(self : FontMetrics) -> Int {
  self.ascent - self.descent + self.line_gap
}
