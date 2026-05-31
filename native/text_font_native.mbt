///|
extern "C" fn native_font_default(size : Float) -> FontHandle = "moonbit_skia_font_default"

///|
extern "C" fn native_font_empty(size : Float) -> FontHandle = "moonbit_skia_font_empty"

///|
#borrow(typeface)
extern "C" fn native_font_from_typeface(
  typeface : TypefaceHandle,
  size : Float,
) -> FontHandle = "moonbit_skia_font_from_typeface"

///|
#borrow(font)
extern "C" fn native_font_is_null(font : FontHandle) -> Bool = "moonbit_skia_font_is_null"

///|
#borrow(font)
extern "C" fn native_font_size(font : FontHandle) -> Float = "moonbit_skia_font_size"

///|
#borrow(font)
extern "C" fn native_font_set_size(font : FontHandle, size : Float) -> Unit = "moonbit_skia_font_set_size"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_utf8(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_count_text_utf8(
  font : FontHandle,
  text : Bytes,
) -> Int = "moonbit_skia_font_count_text_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_text_to_glyphs_utf8(
  font : FontHandle,
  text : Bytes,
) -> Array[GlyphId] = "moonbit_skia_font_text_to_glyphs_utf8"

///|
#borrow(font)
extern "C" fn native_font_glyph_width(font : FontHandle, glyph : Int) -> Float = "moonbit_skia_font_glyph_width"

///|
#borrow(font, glyphs)
extern "C" fn native_font_glyph_widths(
  font : FontHandle,
  glyphs : Array[GlyphId],
) -> Array[Float] = "moonbit_skia_font_glyph_widths"

