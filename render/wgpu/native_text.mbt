///|
let atlas_width : Int = 1024

///|
let atlas_height : Int = 1024

///|
let atlas_padding : Int = 1

///|
priv struct NativeFontCache {
  mut font_system : @moon_cosmic.FontSystem
  swash_cache : @moon_cosmic.SwashCache
  catalog : NativeFontCatalog
  text_engine : NativeTextEngine
  loaded_paths : Map[String, Bool]
  warned_paths : Map[String, Bool]
}

///|
// Opaque native text engine selected by platform hosts. Platform packages should
// construct one with `native_platform_text_engine`; invalid provider output is
// rejected here and falls back to the shared Cosmic path.
pub struct NativeTextEngine {
  priv kind : NativeTextEngineKind
  priv fallback : Bool
}

///|
pub(all) enum NativeTextEngineSetting {
  MoonCosmic
  PlatformDefault
} derive(Eq, Debug, ToJson)

///|
priv enum NativeTextEngineKind {
  PlatformText(NativePlatformTextProvider)
  CosmicFallback
}

///|
// Callback bundle implemented by a platform text engine such as CoreText,
// DirectWrite, or fontconfig/HarfBuzz/FreeType.
pub struct NativePlatformTextProvider {
  priv id : String
  priv measure : (@core.TextLayoutInput) -> NativeTextLayout?
  priv layout_run : (@core.TextRun, Double) -> NativeTextLayout?
  priv raster_glyph : (Bytes) -> NativeRasterGlyph?
  priv register_font_data : (@core.FontFamily, Bytes) -> Unit
}

///|
priv struct NativeFontCatalog {
  regular_path : String
  bold_path : String
  cjk_path : String
}

///|
priv struct GlyphAtlasEntry {
  x : Int
  y : Int
  width : Int
  height : Int
  bearing_x : Int
  bearing_y : Int
}

///|
priv enum NativeGlyphSource {
  CosmicGlyph(@moon_cosmic.CacheKey)
  PlatformGlyph(Bytes)
}

///|
// Renderer-private glyph key. Platform providers own the payload encoding;
// `cache_key` must be stable across frames and include all raster-affecting
// fields such as glyph identity, size, style, and scale.
pub struct NativeGlyphKey {
  priv cache_key : String
  priv source : NativeGlyphSource
}

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
// Single-channel alpha glyph bitmap. `bearing_x` and `bearing_y` are logical
// pixel offsets from the glyph origin to the top-left bitmap corner.
pub(all) struct NativeRasterGlyph {
  width : Int
  height : Int
  bearing_x : Int
  bearing_y : Int
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
}

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
  NativeFontCache::new_with_engine(NativeTextEngine::cosmic_fallback())
}

///|
fn NativeFontCache::new_with_engine(
  text_engine : NativeTextEngine,
) -> NativeFontCache {
  {
    font_system: @moon_cosmic.FontSystem::new().set_fallback_profile(
      @moon_cosmic.FallbackProfile::MacOS,
    ),
    swash_cache: @moon_cosmic.SwashCache::new(),
    catalog: NativeFontCatalog::platform_default(),
    text_engine,
    loaded_paths: {},
    warned_paths: {},
  }
}

///|
fn NativeTextEngine::cosmic_fallback() -> NativeTextEngine {
  { kind: NativeTextEngineKind::CosmicFallback, fallback: false }
}

///|
pub fn native_cosmic_text_engine() -> NativeTextEngine {
  NativeTextEngine::cosmic_fallback()
}

///|
fn NativeTextEngine::id(self : NativeTextEngine) -> String {
  match self.kind {
    PlatformText(provider) => provider.id
    CosmicFallback => "native-wgpu-cosmic-fallback"
  }
}

///|
pub fn NativePlatformTextProvider::new(
  id~ : String,
  measure~ : (@core.TextLayoutInput) -> NativeTextLayout?,
  layout_run~ : (@core.TextRun, Double) -> NativeTextLayout?,
  raster_glyph~ : (Bytes) -> NativeRasterGlyph?,
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
  { kind: NativeTextEngineKind::PlatformText(provider), fallback: true }
}

