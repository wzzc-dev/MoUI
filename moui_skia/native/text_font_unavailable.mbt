///|
pub fn Font::default(size? : Float = 12.0) -> Font? {
  ignore(size)
  None
}

///|
pub fn Font::empty(size? : Float = 12.0) -> Font? {
  ignore(size)
  None
}

///|
pub fn Font::from_typeface(typeface : Typeface, size? : Float = 12.0) -> Font? {
  ignore(typeface)
  ignore(size)
  None
}

///|
pub fn Font::is_available(self : Font) -> Bool {
  ignore(self)
  false
}

///|
pub fn Font::size(self : Font) -> Float {
  ignore(self)
  0.0
}

///|
pub fn Font::set_size(self : Font, size : Float) -> Unit {
  ignore(self)
  ignore(size)
}

///|
pub fn Font::measure_text_utf8(self : Font, text : Bytes) -> Float {
  ignore(self)
  ignore(text)
  0.0
}

///|
pub fn Font::count_text_utf8(self : Font, text : Bytes) -> Int {
  ignore(self)
  ignore(text)
  0
}

///|
pub fn Font::text_to_glyphs_utf8(self : Font, text : Bytes) -> Array[GlyphId] {
  ignore(self)
  ignore(text)
  []
}

///|
pub fn Font::glyph_width(self : Font, glyph : GlyphId) -> Float {
  ignore(self)
  ignore(glyph)
  0.0
}

///|
pub fn Font::glyph_widths(self : Font, glyphs : Array[GlyphId]) -> Array[Float] {
  ignore(self)
  ignore(glyphs)
  []
}

///|
pub fn Font::glyph_x_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : Float = 0.0,
) -> Array[Float] {
  ignore(self)
  ignore(glyphs)
  ignore(origin)
  []
}

///|
pub fn Font::glyph_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  ignore(self)
  ignore(glyphs)
  ignore(origin)
  []
}

///|
pub fn Font::text_glyph_x_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : Float = 0.0,
) -> Array[Float] {
  ignore(self)
  ignore(text)
  ignore(origin)
  []
}

///|
pub fn Font::text_glyph_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  ignore(self)
  ignore(text)
  ignore(origin)
  []
}

///|
pub fn Font::glyph_bounds(self : Font, glyph : GlyphId) -> @skia.Rect {
  ignore(self)
  ignore(glyph)
  @skia.Rect::empty()
}

///|
pub fn Font::glyph_bounds_many(
  self : Font,
  glyphs : Array[GlyphId],
) -> Array[@skia.Rect] {
  ignore(self)
  ignore(glyphs)
  []
}

///|
pub fn Font::measure_text_bounds_utf8(self : Font, text : Bytes) -> @skia.Rect? {
  ignore(self)
  ignore(text)
  None
}

///|
pub fn Font::metrics(self : Font) -> FontMetrics {
  ignore(self)
  {
    top: 0.0,
    ascent: 0.0,
    descent: 0.0,
    bottom: 0.0,
    leading: 0.0,
    average_char_width: 0.0,
    max_char_width: 0.0,
    x_min: 0.0,
    x_max: 0.0,
    x_height: 0.0,
    cap_height: 0.0,
    underline_thickness: None,
    underline_position: None,
    strikeout_thickness: None,
    strikeout_position: None,
    has_bounds: false,
  }
}

///|
pub fn Font::shape_text_utf8(
  self : Font,
  text : Bytes,
  width? : Float = 1000000000.0,
  left_to_right? : Bool = true,
) -> ShapedTextRun? {
  ignore(self)
  ignore(text)
  ignore(width)
  ignore(left_to_right)
  None
}

///|
pub fn Font::shape_text_run_utf8(
  self : Font,
  text : Bytes,
  shaping : @skia.TextShapingDescriptor,
) -> @skia.ShapedGlyphRunDescriptor? {
  ignore(self)
  ignore(text)
  ignore(shaping)
  None
}

///|
pub fn ShapedTextRun::is_available(self : ShapedTextRun) -> Bool {
  ignore(self)
  false
}

///|
pub fn ShapedTextRun::glyph_count(self : ShapedTextRun) -> Int {
  ignore(self)
  0
}

///|
pub fn ShapedTextRun::advance(self : ShapedTextRun) -> @skia.Point {
  ignore(self)
  @skia.Point::zero()
}

