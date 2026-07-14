///|
/// Parsed font face used by higher-level layout and rendering APIs.
struct FontFace {
  font : Font
} derive(Debug)

///|
/// Wrap an already parsed font as a face.
fn FontFace::from_font(font : Font) -> FontFace {
  { font, }
}

///|
/// Parse TTF bytes into a checked font face.
pub fn FontFace::from_bytes(data : Bytes) -> Result[FontFace, FontParseError] {
  match parse_font_result(data) {
    Ok(font) => Ok(FontFace::from_font(font))
    Err(error) => Err(error)
  }
}

///|
/// Parse a raw font-data container into a checked font face.
pub fn FontFace::from_data(data : FontData) -> Result[FontFace, FontParseError] {
  guard data.get_font_index() is 0 else {
    return Err(FontParseError::UnsupportedFontIndex(data.get_font_index()))
  }
  FontFace::from_bytes(data.get_data())
}

///|
/// Parse this raw font-data container into a checked font face.
pub fn FontData::parse(self : FontData) -> Result[FontFace, FontParseError] {
  FontFace::from_data(self)
}

///|
/// Small checked font-face cache for GUI/resource code that repeatedly asks for
/// the same parsed face.
struct FontFaceCache {
  mut faces : Map[String, FontFace]
  mut access_order : Array[String]
  capacity : Int
  is_bounded : Bool
} derive(Debug)

///|
/// Result of reading a checked font face from cache or parsing it on miss.
struct FontFaceCacheParseResult {
  face : FontFace
  did_parse : Bool
} derive(Debug)

///|
/// Create an empty font-face cache.
pub fn FontFaceCache::new() -> FontFaceCache {
  { faces: Map([]), access_order: [], capacity: 0, is_bounded: false }
}

///|
/// Create an empty font-face cache with least-recently-used eviction.
pub fn FontFaceCache::with_capacity(capacity : Int) -> FontFaceCache {
  { faces: Map([]), access_order: [], capacity: capacity.max(1), is_bounded: true }
}

///|
/// Get the resulting checked font face.
pub fn FontFaceCacheParseResult::get_face(
  self : FontFaceCacheParseResult,
) -> FontFace {
  self.face
}

///|
/// Return whether this lookup parsed bytes instead of hitting cache.
pub fn FontFaceCacheParseResult::did_parse(
  self : FontFaceCacheParseResult,
) -> Bool {
  self.did_parse
}

///|
/// Return whether this lookup reused a checked face from cache.
pub fn FontFaceCacheParseResult::did_hit_cache(
  self : FontFaceCacheParseResult,
) -> Bool {
  !self.did_parse
}

///|
/// Return the number of cached font faces.
pub fn FontFaceCache::len(self : FontFaceCache) -> Int {
  self.faces.length()
}

///|
/// Return whether the cache currently has no parsed faces.
pub fn FontFaceCache::is_empty(self : FontFaceCache) -> Bool {
  self.len() is 0
}

///|
/// Return the maximum number of cached font faces, or 0 for an unbounded cache.
pub fn FontFaceCache::capacity(self : FontFaceCache) -> Int {
  self.capacity
}

///|
/// Return whether the cache has a configured entry limit.
pub fn FontFaceCache::is_capacity_bounded(self : FontFaceCache) -> Bool {
  self.is_bounded
}

///|
/// Return whether the cache has a parsed face for this key without refreshing LRU.
pub fn FontFaceCache::contains(self : FontFaceCache, key : String) -> Bool {
  self.faces.contains(key)
}

///|
/// Look up a parsed face by caller-provided key.
pub fn FontFaceCache::get(self : FontFaceCache, key : String) -> FontFace? {
  match self.faces.get(key) {
    Some(face) => {
      self.touch_key(key)
      Some(face)
    }
    None => None
  }
}

///|
/// Insert or replace a parsed face under a caller-provided key.
pub fn FontFaceCache::insert(
  self : FontFaceCache,
  key : String,
  face : FontFace,
) -> FontFace {
  self.faces[key] = face
  self.touch_key(key)
  self.evict_over_capacity()
  face
}

///|
/// Parse bytes on first use and return the cached checked face afterwards.
pub fn FontFaceCache::get_or_parse(
  self : FontFaceCache,
  key : String,
  data : Bytes,
) -> Result[FontFace, FontParseError] {
  match self.get_or_parse_result(key, data) {
    Ok(result) => Ok(result.get_face())
    Err(error) => Err(error)
  }
}

///|
/// Parse bytes on first use and report whether cache missed.
pub fn FontFaceCache::get_or_parse_result(
  self : FontFaceCache,
  key : String,
  data : Bytes,
) -> Result[FontFaceCacheParseResult, FontParseError] {
  match self.get(key) {
    Some(face) => Ok({ face, did_parse: false })
    None =>
      match FontFace::from_bytes(data) {
        Ok(face) => Ok({ face: self.insert(key, face), did_parse: true })
        Err(error) => Err(error)
      }
  }
}

///|
/// Remove a cached face by key.
pub fn FontFaceCache::remove(self : FontFaceCache, key : String) -> Unit {
  self.faces.remove(key)
  self.remove_access_key(key)
}

///|
/// Drop all cached faces.
pub fn FontFaceCache::clear(self : FontFaceCache) -> Unit {
  self.faces = Map([])
  self.access_order = []
}

///|
fn FontFaceCache::touch_key(self : FontFaceCache, key : String) -> Unit {
  self.remove_access_key(key)
  self.access_order.push(key)
}

///|
fn FontFaceCache::remove_access_key(self : FontFaceCache, key : String) -> Unit {
  let mut index = 0
  while index < self.access_order.length() {
    if self.access_order[index] == key {
      ignore(self.access_order.remove(index))
    } else {
      index += 1
    }
  }
}

///|
fn FontFaceCache::evict_over_capacity(self : FontFaceCache) -> Unit {
  guard self.is_bounded && self.capacity > 0 else { return }
  while self.faces.length() > self.capacity && self.access_order.length() > 0 {
    let key = self.access_order.remove(0)
    self.faces.remove(key)
  }
}

///|
/// Get the parsed font backing this face.
fn FontFace::get_font(self : FontFace) -> Font {
  self.font
}

///|
/// Get face-wide metrics in font units.
pub fn FontFace::get_metrics(self : FontFace) -> FontMetrics {
  let (ascent, descent, line_gap) = self.font.get_metrics()
  FontMetrics::new(
    units_per_em=self.font.get_units_per_em(),
    ascent~,
    descent~,
    line_gap~,
  )
}

///|
/// Get units per em for the face.
pub fn FontFace::get_units_per_em(self : FontFace) -> Int {
  self.font.get_units_per_em()
}

///|
/// Map a Unicode codepoint to a glyph id.
pub fn FontFace::char_to_glyph(self : FontFace, char_code : Int) -> Int {
  self.font.char_to_glyph(char_code)
}

///|
/// Return whether this face maps a Unicode codepoint to a drawable glyph.
pub fn FontFace::has_glyph_for_char(self : FontFace, char_code : Int) -> Bool {
  self.font.has_glyph_for_char(char_code)
}

///|
/// Get resolved glyph data for a glyph id.
fn FontFace::get_glyph(self : FontFace, glyph_id : Int) -> GlyphData {
  self.font.get_glyph(glyph_id)
}