///|
#borrow(font, text)
extern "C" fn native_font_text_glyph_positions_utf8(
  font : FontHandle,
  text : Bytes,
  origin_x : Float,
  origin_y : Float,
) -> Array[@skia.Point] = "moonbit_skia_font_text_glyph_positions_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_text_glyph_x_positions_utf8(
  font : FontHandle,
  text : Bytes,
  origin : Float,
) -> Array[Float] = "moonbit_skia_font_text_glyph_x_positions_utf8"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_left(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_left"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_top(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_top"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_right(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_right"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_bottom(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_bottom"

///|
#borrow(font, glyphs)
extern "C" fn native_font_glyph_bounds_many(
  font : FontHandle,
  glyphs : Array[GlyphId],
) -> Array[@skia.Rect] = "moonbit_skia_font_glyph_bounds_many"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8(
  font : FontHandle,
  text : Bytes,
) -> Bool = "moonbit_skia_font_measure_text_bounds_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_left(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_left"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_top(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_top"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_right(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_right"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_bottom(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_bottom"

///|
#borrow(font)
extern "C" fn native_font_metrics_value(
  font : FontHandle,
  metric : Int,
) -> Float = "moonbit_skia_font_metrics_value"

///|
#borrow(font)
extern "C" fn native_font_metrics_has(font : FontHandle, metric : Int) -> Bool = "moonbit_skia_font_metrics_has"

///|
#borrow(font, text)
extern "C" fn native_font_shape_text_utf8(
  font : FontHandle,
  text : Bytes,
  width : Float,
  left_to_right : Bool,
) -> ShapedTextRunHandle = "moonbit_skia_font_shape_text_utf8"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_is_null(run : ShapedTextRunHandle) -> Bool = "moonbit_skia_shaped_text_run_is_null"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_glyph_count(
  run : ShapedTextRunHandle,
) -> Int = "moonbit_skia_shaped_text_run_glyph_count"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_advance_x(
  run : ShapedTextRunHandle,
) -> Float = "moonbit_skia_shaped_text_run_advance_x"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_advance_y(
  run : ShapedTextRunHandle,
) -> Float = "moonbit_skia_shaped_text_run_advance_y"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_glyphs(
  run : ShapedTextRunHandle,
) -> Array[GlyphId] = "moonbit_skia_shaped_text_run_glyphs"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_positions(
  run : ShapedTextRunHandle,
) -> Array[@skia.Point] = "moonbit_skia_shaped_text_run_positions"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_clusters(
  run : ShapedTextRunHandle,
) -> Array[Int] = "moonbit_skia_shaped_text_run_clusters"

///|
extern "C" fn native_typeface_default() -> TypefaceHandle = "moonbit_skia_typeface_default"

///|
extern "C" fn native_font_mgr_default() -> FontMgrHandle = "moonbit_skia_font_mgr_default"

///|
#borrow(font_mgr)
extern "C" fn native_font_mgr_is_null(font_mgr : FontMgrHandle) -> Bool = "moonbit_skia_font_mgr_is_null"

///|
#borrow(font_mgr)
extern "C" fn native_font_mgr_count_families(font_mgr : FontMgrHandle) -> Int = "moonbit_skia_font_mgr_count_families"

///|
#borrow(font_mgr)
extern "C" fn native_font_mgr_family_name(
  font_mgr : FontMgrHandle,
  index : Int,
) -> Bytes = "moonbit_skia_font_mgr_family_name"

///|
#borrow(font_mgr, family_name)
extern "C" fn native_font_mgr_match_family_style(
  font_mgr : FontMgrHandle,
  family_name : Bytes,
  weight : Int,
  width : Int,
  slant : Int,
) -> TypefaceHandle = "moonbit_skia_font_mgr_match_family_style"

///|
#borrow(font_mgr, family_name, bcp47)
extern "C" fn native_font_mgr_match_family_style_character(
  font_mgr : FontMgrHandle,
  family_name : Bytes,
  bcp47 : Array[Bytes],
  character : Int,
  weight : Int,
  width : Int,
  slant : Int,
) -> TypefaceHandle = "moonbit_skia_font_mgr_match_family_style_character"

///|
#borrow(family_name)
extern "C" fn native_typeface_from_name(
  family_name : Bytes,
  weight : Int,
  width : Int,
  slant : Int,
) -> TypefaceHandle = "moonbit_skia_typeface_from_name"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_null(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_null"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_bold(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_bold"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_italic(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_italic"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_fixed_pitch(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_fixed_pitch"

///|
fn Font::from_handle(handle : FontHandle) -> Font? {
  if native_font_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Font::default(size? : Float = 12.0) -> Font? {
  if size <= 0.0 {
    None
  } else {
    Font::from_handle(native_font_default(size))
  }
}

///|
pub fn Font::empty(size? : Float = 12.0) -> Font? {
  if size <= 0.0 {
    None
  } else {
    Font::from_handle(native_font_empty(size))
  }
}

///|
pub fn Font::from_typeface(typeface : Typeface, size? : Float = 12.0) -> Font? {
  if size <= 0.0 {
    None
  } else {
    Font::from_handle(native_font_from_typeface(typeface.handle, size))
  }
}

///|
pub fn Font::is_available(self : Font) -> Bool {
  !native_font_is_null(self.handle)
}

///|
pub fn Font::size(self : Font) -> Float {
  native_font_size(self.handle)
}

///|
pub fn Font::set_size(self : Font, size : Float) -> Unit {
  if size > 0.0 {
    native_font_set_size(self.handle, size)
  }
}

///|
pub fn Font::measure_text_utf8(self : Font, text : Bytes) -> Float {
  if text.is_empty() {
    0.0
  } else {
    native_font_measure_text_utf8(self.handle, text)
  }
}

///|
pub fn Font::count_text_utf8(self : Font, text : Bytes) -> Int {
  if text.is_empty() {
    0
  } else {
    native_font_count_text_utf8(self.handle, text)
  }
}

///|
pub fn Font::text_to_glyphs_utf8(self : Font, text : Bytes) -> Array[GlyphId] {
  if text.is_empty() {
    []
  } else {
    native_font_text_to_glyphs_utf8(self.handle, text)
  }
}

///|
pub fn Font::glyph_width(self : Font, glyph : GlyphId) -> Float {
  native_font_glyph_width(self.handle, glyph.to_int())
}

///|
pub fn Font::glyph_widths(self : Font, glyphs : Array[GlyphId]) -> Array[Float] {
  if glyphs.is_empty() {
    []
  } else {
    native_font_glyph_widths(self.handle, glyphs)
  }
}

///|
pub fn Font::glyph_x_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : Float = 0.0,
) -> Array[Float] {
  let positions : Array[Float] = Array::new(capacity=glyphs.length())
  for x = origin, i = 0; i < glyphs.length(); i = i + 1 {
    positions.push(x)
    continue x + self.glyph_width(glyphs[i]), i + 1
  }
  positions
}

///|
pub fn Font::glyph_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  let positions : Array[@skia.Point] = Array::new(capacity=glyphs.length())
  let x_positions = self.glyph_x_positions(glyphs, origin=origin.x)
  for x in x_positions {
    positions.push(@skia.Point::new(x, origin.y))
  }
  positions
}

///|
pub fn Font::text_glyph_x_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : Float = 0.0,
) -> Array[Float] {
  if text.is_empty() {
    []
  } else {
    native_font_text_glyph_x_positions_utf8(self.handle, text, origin)
  }
}

///|
pub fn Font::text_glyph_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  if text.is_empty() {
    []
  } else {
    native_font_text_glyph_positions_utf8(self.handle, text, origin.x, origin.y)
  }
}

///|
pub fn Font::glyph_bounds(self : Font, glyph : GlyphId) -> @skia.Rect {
  let glyph_int = glyph.to_int()
  @skia.Rect::new(
    native_font_glyph_bounds_left(self.handle, glyph_int),
    native_font_glyph_bounds_top(self.handle, glyph_int),
    native_font_glyph_bounds_right(self.handle, glyph_int),
    native_font_glyph_bounds_bottom(self.handle, glyph_int),
  )
}

///|
pub fn Font::glyph_bounds_many(
  self : Font,
  glyphs : Array[GlyphId],
) -> Array[@skia.Rect] {
  if glyphs.is_empty() {
    []
  } else {
    native_font_glyph_bounds_many(self.handle, glyphs)
  }
}

///|
pub fn Font::measure_text_bounds_utf8(self : Font, text : Bytes) -> @skia.Rect? {
  if text.is_empty() || !native_font_measure_text_bounds_utf8(self.handle, text) {
    None
  } else {
    Some(
      @skia.Rect::new(
        native_font_measure_text_bounds_utf8_left(self.handle, text),
        native_font_measure_text_bounds_utf8_top(self.handle, text),
        native_font_measure_text_bounds_utf8_right(self.handle, text),
        native_font_measure_text_bounds_utf8_bottom(self.handle, text),
      ),
    )
  }
}

///|
fn font_metric_optional(font : FontHandle, metric : Int) -> Float? {
  if native_font_metrics_has(font, metric) {
    Some(native_font_metrics_value(font, metric))
  } else {
    None
  }
}

///|
pub fn Font::metrics(self : Font) -> FontMetrics {
  let font = self.handle
  {
    top: native_font_metrics_value(font, 0),
    ascent: native_font_metrics_value(font, 1),
    descent: native_font_metrics_value(font, 2),
    bottom: native_font_metrics_value(font, 3),
    leading: native_font_metrics_value(font, 4),
    average_char_width: native_font_metrics_value(font, 5),
    max_char_width: native_font_metrics_value(font, 6),
    x_min: native_font_metrics_value(font, 7),
    x_max: native_font_metrics_value(font, 8),
    x_height: native_font_metrics_value(font, 9),
    cap_height: native_font_metrics_value(font, 10),
    underline_thickness: font_metric_optional(font, 11),
    underline_position: font_metric_optional(font, 12),
    strikeout_thickness: font_metric_optional(font, 13),
    strikeout_position: font_metric_optional(font, 14),
    has_bounds: native_font_metrics_has(font, 15),
  }
}

///|
fn ShapedTextRun::from_handle(handle : ShapedTextRunHandle) -> ShapedTextRun? {
  if native_shaped_text_run_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Font::shape_text_utf8(
  self : Font,
  text : Bytes,
  width? : Float = 1000000000.0,
  left_to_right? : Bool = true,
) -> ShapedTextRun? {
  if text.is_empty() || width <= 0.0 {
    None
  } else {
    ShapedTextRun::from_handle(
      native_font_shape_text_utf8(self.handle, text, width, left_to_right),
    )
  }
}

///|
pub fn ShapedTextRun::is_available(self : ShapedTextRun) -> Bool {
  !native_shaped_text_run_is_null(self.handle)
}

///|
pub fn ShapedTextRun::glyph_count(self : ShapedTextRun) -> Int {
  native_shaped_text_run_glyph_count(self.handle)
}

///|
pub fn ShapedTextRun::advance(self : ShapedTextRun) -> @skia.Point {
  @skia.Point::new(
    native_shaped_text_run_advance_x(self.handle),
    native_shaped_text_run_advance_y(self.handle),
  )
}

///|
pub fn ShapedTextRun::glyphs(self : ShapedTextRun) -> Array[GlyphId] {
  native_shaped_text_run_glyphs(self.handle)
}

///|
pub fn ShapedTextRun::positions(self : ShapedTextRun) -> Array[@skia.Point] {
  native_shaped_text_run_positions(self.handle)
}

///|
pub fn ShapedTextRun::clusters(self : ShapedTextRun) -> Array[Int] {
  native_shaped_text_run_clusters(self.handle)
}

///|
pub fn Font::spacing(self : Font) -> Float {
  let metrics = self.metrics()
  metrics.descent - metrics.ascent + metrics.leading
}

///|
fn Typeface::from_handle(handle : TypefaceHandle) -> Typeface? {
  if native_typeface_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Typeface::default() -> Typeface? {
  Typeface::from_handle(native_typeface_default())
}

///|
fn skia_font_style_weight(weight : Int) -> Int {
  weight.clamp(min=1, max=1000)
}

///|
fn skia_font_style_width(width : Int) -> Int {
  width.clamp(min=1, max=9)
}

///|
fn skia_font_style_slant(slant : Int) -> Int {
  slant.clamp(min=0, max=2)
}

///|
pub fn Typeface::from_name(
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  if family_name.is_empty() {
    None
  } else {
    Typeface::from_handle(
      native_typeface_from_name(
        family_name,
        skia_font_style_weight(weight),
        skia_font_style_width(width),
        skia_font_style_slant(slant),
      ),
    )
  }
}

///|
pub fn Typeface::from_name_style(
  family_name : Bytes,
  style : @skia.FontStyleRequest,
) -> Typeface? {
  Typeface::from_name(
    family_name,
    weight=style.weight,
    width=style.width,
    slant=style.slant,
  )
}

///|
fn FontMgr::from_handle(handle : FontMgrHandle) -> FontMgr? {
  if native_font_mgr_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn FontMgr::default() -> FontMgr? {
  FontMgr::from_handle(native_font_mgr_default())
}

///|
pub fn FontMgr::is_available(self : FontMgr) -> Bool {
  !native_font_mgr_is_null(self.handle)
}

///|
pub fn FontMgr::count_families(self : FontMgr) -> Int {
  native_font_mgr_count_families(self.handle)
}

///|
pub fn FontMgr::family_name(self : FontMgr, index : Int) -> Bytes? {
  if index < 0 || index >= self.count_families() {
    None
  } else {
    let name = native_font_mgr_family_name(self.handle, index)
    if name.is_empty() {
      None
    } else {
      Some(name)
    }
  }
}

///|
pub fn FontMgr::match_family_style(
  self : FontMgr,
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  if family_name.is_empty() {
    None
  } else {
    Typeface::from_handle(
      native_font_mgr_match_family_style(
        self.handle,
        family_name,
        skia_font_style_weight(weight),
        skia_font_style_width(width),
        skia_font_style_slant(slant),
      ),
    )
  }
}

///|
pub fn FontMgr::match_family_style_request(
  self : FontMgr,
  family_name : Bytes,
  style : @skia.FontStyleRequest,
) -> Typeface? {
  self.match_family_style(
    family_name,
    weight=style.weight,
    width=style.width,
    slant=style.slant,
  )
}

///|
pub fn FontMgr::match_family_style_character(
  self : FontMgr,
  family_name : Bytes,
  bcp47 : Array[Bytes],
  character : Int,
  style? : @skia.FontStyleRequest = @skia.FontStyleRequest::new(),
) -> Typeface? {
  if character <= 0 {
    None
  } else {
    Typeface::from_handle(
      native_font_mgr_match_family_style_character(
        self.handle,
        family_name,
        bcp47,
        character,
        style.weight,
        style.width,
        style.slant,
      ),
    )
  }
}

///|
pub fn FontMgr::match_fallback_request(
  self : FontMgr,
  request : @skia.FontFallbackRequest,
) -> Typeface? {
  let mut matched : Typeface? = None
  if request.has_character() {
    let family_count = request.families.length()
    if family_count == 0 {
      matched = self.match_family_style_character(
        b"",
        request.bcp47,
        request.character,
        style=request.style,
      )
    } else {
      for index in 0..<family_count {
        match matched {
          Some(_) => ()
          None =>
            match request.families.family_at(index) {
              None => ()
              Some(family) =>
                matched = self.match_family_style_character(
                  family,
                  request.bcp47,
                  request.character,
                  style=request.style,
                )
            }
        }
      }
      match matched {
        Some(_) => ()
        None =>
          matched = self.match_family_style_character(
            b"",
            request.bcp47,
            request.character,
            style=request.style,
          )
      }
    }
  } else {
    for index in 0..<request.families.length() {
      match matched {
        Some(_) => ()
        None =>
          match request.families.family_at(index) {
            None => ()
            Some(family) =>
              matched = self.match_family_style_request(family, request.style)
          }
      }
    }
  }
  matched
}

///|
pub fn Typeface::from_font_mgr_family(
  font_mgr : FontMgr,
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  font_mgr.match_family_style(family_name, weight~, width~, slant~)
}

///|
pub fn Typeface::from_font_mgr_request(
  font_mgr : FontMgr,
  request : @skia.FontFallbackRequest,
) -> Typeface? {
  font_mgr.match_fallback_request(request)
}

///|
pub fn Typeface::is_available(self : Typeface) -> Bool {
  !native_typeface_is_null(self.handle)
}

///|
pub fn Typeface::is_bold(self : Typeface) -> Bool {
  native_typeface_is_bold(self.handle)
}

///|
pub fn Typeface::is_italic(self : Typeface) -> Bool {
  native_typeface_is_italic(self.handle)
}

///|
pub fn Typeface::is_fixed_pitch(self : Typeface) -> Bool {
  native_typeface_is_fixed_pitch(self.handle)
}
