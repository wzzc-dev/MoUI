///|
let atlas_width : Int = 1024

///|
let atlas_height : Int = 1024

///|
let atlas_padding : Int = 1

///|
priv struct NativeFontCache {
  text_engine : NativeTextEngine
}

///|
// Opaque native text engine selected by platform hosts. Platform packages
// construct one with `native_platform_text_engine`; optional fallback behavior
// is explicit so renderer/wgpu stays independent from concrete text engines.
pub struct NativeTextEngine {
  priv provider : NativePlatformTextProvider
  priv fallback : NativePlatformTextProvider?
}

///|
pub(all) enum NativeTextEngineSetting {
  MoonCosmic
  PlatformDefault
} derive(Eq, Debug, ToJson)

///|
// Callback bundle implemented by a platform text engine such as CoreText,
// DirectWrite, or fontconfig/HarfBuzz/FreeType.
pub struct NativePlatformTextProvider {
  priv id : String
  priv measure : (@core.TextLayoutInput) -> NativeTextLayout?
  priv layout_run : (@core.TextRun, Double) -> NativeTextLayout?
  priv raster_glyph : (String, Bytes) -> NativeRasterGlyph?
  priv register_font_data : (@core.FontFamily, Bytes) -> Unit
}

///|
priv struct GlyphAtlasEntry {
  x : Int
  y : Int
  width : Int
  height : Int
  bearing_x : Int
  bearing_y : Int
  format : NativeRasterGlyphFormat
}

///|
// Renderer-private glyph key. Platform providers own the payload encoding;
// `cache_key` must be stable across frames and include all raster-affecting
// fields such as glyph identity, size, style, and scale.
pub struct NativeGlyphKey {
  priv cache_key : String
  priv payload : Bytes
}

///|
pub(all) enum NativeRasterGlyphFormat {
  AlphaMask
  ColorRgba
} derive(Eq, Debug, ToJson)

///|
// Positioned glyph produced by platform text layout. Coordinates are logical
// pixels relative to the text run before frame alignment is applied.
pub(all) struct NativeGlyphPlacement {
  key : NativeGlyphKey
  x : Double
  y : Double
}

///|
// Text layout returned by platform providers. Measurement must provide a
// monotonic caret array covering the input text; render layout may omit carets
// but must provide valid metrics and glyph placements.
pub(all) struct NativeTextLayout {
  size : @core.Size
  baseline : Double
  caret_positions : Array[Double]
  glyphs : Array[NativeGlyphPlacement]
}

///|
// Glyph bitmap returned by a native text provider. Alpha glyphs are tinted by
// the text run color; color glyphs carry RGBA pixel payloads and preserve
// native emoji/color-font raster output while still applying run opacity.
pub(all) struct NativeRasterGlyph {
  width : Int
  height : Int
  bearing_x : Int
  bearing_y : Int
  format : NativeRasterGlyphFormat
  pixels : Bytes
}

///|
priv enum GlyphLookup {
  GlyphReady(GlyphAtlasEntry)
  GlyphMissing
  GlyphAtlasFull
}

///|
priv struct GlyphAtlas {
  width : Int
  height : Int
  padding : Int
  mut next_x : Int
  mut next_y : Int
  mut shelf_height : Int
  mut entries : Map[String, GlyphAtlasEntry]
  mut pixels : Array[Byte]
  mut dirty : Bool
}

///|
priv struct TextVertex {
  x : Double
  y : Double
  u : Double
  v : Double
  r : Double
  g : Double
  b : Double
  a : Double
  color_glyph : Double
}

///|
let text_vertex_stride : UInt64 = 36UL

///|
priv struct TextRunBuildResult {
  vertices : Array[TextVertex]
  atlas_full : Bool
}

///|
priv enum TextRunAppendResult {
  TextRunAppendComplete(Bool)
  TextRunAppendNeedsFallback
}

///|
fn NativeFontCache::new() -> NativeFontCache {
  NativeFontCache::new_with_engine(native_noop_text_engine())
}

///|
fn NativeFontCache::new_with_engine(
  text_engine : NativeTextEngine,
) -> NativeFontCache {
  { text_engine, }
}