///|
pub fn ShapedTextRun::glyphs(self : ShapedTextRun) -> Array[GlyphId] {
  ignore(self)
  []
}

///|
pub fn ShapedTextRun::positions(self : ShapedTextRun) -> Array[@skia.Point] {
  ignore(self)
  []
}

///|
pub fn ShapedTextRun::clusters(self : ShapedTextRun) -> Array[Int] {
  ignore(self)
  []
}

///|
pub fn Font::spacing(self : Font) -> Float {
  ignore(self)
  0.0
}

///|
pub fn Typeface::default() -> Typeface? {
  None
}

///|
pub fn Typeface::from_name(
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  ignore(family_name)
  ignore(weight)
  ignore(width)
  ignore(slant)
  None
}

///|
pub fn Typeface::from_name_style(
  family_name : Bytes,
  style : @skia.FontStyleRequest,
) -> Typeface? {
  ignore(family_name)
  ignore(style)
  None
}

///|
pub fn Typeface::from_file(path : Bytes, index? : Int = 0) -> Typeface? {
  ignore(path)
  ignore(index)
  None
}

///|
pub fn Typeface::from_data(data : Bytes, index? : Int = 0) -> Typeface? {
  ignore(data)
  ignore(index)
  None
}

///|
pub fn Typeface::register_data(
  family_alias : Bytes,
  data : Bytes,
  index? : Int = 0,
) -> Typeface? {
  ignore(family_alias)
  ignore(data)
  ignore(index)
  None
}

///|
pub fn Typeface::with_variations(
  self : Typeface,
  variations : Array[(Bytes, Float)],
) -> Typeface? {
  if variations.is_empty() {
    Some(self)
  } else {
    ignore(variations)
    None
  }
}

///|
pub fn FontMgr::default() -> FontMgr? {
  None
}

///|
pub fn FontMgr::is_available(self : FontMgr) -> Bool {
  ignore(self)
  false
}

///|
pub fn FontMgr::count_families(self : FontMgr) -> Int {
  ignore(self)
  0
}

///|
pub fn FontMgr::family_name(self : FontMgr, index : Int) -> Bytes? {
  ignore(self)
  ignore(index)
  None
}

///|
pub fn FontMgr::match_family_style(
  self : FontMgr,
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  ignore(self)
  ignore(family_name)
  ignore(weight)
  ignore(width)
  ignore(slant)
  None
}

///|
pub fn FontMgr::match_family_style_request(
  self : FontMgr,
  family_name : Bytes,
  style : @skia.FontStyleRequest,
) -> Typeface? {
  ignore(self)
  ignore(family_name)
  ignore(style)
  None
}

///|
pub fn FontMgr::match_family_style_character(
  self : FontMgr,
  family_name : Bytes,
  bcp47 : Array[Bytes],
  character : Int,
  style? : @skia.FontStyleRequest = @skia.FontStyleRequest::new(),
) -> Typeface? {
  ignore(self)
  ignore(family_name)
  ignore(bcp47)
  ignore(character)
  ignore(style)
  None
}

///|
pub fn FontMgr::match_fallback_request(
  self : FontMgr,
  request : @skia.FontFallbackRequest,
) -> Typeface? {
  ignore(self)
  ignore(request)
  None
}

///|
pub fn FontMgr::resolve_fallback_request(
  self : FontMgr,
  request : @skia.FontFallbackRequest,
) -> ResolvedTypeface? {
  ignore(self)
  ignore(request)
  None
}

///|
pub fn Typeface::from_font_mgr_family(
  font_mgr : FontMgr,
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  ignore(font_mgr)
  ignore(family_name)
  ignore(weight)
  ignore(width)
  ignore(slant)
  None
}

///|
pub fn Typeface::from_font_mgr_request(
  font_mgr : FontMgr,
  request : @skia.FontFallbackRequest,
) -> Typeface? {
  ignore(font_mgr)
  ignore(request)
  None
}

///|
pub fn Typeface::is_available(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::is_bold(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::is_italic(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::is_fixed_pitch(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::family_name(self : Typeface) -> Bytes? {
  ignore(self)
  None
}

///|
pub fn Typeface::has_color_glyphs(self : Typeface) -> Bool {
  ignore(self)
  false
}