///|
// Create a platform glyph key. The renderer treats payload as opaque data and
// passes it back to the provider's raster callback.
pub fn native_platform_glyph_key(
  cache_key~ : String,
  payload~ : Bytes,
) -> NativeGlyphKey {
  { cache_key, source: PlatformGlyph(payload) }
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
  pixels~ : Bytes,
) -> NativeRasterGlyph {
  { width, height, bearing_x, bearing_y, pixels }
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
fn windows_regular_font_path() -> String {
  "C:\\Windows\\Fonts\\segoeui.ttf"
}

///|
fn windows_bold_font_path() -> String {
  "C:\\Windows\\Fonts\\segoeuib.ttf"
}

///|
fn macos_regular_font_path() -> String {
  first_existing_font_path([
    "/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
  ])
}

///|
fn macos_bold_font_path() -> String {
  first_existing_font_path([
    "/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
  ])
}

///|
fn windows_cjk_font_path() -> String {
  first_existing_font_path([
    "C:\\Windows\\Fonts\\msyh.ttc", "C:\\Windows\\Fonts\\simsun.ttc", "C:\\Windows\\Fonts\\simhei.ttf",
  ])
}

///|
fn macos_cjk_font_path() -> String {
  first_existing_font_path(["/System/Library/Fonts/Hiragino Sans GB.ttc"])
}

///|
fn native_regular_font_path() -> String {
  first_existing_font_path([
    windows_regular_font_path(),
    macos_regular_font_path(),
  ])
}

///|
fn native_bold_font_path() -> String {
  first_existing_font_path([windows_bold_font_path(), macos_bold_font_path()])
}

///|
fn native_cjk_font_path() -> String {
  first_existing_font_path([windows_cjk_font_path(), macos_cjk_font_path()])
}

///|
fn NativeFontCatalog::platform_default() -> NativeFontCatalog {
  {
    regular_path: native_regular_font_path(),
    bold_path: native_bold_font_path(),
    cjk_path: native_cjk_font_path(),
  }
}

///|
fn NativeFontCatalog::font_path_for_spec(
  self : NativeFontCatalog,
  font : @core.FontSpec,
) -> String {
  if font.weight >= 600 {
    self.bold_path
  } else {
    self.regular_path
  }
}

///|
fn NativeFontCatalog::fallback_font_paths_for_spec(
  self : NativeFontCatalog,
  font : @core.FontSpec,
) -> Array[String] {
  [self.font_path_for_spec(font), self.cjk_path]
}

///|
fn first_existing_font_path(paths : Array[String]) -> String {
  for path in paths {
    if @fs.path_exists(path) {
      return path
    }
  }
  paths[0]
}

///|
pub fn native_text_font_path_for_spec(font : @core.FontSpec) -> String {
  NativeFontCatalog::platform_default().font_path_for_spec(font)
}

///|
pub fn native_text_fallback_font_paths_for_spec(
  font : @core.FontSpec,
) -> Array[String] {
  NativeFontCatalog::platform_default().fallback_font_paths_for_spec(font)
}

///|
fn NativeFontCache::ensure_fonts_for_font(
  self : NativeFontCache,
  font : @core.FontSpec,
) -> Unit {
  for path in self.catalog.fallback_font_paths_for_spec(font) {
    self.load_font_path(path)
  }
}

///|
fn NativeFontCache::load_font_path(
  self : NativeFontCache,
  path : String,
) -> Unit {
  match self.loaded_paths.get(path) {
    Some(true) => ()
    _ => {
      if !@fs.path_exists(path) {
        self.warn_font_once(path)
      } else {
        try {
          let bytes = @fs.read_file_to_bytes(path)
          let before = self.font_system.fonts().length()
          self.font_system = self.font_system.load_font_data(bytes)
          let after = self.font_system.fonts().length()
          if after == before {
            self.warn_font_once(path)
          }
        } catch {
          _ => self.warn_font_once(path)
        }
      }
      self.loaded_paths[path] = true
    }
  }
}

///|
fn NativeFontCache::load_font_data(
  self : NativeFontCache,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  let key = "registered:" + family.css_name()
  let before = self.font_system.fonts().length()
  self.font_system = self.font_system.load_font_data(data)
  let after = self.font_system.fonts().length()
  if after == before {
    self.warn_font_once(key)
  } else {
    self.loaded_paths[key] = true
  }
}

///|
fn NativeFontCache::has_loaded_fonts(self : NativeFontCache) -> Bool {
  self.font_system.fonts().length() > 0
}

///|
fn NativeFontCache::warn_font_once(
  self : NativeFontCache,
  path : String,
) -> Unit {
  match self.warned_paths.get(path) {
    Some(true) => ()
    _ => {
      println("MoUI native text: unable to load font: \{path}")
      self.warned_paths[path] = true
    }
  }
}

///|
fn NativeTextEngine::measure(
  self : NativeTextEngine,
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  match self.kind {
    PlatformText(provider) =>
      match (provider.measure)(input) {
        Some(layout) =>
          if layout.is_valid_for_measure(input.text) {
            layout.to_text_layout_result()
          } else {
            self.measure_with_fallback(cache, input)
          }
        None => self.measure_with_fallback(cache, input)
      }
    CosmicFallback => cache.cosmic_measure(input)
  }
}

///|
fn NativeTextEngine::measure_with_fallback(
  self : NativeTextEngine,
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let _ = self
  cache.cosmic_measure(input)
}

///|
fn NativeTextEngine::layout_run(
  self : NativeTextEngine,
  cache : NativeFontCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  match self.kind {
    PlatformText(provider) =>
      match (provider.layout_run)(run, scale_factor) {
        Some(layout) =>
          if layout.is_valid_for_run() {
            Some(layout)
          } else {
            self.layout_with_fallback(cache, run, scale_factor)
          }
        None => self.layout_with_fallback(cache, run, scale_factor)
      }
    CosmicFallback => cache.cosmic_layout_for_run(run, scale_factor)
  }
}

///|
fn NativeTextEngine::layout_with_fallback(
  self : NativeTextEngine,
  cache : NativeFontCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  self.fallback_layout_run(cache, run, scale_factor)
}

///|
fn NativeTextEngine::fallback_layout_run(
  self : NativeTextEngine,
  cache : NativeFontCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  if self.fallback {
    cache.cosmic_layout_for_run(run, scale_factor)
  } else {
    None
  }
}

///|
fn NativeTextEngine::raster_glyph(
  self : NativeTextEngine,
  cache : NativeFontCache,
  key : NativeGlyphKey,
) -> NativeRasterGlyph? {
  let raster = match key.source {
    PlatformGlyph(payload) =>
      match self.kind {
        PlatformText(provider) => (provider.raster_glyph)(payload)
        CosmicFallback => None
      }
    CosmicGlyph(cosmic_key) => raster_glyph(cache, cosmic_key)
  }
  match raster {
    Some(glyph) => if glyph.is_valid() { Some(glyph) } else { None }
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
  match self.kind {
    PlatformText(provider) => {
      (provider.register_font_data)(family, data)
      cache.load_font_data(family, data)
    }
    CosmicFallback => cache.load_font_data(family, data)
  }
}

///|
fn NativeRasterGlyph::is_valid(self : NativeRasterGlyph) -> Bool {
  if self.width <= 0 || self.height <= 0 {
    return false
  }
  self.width <= self.pixels.length() / self.height
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
fn NativeTextLayout::is_valid_for_run(self : NativeTextLayout) -> Bool {
  self.has_valid_metrics() &&
  (self.caret_positions.is_empty() || self.has_monotonic_carets())
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
fn cosmic_glyph_cache_key(key : @moon_cosmic.CacheKey) -> String {
  "cosmic:" + key.to_string()
}

///|
fn cosmic_native_glyph_key(key : @moon_cosmic.CacheKey) -> NativeGlyphKey {
  { cache_key: cosmic_glyph_cache_key(key), source: CosmicGlyph(key) }
}

///|
fn native_text_attrs_for_font(font : @core.FontSpec) -> @moon_cosmic.Attrs {
  @moon_cosmic.Attrs::new()
  .family(native_text_family_for_font(font))
  .style(native_text_style_for_font(font.style))
  .weight(@moon_cosmic.Weight::new(font.weight))
}

///|
fn native_text_style_for_font(style : @core.FontStyle) -> @moon_swash.Style {
  match style {
    @core.FontStyle::Normal => @moon_swash.Style::Normal
    @core.FontStyle::Italic => @moon_swash.Style::Italic
  }
}

///|
fn native_text_family_for_font(font : @core.FontSpec) -> @moon_cosmic.Family {
  let family = if font.families.families.is_empty() {
    @core.FontFamily::SystemUi
  } else {
    font.families.families[0]
  }
  match family {
    @core.FontFamily::Name(name) => @moon_cosmic.Family::Name(name)
    @core.FontFamily::SystemUi => @moon_cosmic.Family::SystemUi
    @core.FontFamily::UiSansSerif => @moon_cosmic.Family::UiSansSerif
    @core.FontFamily::UiSerif => @moon_cosmic.Family::UiSerif
    @core.FontFamily::UiMonospace => @moon_cosmic.Family::UiMonospace
    @core.FontFamily::SansSerif => @moon_cosmic.Family::SansSerif
    @core.FontFamily::Serif => @moon_cosmic.Family::Serif
    @core.FontFamily::Monospace => @moon_cosmic.Family::Monospace
    @core.FontFamily::Emoji => @moon_cosmic.Family::Emoji
    @core.FontFamily::Math => @moon_cosmic.Family::Math
    @core.FontFamily::FangSong => @moon_cosmic.Family::FangSong
  }
}

///|
fn build_native_text_buffer(
  cache : NativeFontCache,
  run : @core.TextRun,
) -> @moon_cosmic.Buffer {
  cache.ensure_fonts_for_font(run.font)
  let metrics = @moon_cosmic.Metrics::new(
    Float::from_double(run.font.size),
    Float::from_double(run.font.size * 1.25),
  )
  let attrs = native_text_attrs_for_font(run.font)
  let text = native_text_cosmic_safe_text(run.text)
  @moon_cosmic.Buffer::new(metrics)
  .set_wrap(@moon_cosmic.Wrap::None)
  .set_size(Some(Float::from_double(run.frame.size.width)), None)
  .set_text(
    text,
    @moon_cosmic.AttrsList::new(attrs),
    @moon_cosmic.Shaping::Advanced,
  )
  .shape_all_with_font_system(cache.font_system)
  .layout_all_with_font_system(cache.font_system)
}

///|
fn build_native_text_input_buffer(
  cache : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @moon_cosmic.Buffer {
  cache.ensure_fonts_for_font(input.font)
  let metrics = @moon_cosmic.Metrics::new(
    Float::from_double(input.font.size),
    Float::from_double(input.font.size * 1.25),
  )
  let attrs = native_text_attrs_for_font(input.font)
  let text = native_text_cosmic_safe_text(input.text)
  let max_width = match input.max_width {
    Some(width) => Some(Float::from_double(width))
    None => None
  }
  @moon_cosmic.Buffer::new(metrics)
  .set_wrap(@moon_cosmic.Wrap::None)
  .set_size(max_width, None)
  .set_text(
    text,
    @moon_cosmic.AttrsList::new(attrs),
    @moon_cosmic.Shaping::Advanced,
  )
  .shape_all_with_font_system(cache.font_system)
  .layout_all_with_font_system(cache.font_system)
}

///|
pub fn native_text_measurer() -> @core.TextMeasurer {
  native_text_measurer_with_cache(NativeFontCache::new())
}

///|
pub fn native_text_measurer_with_engine(
  text_engine : NativeTextEngine,
) -> @core.TextMeasurer {
  native_text_measurer_with_cache(NativeFontCache::new_with_engine(text_engine))
}

///|
fn native_text_measurer_with_cache(
  cache : NativeFontCache,
) -> @core.TextMeasurer {
  @core.TextMeasurer::new(
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
fn NativeFontCache::cosmic_measure(
  self : NativeFontCache,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let buffer = build_native_text_input_buffer(self, input)
  if !self.has_loaded_fonts() {
    return @core.measure_text_layout(input)
  }
  let raw = native_text_layout_result_from_cosmic(input, buffer)
  match input.max_width {
    Some(max_width) => native_clamp_text_layout_result(raw, max_width)
    None => raw
  }
}

///|
fn native_text_layout_result_from_cosmic(
  input : @core.TextLayoutInput,
  buffer : @moon_cosmic.Buffer,
) -> @core.TextLayoutResult {
  let char_count = input.text.to_array().length()
  let carets = Array::make(char_count + 1, 0.0)
  let mut width = 0.0
  let mut height = input.font.size * 1.25
  let mut saw_run = false
  for run in buffer.layout_runs() {
    saw_run = true
    width = width.max(run.line_w.to_double())
    height = height.max((run.line_top + run.line_height).to_double())
    for glyph in run.glyphs {
      let start = native_clamp_int(glyph.start, 0, char_count)
      let end = native_clamp_int(glyph.end, start, char_count)
      let left = glyph.x.to_double()
      let right = (glyph.x + glyph.w).to_double()
      if start < carets.length() {
        carets[start] = carets[start].max(left)
      }
      if end < carets.length() {
        carets[end] = carets[end].max(right)
      }
    }
  }
  if !saw_run || (char_count > 0 && carets[char_count] == 0.0) {
    return @core.measure_text_layout(input)
  }
  native_fill_missing_caret_positions(carets)
  {
    size: @core.Size::new(width~, height~),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn native_fill_missing_caret_positions(carets : Array[Double]) -> Unit {
  let mut last = 0.0
  for index in 0..<carets.length() {
    if carets[index] < last {
      carets[index] = last
    } else {
      last = carets[index]
    }
  }
}

///|
fn native_clamp_text_layout_result(
  result : @core.TextLayoutResult,
  max_width : Double,
) -> @core.TextLayoutResult {
  let carets : Array[Double] = []
  for caret in result.caret_positions {
    carets.push(caret.min(max_width))
  }
  {
    size: @core.Size::new(
      width=result.size.width.min(max_width),
      height=result.size.height,
    ),
    baseline: result.baseline,
    caret_positions: carets,
  }
}

///|
fn native_clamp_int(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

///|
fn native_text_cosmic_safe_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut changed = false
  for ch in text {
    let mapped = native_text_cosmic_safe_char(ch)
    if mapped != ch {
      changed = true
    }
    chars.push(mapped)
  }
  if changed {
    String::from_array(chars)
  } else {
    text
  }
}

///|
fn native_text_cosmic_safe_char(ch : Char) -> Char {
  match ch {
    '✓' => 'v'
    '🔍' => '?'
    '✕' => 'x'
    '•' => '*'
    '☑' => 'x'
    '☐' => 'o'
    '·' => '/'
    _ => ch
  }
}

///|
fn native_text_layout_runs(
  cache : NativeFontCache,
  run : @core.TextRun,
) -> Array[@moon_cosmic.LayoutRun] {
  build_native_text_buffer(cache, run).layout_runs().to_array()
}

///|
fn NativeFontCache::cosmic_layout_for_run(
  self : NativeFontCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> NativeTextLayout? {
  let runs = native_text_layout_runs(self, run)
  if runs.is_empty() || !self.has_loaded_fonts() {
    return None
  }
  let scale = native_text_scale(scale_factor)
  let glyphs : Array[NativeGlyphPlacement] = []
  let mut width = 0.0
  let mut height = run.font.size * 1.25
  for layout_run in runs {
    width = width.max(layout_run.line_w.to_double())
    height = height.max(
      (layout_run.line_top + layout_run.line_height).to_double(),
    )
    let offset = (
      0.0F,
      Float::from_double(layout_run.line_y.to_double() * scale),
    )
    for glyph in layout_run.glyphs {
      let physical = glyph.physical(offset, Float::from_double(scale))
      let cache_key = native_text_cache_key_with_fallback(
        self,
        run,
        glyph,
        physical.cache_key,
      )
      glyphs.push({
        key: cosmic_native_glyph_key(cache_key),
        x: physical.x.to_double() / scale,
        y: physical.y.to_double() / scale,
      })
    }
  }
  Some({
    size: @core.Size::new(width~, height~),
    baseline: run.font.size * 0.8,
    caret_positions: [],
    glyphs,
  })
}

///|
fn native_text_cache_key_with_fallback(
  cache : NativeFontCache,
  run : @core.TextRun,
  glyph : @moon_cosmic.LayoutGlyph,
  cache_key : @moon_cosmic.CacheKey,
) -> @moon_cosmic.CacheKey {
  if glyph.glyph_id != 0 {
    return cache_key
  }
  match native_text_codepoint_at(run.text, glyph.start) {
    None => cache_key
    Some(codepoint) =>
      match
        cache.font_system.resolve_for_codepoint(
          native_text_attrs_for_font(run.font),
          codepoint,
        ) {
        None => cache_key
        Some(font_id) =>
          match cache.font_system.get_font_entry(font_id) {
            None => cache_key
            Some(entry) => {
              let charmap = entry.charmap_proxy.materialize(entry.font)
              let glyph_id = charmap.map(codepoint).to_int()
              if glyph_id == 0 {
                cache_key
              } else {
                let (fallback_key, _, _) = @moon_cosmic.CacheKey::new(
                  font_id,
                  glyph_id,
                  glyph.font_size,
                  (0.0F, 0.0F),
                  glyph.font_weight,
                  glyph.cache_key_flags,
                )
                fallback_key
              }
            }
          }
      }
  }
}

///|
fn native_text_codepoint_at(text : String, index : Int) -> UInt? {
  if index < 0 {
    return None
  }
  let chars = text.to_array()
  if index >= chars.length() {
    None
  } else {
    Some(chars[index].to_uint())
  }
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
      match cache.text_engine.fallback_layout_run(cache, run, scale_factor) {
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
priv struct RasterGlyphPixel {
  x : Int
  y : Int
  color : @moon_cosmic.Color
}

///|
fn raster_glyph(
  cache : NativeFontCache,
  cache_key : @moon_cosmic.CacheKey,
) -> NativeRasterGlyph? {
  let pixels : Array[RasterGlyphPixel] = []
  cache.swash_cache.with_pixels(
    cache.font_system,
    cache_key,
    @moon_cosmic.Color::rgba(b'\xff', b'\xff', b'\xff', b'\xff'),
    fn(x, y, color) { pixels.push({ x, y, color }) },
  )
  if pixels.is_empty() {
    None
  } else {
    let mut min_x = pixels[0].x
    let mut min_y = pixels[0].y
    let mut max_x = pixels[0].x
    let mut max_y = pixels[0].y
    for pixel in pixels {
      min_x = min_x.min(pixel.x)
      min_y = min_y.min(pixel.y)
      max_x = max_x.max(pixel.x)
      max_y = max_y.max(pixel.y)
    }
    let bytes = Array::make((max_x - min_x + 1) * (max_y - min_y + 1), b'\x00')
    for pixel in pixels {
      let x = pixel.x - min_x
      let y = pixel.y - min_y
      bytes[y * (max_x - min_x + 1) + x] = pixel.color.a()
    }
    Some({
      width: max_x - min_x + 1,
      height: max_y - min_y + 1,
      bearing_x: min_x,
      bearing_y: min_y,
      pixels: Bytes::from_array(bytes),
    })
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
  push_text_vertex(vertices, p0, size, u0, v0, color)
  push_text_vertex(vertices, p1, size, u0, v1, color)
  push_text_vertex(vertices, p2, size, u1, v1, color)
  push_text_vertex(vertices, p0, size, u0, v0, color)
  push_text_vertex(vertices, p2, size, u1, v1, color)
  push_text_vertex(vertices, p3, size, u1, v0, color)
}

///|
fn push_text_vertex(
  vertices : Array[TextVertex],
  point : @core.Point,
  size : @core.Size,
  u : Double,
  v : Double,
  color : @core.Color,
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
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) uv: vec2<f32>,
    #|  @location(2) color: vec4<f32>,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.uv = uv;
    #|  out.color = color;
    #|  return out;
    #|}
    #|
    #|@group(0) @binding(0) var glyph_sampler : sampler;
    #|@group(0) @binding(1) var glyph_atlas : texture_2d<f32>;
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let sample = textureSample(glyph_atlas, glyph_sampler, in.uv);
    #|  return vec4<f32>(in.color.rgb, in.color.a * sample.a);
    #|}
    #|
  shader
}
