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
extern "C" fn native_font_text_to_glyphs_utf8_value(
  font : FontHandle,
  text : Bytes,
  index : Int,
) -> Int = "moonbit_skia_font_text_to_glyphs_utf8_value"

///|
#borrow(font)
extern "C" fn native_font_glyph_width(font : FontHandle, glyph : Int) -> Float = "moonbit_skia_font_glyph_width"

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
extern "C" fn native_shaped_text_run_glyph_value(
  run : ShapedTextRunHandle,
  index : Int,
) -> Int = "moonbit_skia_shaped_text_run_glyph_value"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_position_x(
  run : ShapedTextRunHandle,
  index : Int,
) -> Float = "moonbit_skia_shaped_text_run_position_x"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_position_y(
  run : ShapedTextRunHandle,
  index : Int,
) -> Float = "moonbit_skia_shaped_text_run_position_y"

///|
#borrow(run)
extern "C" fn native_shaped_text_run_cluster_value(
  run : ShapedTextRunHandle,
  index : Int,
) -> Int = "moonbit_skia_shaped_text_run_cluster_value"

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
#borrow(font_mgr, family_name, language_tag)
extern "C" fn native_font_mgr_match_family_style_character(
  font_mgr : FontMgrHandle,
  family_name : Bytes,
  language_tag : Bytes,
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
#borrow(path)
extern "C" fn native_typeface_from_file(
  path : Bytes,
  index : Int,
) -> TypefaceHandle = "moonbit_skia_typeface_from_file"

///|
/// Creates a typeface from in-memory font data (e.g. an embedded TTF/OTF) via
/// the default font manager. The typeface is not registered anywhere; use
/// `register_data` when the family must also be visible to paragraph layout.
#borrow(data)
extern "C" fn native_typeface_from_data(
  data : Bytes,
  index : Int,
) -> TypefaceHandle = "moonbit_skia_typeface_from_data"

///|
/// Creates a typeface from in-memory font data and registers it under
/// `alias` (plus its own family name) in the C++ embedded-font registry so
/// that paragraph layout can resolve the family too.
#borrow(family_alias, data)
extern "C" fn native_typeface_register_data(
  family_alias : Bytes,
  data : Bytes,
  index : Int,
) -> TypefaceHandle = "moonbit_skia_typeface_register_data"

///|
/// Returns a cloned typeface with one variation axis applied. `axis` is the
/// 4-byte OpenType tag (e.g. b"wght"). The clone inherits the typeface's
/// existing variation coordinates, so calls compose.
#borrow(typeface, axis)
extern "C" fn native_typeface_clone_variation(
  typeface : TypefaceHandle,
  axis : Bytes,
  value : Float,
) -> TypefaceHandle = "moonbit_skia_typeface_clone_variation"

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
#borrow(typeface)
extern "C" fn native_typeface_family_name(typeface : TypefaceHandle) -> Bytes = "moonbit_skia_typeface_family_name"

///|
#borrow(typeface)
extern "C" fn native_typeface_has_color_glyphs(
  typeface : TypefaceHandle,
) -> Bool = "moonbit_skia_typeface_has_color_glyphs"

///|
fn Font::from_handle(handle : FontHandle) -> Font? {
  if native_font_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
fn native_font_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}

///|
fn native_font_positive_scalar_is_valid(value : Float) -> Bool {
  native_font_scalar_is_finite(value) && value > 0.0
}

///|
fn native_font_position_scalar(value : Float) -> Float {
  if native_font_scalar_is_finite(value) {
    value
  } else {
    0.0
  }
}

///|
fn native_font_position_origin(origin : @skia.Point) -> @skia.Point {
  @skia.Point::new(
    native_font_position_scalar(origin.x),
    native_font_position_scalar(origin.y),
  )
}

///|
pub fn Font::default(size? : Float = 12.0) -> Font? {
  if !native_font_positive_scalar_is_valid(size) {
    None
  } else {
    Font::from_handle(native_font_default(size))
  }
}

///|
pub fn Font::empty(size? : Float = 12.0) -> Font? {
  if !native_font_positive_scalar_is_valid(size) {
    None
  } else {
    Font::from_handle(native_font_empty(size))
  }
}

///|
pub fn Font::from_typeface(typeface : Typeface, size? : Float = 12.0) -> Font? {
  if !native_font_positive_scalar_is_valid(size) {
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
  if native_font_positive_scalar_is_valid(size) {
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
    let count = native_font_count_text_utf8(self.handle, text)
    let glyphs : Array[GlyphId] = Array::new(capacity=count)
    for i in 0..<count {
      let value = native_font_text_to_glyphs_utf8_value(self.handle, text, i)
      glyphs.push(GlyphId::new(value.clamp(min=0, max=65535).to_uint16()))
    }
    glyphs
  }
}

///|
pub fn Font::glyph_width(self : Font, glyph : GlyphId) -> Float {
  native_font_glyph_width(self.handle, glyph.to_int())
}

///|
pub fn Font::glyph_widths(self : Font, glyphs : Array[GlyphId]) -> Array[Float] {
  // Build the result in MoonBit rather than calling the C batch function
  // native_font_glyph_widths. The C function returns MoonbitSkiaFloatArray*
  // (a regular object with a buffer pointer), whose memory layout is
  // incompatible with MoonBit's Array[Float] (a val array with inline data
  // and length stored in the object header meta). Calling it directly causes
  // garbage lengths and data to be read, failing the native smoke test.
  let widths : Array[Float] = Array::new(capacity=glyphs.length())
  for glyph in glyphs {
    widths.push(self.glyph_width(glyph))
  }
  widths
}

///|
pub fn Font::glyph_x_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : Float = 0.0,
) -> Array[Float] {
  let positions : Array[Float] = Array::new(capacity=glyphs.length())
  let origin = native_font_position_scalar(origin)
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
  let origin = native_font_position_origin(origin)
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
  // Build the result in MoonBit rather than calling the C batch function
  // native_font_text_glyph_x_positions_utf8. The C function returns
  // MoonbitSkiaFloatArray* whose memory layout is incompatible with
  // MoonBit's Array[Float] (val array with inline data).
  if text.is_empty() {
    []
  } else {
    let glyphs = self.text_to_glyphs_utf8(text)
    self.glyph_x_positions(glyphs, origin~)
  }
}

///|
pub fn Font::text_glyph_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  // Build the result in MoonBit rather than calling the C batch function
  // native_font_text_glyph_positions_utf8. The C function returns
  // MoonbitSkiaPointArray* whose memory layout is incompatible with
  // MoonBit's Array[@skia.Point].
  if text.is_empty() {
    []
  } else {
    let glyphs = self.text_to_glyphs_utf8(text)
    self.glyph_positions(glyphs, origin~)
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
  // Build the result in MoonBit rather than calling the C batch function
  // native_font_glyph_bounds_many. The C function returns
  // MoonbitSkiaRectArray* whose memory layout is incompatible with
  // MoonBit's Array[@skia.Rect].
  let bounds : Array[@skia.Rect] = Array::new(capacity=glyphs.length())
  for glyph in glyphs {
    bounds.push(self.glyph_bounds(glyph))
  }
  bounds
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
  // Unconstrained wrap width for single-line runs. Keep finite and moderate so
  // native shapers never allocate pathological run buffers.
  width? : Float = 1000000.0,
  left_to_right? : Bool = true,
) -> ShapedTextRun? {
  if text.is_empty() || !native_font_positive_scalar_is_valid(width) {
    None
  } else {
    ShapedTextRun::from_handle(
      native_font_shape_text_utf8(self.handle, text, width, left_to_right),
    )
  }
}

///|
fn text_run_bytes_for_shaping(
  text : Bytes,
  run : @skia.TextRunDescriptor,
) -> Bytes {
  let text_length = text.length()
  let start = run.range.start.clamp(min=0, max=text_length)
  let end = run.range.end.clamp(min=start, max=text_length)
  if end <= start {
    b""
  } else {
    let bytes : Array[Byte] = Array::new(capacity=end - start)
    for index in start..<end {
      bytes.push(text[index])
    }
    Bytes::from_array(bytes)
  }
}

///|
pub fn Font::shape_text_run_utf8(
  self : Font,
  text : Bytes,
  shaping : @skia.TextShapingDescriptor,
) -> @skia.ShapedGlyphRunDescriptor? {
  let run_text = text_run_bytes_for_shaping(text, shaping.run)
  if run_text.is_empty() || shaping.run.is_empty() {
    None
  } else {
    match
      self.shape_text_utf8(
        run_text,
        width=shaping.width,
        left_to_right=shaping.run.direction.is_left_to_right(),
      ) {
      None => None
      Some(run) => {
        let glyphs = run.glyphs()
        let glyph_ids : Array[Int] = Array::new(capacity=glyphs.length())
        for glyph in glyphs {
          glyph_ids.push(glyph.to_int())
        }
        let positions = run.positions()
        let clusters = run.clusters()
        let glyph_count = run.glyph_count()
        if glyph_count <= 0 ||
          glyphs.length() != glyph_count ||
          positions.length() != glyph_count ||
          clusters.length() != glyph_count {
          return None
        }
        let shaped_run = shaping.shaped_run_descriptor(
          glyph_count~,
          cluster_count=clusters.length(),
          advance=run.advance(),
        )
        let descriptor = shaped_run.glyph_run_descriptor(
          glyph_ids~,
          positions~,
          clusters~,
        )
        if descriptor.is_valid() {
          Some(descriptor)
        } else {
          None
        }
      }
    }
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
  let count = self.glyph_count()
  let glyphs : Array[GlyphId] = Array::new(capacity=count)
  for index in 0..<count {
    glyphs.push(
      GlyphId::new(
        native_shaped_text_run_glyph_value(self.handle, index)
        .clamp(min=0, max=65535)
        .to_uint16(),
      ),
    )
  }
  glyphs
}

///|
pub fn ShapedTextRun::positions(self : ShapedTextRun) -> Array[@skia.Point] {
  let count = self.glyph_count()
  let positions : Array[@skia.Point] = Array::new(capacity=count)
  for index in 0..<count {
    positions.push(
      @skia.Point::new(
        native_shaped_text_run_position_x(self.handle, index),
        native_shaped_text_run_position_y(self.handle, index),
      ),
    )
  }
  positions
}

///|
pub fn ShapedTextRun::clusters(self : ShapedTextRun) -> Array[Int] {
  let count = self.glyph_count()
  let clusters : Array[Int] = Array::new(capacity=count)
  for index in 0..<count {
    clusters.push(
      Int::max(0, native_shaped_text_run_cluster_value(self.handle, index)),
    )
  }
  clusters
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
pub fn Typeface::from_file(path : Bytes, index? : Int = 0) -> Typeface? {
  if path.is_empty() || index < 0 {
    None
  } else {
    Typeface::from_handle(native_typeface_from_file(path, index))
  }
}

///|
/// Creates a typeface from in-memory font data (embedded TTF/OTF bytes).
/// `index` selects a face from a TTC collection. The resulting typeface is
/// usable for measurement and drawing but is not registered for family-name
/// resolution; use `register_data` when paragraph layout must resolve it too.
pub fn Typeface::from_data(data : Bytes, index? : Int = 0) -> Typeface? {
  if data.is_empty() || index < 0 {
    None
  } else {
    Typeface::from_handle(native_typeface_from_data(data, index))
  }
}

///|
/// Creates a typeface from in-memory font data and registers it under `alias`
/// (plus the font's own family name) in the embedded-font registry, so that
/// paragraph layout can resolve the family by name as well.
pub fn Typeface::register_data(
  family_alias : Bytes,
  data : Bytes,
  index? : Int = 0,
) -> Typeface? {
  if family_alias.is_empty() || data.is_empty() || index < 0 {
    None
  } else {
    Typeface::from_handle(native_typeface_register_data(family_alias, data, index))
  }
}

///|
/// Returns a typeface with the given variation axes applied. Each pair is the
/// 4-byte OpenType axis tag (e.g. `b"wght"`) and the desired value. The clone
/// composes with any variations already baked into the typeface. Returns
/// `None` if the typeface does not support variation cloning; an empty
/// `variations` list returns the original typeface unchanged.
pub fn Typeface::with_variations(
  self : Typeface,
  variations : Array[(Bytes, Float)],
) -> Typeface? {
  if variations.is_empty() {
    return Some(self)
  }
  let mut current = self
  for pair in variations {
    let (axis, value) = pair
    match Typeface::from_handle(native_typeface_clone_variation(current.handle, axis, value)) {
      Some(clone) => current = clone
      None => return None
    }
  }
  Some(current)
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
fn FontMgr::match_family_style_character_language(
  self : FontMgr,
  family_name : Bytes,
  language_tag : Bytes,
  character : Int,
  style : @skia.FontStyleRequest,
) -> Typeface? {
  if character <= 0 {
    None
  } else {
    Typeface::from_handle(
      native_font_mgr_match_family_style_character(
        self.handle,
        family_name,
        language_tag,
        character,
        style.weight,
        style.width,
        style.slant,
      ),
    )
  }
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
  } else if bcp47.is_empty() {
    self.match_family_style_character_language(
      family_name, b"", character, style,
    )
  } else {
    let mut matched : Typeface? = None
    for language_tag in bcp47 {
      match matched {
        Some(_) => ()
        None =>
          matched = self.match_family_style_character_language(
            family_name, language_tag, character, style,
          )
      }
    }
    matched
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
pub fn FontMgr::resolve_fallback_request(
  self : FontMgr,
  request : @skia.FontFallbackRequest,
) -> ResolvedTypeface? {
  if request.is_empty() {
    None
  } else {
    match self.match_fallback_request(request) {
      None => None
      Some(typeface) =>
        match typeface.family_name() {
          None => None
          Some(family_name) =>
            if family_name.is_empty() {
              None
            } else {
              let resolution = request.resolution_descriptor(family_name)
              if resolution.is_valid() {
                Some({ typeface, resolution })
              } else {
                None
              }
            }
        }
    }
  }
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

///|
pub fn Typeface::family_name(self : Typeface) -> Bytes? {
  let family_name = native_typeface_family_name(self.handle)
  if family_name.is_empty() {
    None
  } else {
    Some(family_name)
  }
}

///|
pub fn Typeface::has_color_glyphs(self : Typeface) -> Bool {
  native_typeface_has_color_glyphs(self.handle)
}