///|
fn NativeTextEngine::id(self : NativeTextEngine) -> String {
  self.provider.id
}

///|
pub fn NativeTextEngine::provider_id(self : NativeTextEngine) -> String {
  self.provider.id
}

///|
pub fn NativeTextEngine::fallback_provider_id(
  self : NativeTextEngine,
) -> String {
  match self.fallback {
    Some(provider) => provider.id
    None => ""
  }
}

///|
pub fn NativePlatformTextProvider::new(
  id~ : String,
  measure~ : (@core.TextLayoutInput) -> NativeTextLayout?,
  layout_run~ : (@core.TextRun, Double) -> NativeTextLayout?,
  raster_glyph~ : (String, Bytes) -> NativeRasterGlyph?,
  register_font_data? : (@core.FontFamily, Bytes) -> Unit = (_family, _data) => {
    ()
  },
) -> NativePlatformTextProvider {
  { id, measure, layout_run, raster_glyph, register_font_data }
}

///|
pub fn native_platform_text_engine(
  provider : NativePlatformTextProvider,
) -> NativeTextEngine {
  { provider, fallback: None }
}

///|
pub fn native_platform_text_engine_with_fallback(
  provider : NativePlatformTextProvider,
  fallback~ : NativeTextEngine,
) -> NativeTextEngine {
  { provider, fallback: Some(fallback.provider) }
}

///|
fn native_noop_text_engine() -> NativeTextEngine {
  native_platform_text_engine(
    NativePlatformTextProvider::new(
      id="native-wgpu-noop-text",
      measure=_input => None,
      layout_run=(_run, _scale_factor) => None,
      raster_glyph=(_cache_key, _payload) => None,
    ),
  )
}

///|
// Create a platform glyph key. The renderer treats payload as opaque data and
// passes it back to the provider's raster callback.
pub fn native_platform_glyph_key(
  cache_key~ : String,
  payload~ : Bytes,
) -> NativeGlyphKey {
  { cache_key, payload }
}

///|
// Create a positioned platform glyph in logical run coordinates.
pub fn NativeGlyphPlacement::new(
  key~ : NativeGlyphKey,
  x~ : Double,
  y? : Double = 0.0,
) -> NativeGlyphPlacement {
  { key, x, y }
}

///|
// Create a provider layout value. Invalid metrics or non-monotonic carets are
// filtered by the renderer and trigger fallback.
pub fn NativeTextLayout::new(
  size~ : @core.Size,
  baseline~ : Double,
  caret_positions? : Array[Double] = [],
  glyphs? : Array[NativeGlyphPlacement] = [],
) -> NativeTextLayout {
  { size, baseline, caret_positions, glyphs }
}

///|
// Create a provider raster glyph. The renderer validates dimensions against the
// pixel buffer before uploading it to the atlas.
pub fn NativeRasterGlyph::new(
  width~ : Int,
  height~ : Int,
  bearing_x~ : Int,
  bearing_y~ : Int,
  format? : NativeRasterGlyphFormat = NativeRasterGlyphFormat::AlphaMask,
  pixels~ : Bytes,
) -> NativeRasterGlyph {
  { width, height, bearing_x, bearing_y, format, pixels }
}

///|
fn GlyphAtlas::new(width~ : Int, height~ : Int) -> GlyphAtlas {
  {
    width,
    height,
    padding: atlas_padding,
    next_x: 0,
    next_y: 0,
    shelf_height: 0,
    entries: {},
    pixels: Array::make(width * height * 4, b'\x00'),
    dirty: true,
  }
}

///|
fn GlyphAtlas::clear(self : GlyphAtlas) -> Unit {
  self.next_x = 0
  self.next_y = 0
  self.shelf_height = 0
  self.entries = {}
  self.pixels = Array::make(self.width * self.height * 4, b'\x00')
  self.dirty = true
}

///|
fn GlyphAtlas::to_bytes(self : GlyphAtlas) -> Bytes {
  Bytes::from_array(self.pixels)
}

