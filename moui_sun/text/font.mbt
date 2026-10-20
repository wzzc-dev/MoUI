///|
/// Font data (simplified representation)
struct FontData {
  data : Bytes
  font_index : Int32
} derive(Debug)

///|
pub extend FontData with Debug::{to_repr}

///|
/// Create font data from bytes
pub fn FontData::new(data : Bytes, font_index~ : Int32 = 0) -> FontData {
  { data, font_index, }
}

///|
/// Get the raw font data
pub fn FontData::get_data(self : FontData) -> Bytes {
  self.data
}

///|
/// Get the face index inside a font collection.
pub fn FontData::get_font_index(self : FontData) -> Int32 {
  self.font_index
}

///|
/// Font metrics information
pub struct FontMetrics {
  units_per_em : Int32
  ascent : Int32
  descent : Int32
  line_gap : Int32
} derive(Eq, Debug)

///|
pub extend FontMetrics with Debug::{to_repr}

///|
pub extend FontMetrics with Eq::{not_equal, equal}

///|
/// Create font metrics
pub fn FontMetrics::new(
  units_per_em~ : Int32,
  ascent~ : Int32,
  descent~ : Int32,
  line_gap~ : Int32 = 0,
) -> FontMetrics {
  { units_per_em, ascent, descent, line_gap, }
}

///|
/// Get the line height (ascent - descent + line_gap)
pub fn FontMetrics::line_height(self : FontMetrics) -> Int32 {
  self.ascent - self.descent + self.line_gap
}