///|
fn NativeTextEngine::measure(
  self : NativeTextEngine,
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let _ = cache
  match (self.provider.measure)(input) {
    Some(layout) =>
      if layout.is_valid_for_measure(input.text) {
        layout.to_text_layout_result()
      } else {
        self.measure_with_fallback(input)
      }
    None => self.measure_with_fallback(input)
  }
}

///|
fn NativeTextEngine::measure_with_fallback(
  self : NativeTextEngine,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  match self.fallback {
    Some(fallback) =>
      match (fallback.measure)(input) {
        Some(layout) =>
          if layout.is_valid_for_measure(input.text) {
            layout.to_text_layout_result()
          } else {
            @core.TextSystem::fallback().measure_text(input)
          }
        None => @core.TextSystem::fallback().measure_text(input)
      }
    None => @core.TextSystem::fallback().measure_text(input)
  }
}

///|
fn NativeTextEngine::layout_run(
  self : NativeTextEngine,
  cache : NativeFontCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  let _ = cache
  match (self.provider.layout_run)(run, scale_factor) {
    Some(layout) =>
      if layout.is_valid_for_run(run.text) {
        Some(layout)
      } else {
        self.layout_with_fallback(run, scale_factor)
      }
    None => self.layout_with_fallback(run, scale_factor)
  }
}

///|
fn NativeTextEngine::layout_with_fallback(
  self : NativeTextEngine,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  self.fallback_layout_run(run, scale_factor)
}

///|
fn NativeTextEngine::fallback_layout_run(
  self : NativeTextEngine,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  match self.fallback {
    Some(fallback) =>
      match (fallback.layout_run)(run, scale_factor) {
        Some(layout) =>
          if layout.is_valid_for_run(run.text) {
            Some(layout)
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
fn NativeTextEngine::raster_glyph(
  self : NativeTextEngine,
  cache : NativeFontCache,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  let _ = cache
  match (self.provider.raster_glyph)(key.cache_key, key.payload) {
    Some(glyph) if glyph.is_valid() => Some(glyph)
    _ => self.fallback_raster_glyph(key)
  }
}

///|
fn NativeTextEngine::fallback_raster_glyph(
  self : NativeTextEngine,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  match self.fallback {
    Some(fallback) =>
      match (fallback.raster_glyph)(key.cache_key, key.payload) {
        Some(glyph) => if glyph.is_valid() { Some(glyph) } else { None }
        None => None
      }
    None => None
  }
}

///|
fn NativeTextEngine::register_font_data(
  self : NativeTextEngine,
  cache : NativeFontCache,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  let _ = cache
  (self.provider.register_font_data)(family, data)
  match self.fallback {
    Some(fallback) => (fallback.register_font_data)(family, data)
    None => ()
  }
}

///|
fn NativeRasterGlyph::is_valid(self : NativeRasterGlyph) -> Bool {
  if self.width <= 0 || self.height <= 0 {
    return false
  }
  match self.format {
    NativeRasterGlyphFormat::AlphaMask =>
      self.width <= self.pixels.length() / self.height
    NativeRasterGlyphFormat::ColorRgba =>
      self.width <= self.pixels.length() / self.height / 4
  }
}

///|
fn NativeTextLayout::is_valid_for_measure(
  self : NativeTextLayout,
  text : String,
) -> Bool {
  self.has_valid_metrics() &&
  self.caret_positions.length() >= text.to_array().length() + 1 &&
  self.has_monotonic_carets()
}

///|
fn NativeTextLayout::is_valid_for_run(
  self : NativeTextLayout,
  text : String,
) -> Bool {
  self.has_valid_metrics() &&
  (
    self.caret_positions.is_empty() ||
    (
      self.caret_positions.length() >= text.to_array().length() + 1 &&
      self.has_monotonic_carets()
    )
  )
}

///|
fn NativeTextLayout::has_valid_metrics(self : NativeTextLayout) -> Bool {
  self.size.width >= 0.0 &&
  self.size.height > 0.0 &&
  self.baseline >= 0.0 &&
  self.baseline <= self.size.height
}

///|
fn NativeTextLayout::has_monotonic_carets(self : NativeTextLayout) -> Bool {
  if self.caret_positions.is_empty() {
    return false
  }
  let mut last = self.caret_positions[0]
  if last < 0.0 {
    return false
  }
  for index in 1..<self.caret_positions.length() {
    let caret = self.caret_positions[index]
    if caret < last {
      return false
    }
    last = caret
  }
  true
}

///|
fn NativeTextLayout::to_text_layout_result(
  self : NativeTextLayout,
) -> @core.TextLayoutResult {
  {
    size: self.size,
    baseline: self.baseline,
    caret_positions: self.caret_positions,
  }
}

///|
fn text_align_extra(
  align : @core.TextAlign,
  frame_width : Double,
  text_width : Double,
) -> Double {
  let extra = (frame_width - text_width).max(0.0)
  match align {
    @core.TextAlign::TextStart => 0.0
    @core.TextAlign::TextCenter => extra / 2.0
    @core.TextAlign::TextEnd => extra
  }
}

///|
pub fn native_text_system() -> @core.TextSystem {
  native_text_system_with_cache(NativeFontCache::new())
}

///|
pub fn native_text_system_with_engine(
  text_engine : NativeTextEngine,
) -> @core.TextSystem {
  native_text_system_with_cache(NativeFontCache::new_with_engine(text_engine))
}

///|
fn native_text_system_with_cache(cache : NativeFontCache) -> @core.TextSystem {
  @core.TextSystem::new(
    id=cache.text_engine.id(),
    measure=input => native_measure_text_layout(cache, input),
    register_font_data=(family, data) => {
      cache.text_engine.register_font_data(cache, family, data)
    },
  )
}

///|
fn native_measure_text_layout(
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  cache.text_engine.measure(cache, input)
}

///|
fn native_text_vertical_extra(
  frame : @core.Rect,
  layout : NativeTextLayout,
) -> Double {
  let extra = frame.size.height - layout.size.height
  if extra > 0.0 {
    extra / 2.0
  } else {
    0.0
  }
}

///|
fn build_native_text_run(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  run : @core.TextRun,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> TextRunBuildResult {
  let vertices : Array[TextVertex] = []
  let atlas_full = append_text_run_vertices(
    cache, atlas, run, state, size, scale_factor, vertices,
  )
  { vertices, atlas_full }
}

///|
fn append_text_run_vertices(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  run : @core.TextRun,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
  vertices : Array[TextVertex],
) -> Bool {
  match cache.text_engine.layout_run(cache, run, scale_factor) {
    Some(layout) =>
      append_text_layout_or_fallback(
        cache, atlas, run, state, size, scale_factor, layout, vertices,
      )
    None => false
  }
}

///|
fn append_text_layout_or_fallback(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  run : @core.TextRun,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
  layout : NativeTextLayout,
  vertices : Array[TextVertex],
) -> Bool {
  let attempt_vertices : Array[TextVertex] = []
  match
    append_text_layout_vertices(
      cache, atlas, run, state, size, scale_factor, layout, attempt_vertices,
    ) {
    TextRunAppendComplete(atlas_full) => {
      append_text_vertices(vertices, attempt_vertices)
      atlas_full
    }
    TextRunAppendNeedsFallback =>
      match cache.text_engine.fallback_layout_run(run, scale_factor) {
        None => false
        Some(fallback_layout) => {
          let fallback_vertices : Array[TextVertex] = []
          match
            append_text_layout_vertices(
              cache, atlas, run, state, size, scale_factor, fallback_layout, fallback_vertices,
            ) {
            TextRunAppendComplete(atlas_full) => {
              append_text_vertices(vertices, fallback_vertices)
              atlas_full
            }
            TextRunAppendNeedsFallback => false
          }
        }
      }
  }
}

///|
fn append_text_layout_vertices(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  run : @core.TextRun,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
  layout : NativeTextLayout,
  vertices : Array[TextVertex],
) -> TextRunAppendResult {
  let start_extra = text_align_extra(
    run.align,
    run.frame.size.width,
    layout.size.width,
  )
  let vertical_extra = native_text_vertical_extra(run.frame, layout)
  let scale = native_text_scale(scale_factor)
  let mut appended_count = 0
  for glyph in layout.glyphs {
    match atlas.ensure_glyph(cache, glyph.key) {
      GlyphReady(entry) =>
        if entry.width > 0 && entry.height > 0 {
          appended_count = appended_count + 1
          append_text_quad(
            vertices,
            run.frame.origin.x +
            start_extra +
            glyph.x +
            entry.bearing_x.to_double() / scale,
            run.frame.origin.y +
            vertical_extra +
            layout.baseline +
            glyph.y +
            entry.bearing_y.to_double() / scale,
            entry,
            atlas,
            state,
            size,
            scale,
            run.color.multiply_alpha(state.opacity),
          )
        }
      GlyphMissing => return TextRunAppendNeedsFallback
      GlyphAtlasFull => return TextRunAppendComplete(true)
    }
  }
  if appended_count == 0 && !run.text.is_empty() {
    return TextRunAppendNeedsFallback
  }
  TextRunAppendComplete(false)
}

///|
fn append_text_vertices(
  vertices : Array[TextVertex],
  appended : Array[TextVertex],
) -> Unit {
  for vertex in appended {
    vertices.push(vertex)
  }
}

///|
fn native_text_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn GlyphAtlas::ensure_glyph(
  self : GlyphAtlas,
  cache : NativeFontCache,
  key : NativeGlyphKey,
) -> GlyphLookup {
  match self.entries.get(key.cache_key) {
    Some(entry) => GlyphReady(entry)
    None =>
      match cache.text_engine.raster_glyph(cache, key) {
        None => GlyphMissing
        Some(raster) =>
          match self.place_glyph(raster.width, raster.height) {
            None => GlyphAtlasFull
            Some((x, y)) => {
              self.blit_glyph(x, y, raster)
              let entry = {
                x,
                y,
                width: raster.width,
                height: raster.height,
                bearing_x: raster.bearing_x,
                bearing_y: raster.bearing_y,
                format: raster.format,
              }
              self.entries[key.cache_key] = entry
              self.dirty = true
              GlyphReady(entry)
            }
          }
      }
  }
}

///|
fn GlyphAtlas::place_glyph(
  self : GlyphAtlas,
  width : Int,
  height : Int,
) -> (Int, Int)? {
  if width == 0 || height == 0 {
    return Some((0, 0))
  }
  let padded_width = width + self.padding * 2
  let padded_height = height + self.padding * 2
  if padded_width > self.width || padded_height > self.height {
    return None
  }
  if self.next_x + padded_width > self.width {
    self.next_x = 0
    self.next_y = self.next_y + self.shelf_height
    self.shelf_height = 0
  }
  if self.next_y + padded_height > self.height {
    return None
  }
  let x = self.next_x + self.padding
  let y = self.next_y + self.padding
  self.next_x = self.next_x + padded_width
  self.shelf_height = self.shelf_height.max(padded_height)
  Some((x, y))
}

///|
fn GlyphAtlas::blit_glyph(
  self : GlyphAtlas,
  dst_x : Int,
  dst_y : Int,
  raster : NativeRasterGlyph,
) -> Unit {
  match raster.format {
    NativeRasterGlyphFormat::AlphaMask =>
      for y in 0..<raster.height {
        for x in 0..<raster.width {
          let alpha = raster.pixels[y * raster.width + x]
          if alpha != b'\x00' {
            let dst = ((dst_y + y) * self.width + dst_x + x) * 4
            self.pixels[dst] = b'\xff'
            self.pixels[dst + 1] = b'\xff'
            self.pixels[dst + 2] = b'\xff'
            self.pixels[dst + 3] = alpha
          }
        }
      }
    NativeRasterGlyphFormat::ColorRgba =>
      for y in 0..<raster.height {
        for x in 0..<raster.width {
          let src = (y * raster.width + x) * 4
          let alpha = raster.pixels[src + 3]
          if alpha != b'\x00' {
            let dst = ((dst_y + y) * self.width + dst_x + x) * 4
            self.pixels[dst] = raster.pixels[src]
            self.pixels[dst + 1] = raster.pixels[src + 1]
            self.pixels[dst + 2] = raster.pixels[src + 2]
            self.pixels[dst + 3] = alpha
          }
        }
      }
  }
}

///|
fn append_text_quad(
  vertices : Array[TextVertex],
  x : Double,
  y : Double,
  entry : GlyphAtlasEntry,
  atlas : GlyphAtlas,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
  color : @core.Color,
) -> Unit {
  let width = entry.width.to_double() / native_text_scale(scale_factor)
  let height = entry.height.to_double() / native_text_scale(scale_factor)
  let p0 = transform_point(state.transform, x, y)
  let p1 = transform_point(state.transform, x, y + height)
  let p2 = transform_point(state.transform, x + width, y + height)
  let p3 = transform_point(state.transform, x + width, y)
  let u0 = entry.x.to_double() / atlas.width.to_double()
  let v0 = entry.y.to_double() / atlas.height.to_double()
  let u1 = (entry.x + entry.width).to_double() / atlas.width.to_double()
  let v1 = (entry.y + entry.height).to_double() / atlas.height.to_double()
  let color_glyph = match entry.format {
    NativeRasterGlyphFormat::AlphaMask => 0.0
    NativeRasterGlyphFormat::ColorRgba => 1.0
  }
  push_text_vertex(vertices, p0, size, u0, v0, color, color_glyph)
  push_text_vertex(vertices, p1, size, u0, v1, color, color_glyph)
  push_text_vertex(vertices, p2, size, u1, v1, color, color_glyph)
  push_text_vertex(vertices, p0, size, u0, v0, color, color_glyph)
  push_text_vertex(vertices, p2, size, u1, v1, color, color_glyph)
  push_text_vertex(vertices, p3, size, u1, v0, color, color_glyph)
}

///|
fn push_text_vertex(
  vertices : Array[TextVertex],
  point : @core.Point,
  size : @core.Size,
  u : Double,
  v : Double,
  color : @core.Color,
  color_glyph : Double,
) -> Unit {
  vertices.push({
    x: pixel_x_to_ndc(point.x, size.width),
    y: pixel_y_to_ndc(point.y, size.height),
    u,
    v,
    r: color.r,
    g: color.g,
    b: color.b,
    a: color.a,
    color_glyph,
  })
}

///|
fn pixel_x_to_ndc(x : Double, width : Double) -> Double {
  if width <= 0.0 {
    -1.0
  } else {
    x / width * 2.0 - 1.0
  }
}

///|
fn pixel_y_to_ndc(y : Double, height : Double) -> Double {
  if height <= 0.0 {
    1.0
  } else {
    1.0 - y / height * 2.0
  }
}

///|
fn text_vertices_to_bytes(vertices : Array[TextVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_text_f32le(out, vertex.x)
    push_text_f32le(out, vertex.y)
    push_text_f32le(out, vertex.u)
    push_text_f32le(out, vertex.v)
    push_text_f32le(out, vertex.r)
    push_text_f32le(out, vertex.g)
    push_text_f32le(out, vertex.b)
    push_text_f32le(out, vertex.a)
    push_text_f32le(out, vertex.color_glyph)
  }
  Bytes::from_array(out)
}

///|
fn push_text_f32le(out : Array[Byte], value : Double) -> Unit {
  let bits : UInt = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
fn text_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) color: vec4<f32>,
    #|  @location(2) color_glyph: f32,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) uv: vec2<f32>,
    #|  @location(2) color: vec4<f32>,
    #|  @location(3) color_glyph: f32,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.uv = uv;
    #|  out.color = color;
    #|  out.color_glyph = color_glyph;
    #|  return out;
    #|}
    #|
    #|@group(0) @binding(0) var glyph_sampler : sampler;
    #|@group(0) @binding(1) var glyph_atlas : texture_2d<f32>;
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let sample = textureSample(glyph_atlas, glyph_sampler, in.uv);
    #|  let rgb = select(in.color.rgb, sample.rgb, in.color_glyph > 0.5);
    #|  return vec4<f32>(rgb, in.color.a * sample.a);
    #|}
    #|
  shader
}
