///|
priv struct CosmicFontCatalog {
  regular_path : String
  bold_path : String
  cjk_path : String
}

///|
priv struct CosmicTextCache {
  mut font_system : @moon_cosmic.FontSystem
  swash_cache : @moon_cosmic.SwashCache
  catalog : CosmicFontCatalog
  loaded_paths : Map[String, Bool]
  warned_paths : Map[String, Bool]
  glyph_keys : Map[String, @moon_cosmic.CacheKey]
}

///|
priv struct RasterGlyphPixel {
  x : Int
  y : Int
  color : @moon_cosmic.Color
}

///|
pub fn cosmic_text_engine() -> @wgpu_renderer.NativeTextEngine {
  let cache = CosmicTextCache::new()
  @wgpu_renderer.native_platform_text_engine(
    @wgpu_renderer.NativePlatformTextProvider::new(
      id="native-wgpu-cosmic-fallback",
      measure=input => cache.measure(input),
      layout_run=(run, scale_factor) => cache.layout_for_run(run, scale_factor),
      raster_glyph=(cache_key, _payload) => cache.raster_glyph(cache_key),
      register_font_data=(family, data) => cache.load_font_data(family, data),
    ),
  )
}

///|
fn CosmicTextCache::new() -> CosmicTextCache {
  {
    font_system: @moon_cosmic.FontSystem::new().set_fallback_profile(
      cosmic_text_platform_fallback_profile(),
    ),
    swash_cache: @moon_cosmic.SwashCache::new(),
    catalog: CosmicFontCatalog::platform_default(),
    loaded_paths: {},
    warned_paths: {},
    glyph_keys: {},
  }
}

///|
#cfg(platform="windows")
fn cosmic_text_platform_fallback_profile() -> @moon_cosmic.FallbackProfile {
  @moon_cosmic.FallbackProfile::Windows
}

///|
#cfg(platform="macos")
fn cosmic_text_platform_fallback_profile() -> @moon_cosmic.FallbackProfile {
  @moon_cosmic.FallbackProfile::MacOS
}

///|
#cfg(platform="linux")
fn cosmic_text_platform_fallback_profile() -> @moon_cosmic.FallbackProfile {
  @moon_cosmic.FallbackProfile::Unix
}

///|
#cfg(not(any(platform="windows", platform="macos", platform="linux")))
fn cosmic_text_platform_fallback_profile() -> @moon_cosmic.FallbackProfile {
  @moon_cosmic.FallbackProfile::Other
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
fn linux_regular_font_path() -> String {
  first_existing_font_path([
    "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf", "/usr/share/fonts/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
  ])
}

///|
fn linux_bold_font_path() -> String {
  first_existing_font_path([
    "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf", "/usr/share/fonts/noto/NotoSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
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
  first_existing_font_path([
    "/System/Library/Fonts/STHeiti Medium.ttc", "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/Songti.ttc",
  ])
}

///|
fn linux_cjk_font_path() -> String {
  first_existing_font_path([
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc", "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
  ])
}

///|
fn cosmic_regular_font_path() -> String {
  first_existing_font_path([
    windows_regular_font_path(),
    macos_regular_font_path(),
    linux_regular_font_path(),
  ])
}

///|
fn cosmic_bold_font_path() -> String {
  first_existing_font_path([
    windows_bold_font_path(),
    macos_bold_font_path(),
    linux_bold_font_path(),
  ])
}

///|
fn cosmic_cjk_font_path() -> String {
  first_existing_font_path([
    windows_cjk_font_path(),
    macos_cjk_font_path(),
    linux_cjk_font_path(),
  ])
}

///|
fn CosmicFontCatalog::platform_default() -> CosmicFontCatalog {
  {
    regular_path: cosmic_regular_font_path(),
    bold_path: cosmic_bold_font_path(),
    cjk_path: cosmic_cjk_font_path(),
  }
}

///|
fn CosmicFontCatalog::font_path_for_spec(
  self : CosmicFontCatalog,
  font : @core.FontSpec,
) -> String {
  if font.weight >= 600 {
    self.bold_path
  } else {
    self.regular_path
  }
}

///|
fn CosmicFontCatalog::fallback_font_paths_for_spec(
  self : CosmicFontCatalog,
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
pub fn cosmic_text_font_path_for_spec(font : @core.FontSpec) -> String {
  CosmicFontCatalog::platform_default().font_path_for_spec(font)
}

///|
pub fn cosmic_text_fallback_font_paths_for_spec(
  font : @core.FontSpec,
) -> Array[String] {
  CosmicFontCatalog::platform_default().fallback_font_paths_for_spec(font)
}

///|
fn CosmicTextCache::ensure_fonts_for_font(
  self : CosmicTextCache,
  font : @core.FontSpec,
) -> Unit {
  for path in self.catalog.fallback_font_paths_for_spec(font) {
    self.load_font_path(path)
  }
}

///|
fn CosmicTextCache::load_font_path(
  self : CosmicTextCache,
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
fn CosmicTextCache::load_font_data(
  self : CosmicTextCache,
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
fn CosmicTextCache::has_loaded_fonts(self : CosmicTextCache) -> Bool {
  self.font_system.fonts().length() > 0
}

///|
fn CosmicTextCache::warn_font_once(
  self : CosmicTextCache,
  path : String,
) -> Unit {
  match self.warned_paths.get(path) {
    Some(true) => ()
    _ => {
      println("MoUI cosmic text: unable to load font: \{path}")
      self.warned_paths[path] = true
    }
  }
}

///|
fn cosmic_text_attrs_for_font(font : @core.FontSpec) -> @moon_cosmic.Attrs {
  @moon_cosmic.Attrs::new()
  .family(cosmic_text_family_for_font(font))
  .style(cosmic_text_style_for_font(font.style))
  .weight(@moon_cosmic.Weight::new(font.weight))
}

///|
fn cosmic_text_style_for_font(style : @core.FontStyle) -> @moon_swash.Style {
  match style {
    @core.FontStyle::Normal => @moon_swash.Style::Normal
    @core.FontStyle::Italic => @moon_swash.Style::Italic
  }
}

///|
fn cosmic_text_family_for_font(font : @core.FontSpec) -> @moon_cosmic.Family {
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
fn build_cosmic_text_buffer(
  cache : CosmicTextCache,
  run : @core.TextRun,
) -> @moon_cosmic.Buffer {
  cache.ensure_fonts_for_font(run.font)
  let metrics = @moon_cosmic.Metrics::new(
    Float::from_double(run.font.size),
    Float::from_double(run.font.size * 1.25),
  )
  let attrs = cosmic_text_attrs_for_font(run.font)
  let text = cosmic_text_safe_text(run.text)
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
fn build_cosmic_text_input_buffer(
  cache : CosmicTextCache,
  input : @core.TextLayoutInput,
) -> @moon_cosmic.Buffer {
  cache.ensure_fonts_for_font(input.font)
  let metrics = @moon_cosmic.Metrics::new(
    Float::from_double(input.font.size),
    Float::from_double(input.font.size * 1.25),
  )
  let attrs = cosmic_text_attrs_for_font(input.font)
  let text = cosmic_text_safe_text(input.text)
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
fn CosmicTextCache::measure(
  self : CosmicTextCache,
  input : @core.TextLayoutInput,
) -> @wgpu_renderer.NativeTextLayout? {
  let buffer = build_cosmic_text_input_buffer(self, input)
  if !self.has_loaded_fonts() {
    return None
  }
  let raw = cosmic_text_layout_result_from_buffer(input, buffer)
  let result = match input.max_width {
    Some(max_width) => cosmic_clamp_text_layout_result(raw, max_width)
    None => raw
  }
  Some(
    @wgpu_renderer.NativeTextLayout::new(
      size=result.size,
      baseline=result.baseline,
      caret_positions=result.caret_positions,
    ),
  )
}

///|
fn cosmic_text_layout_result_from_buffer(
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
      let start = cosmic_clamp_int(glyph.start, 0, char_count)
      let end = cosmic_clamp_int(glyph.end, start, char_count)
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
    return @core.TextSystem::fallback().measure_text(input)
  }
  cosmic_fill_missing_caret_positions(carets)
  {
    size: @core.Size::new(width~, height~),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
fn cosmic_fill_missing_caret_positions(carets : Array[Double]) -> Unit {
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
fn cosmic_clamp_text_layout_result(
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
fn cosmic_clamp_int(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

///|
fn cosmic_text_safe_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut changed = false
  for ch in text {
    let mapped = cosmic_text_safe_char(ch)
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
fn cosmic_text_safe_char(ch : Char) -> Char {
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
fn cosmic_text_layout_runs(
  cache : CosmicTextCache,
  run : @core.TextRun,
) -> Array[@moon_cosmic.LayoutRun] {
  build_cosmic_text_buffer(cache, run).layout_runs().to_array()
}

///|
fn CosmicTextCache::layout_for_run(
  self : CosmicTextCache,
  run : @core.TextRun,
  scale_factor : Double,
) -> @wgpu_renderer.NativeTextLayout? {
  let runs = cosmic_text_layout_runs(self, run)
  if runs.is_empty() || !self.has_loaded_fonts() {
    return None
  }
  let scale = cosmic_text_scale(scale_factor)
  let glyphs : Array[@wgpu_renderer.NativeGlyphPlacement] = []
  let baseline = run.font.size * 0.8
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
      if !cosmic_text_glyph_is_whitespace(run, glyph) {
        let physical = glyph.physical(offset, Float::from_double(scale))
        let cache_key = cosmic_text_cache_key_with_fallback(
          self,
          run,
          glyph,
          physical.cache_key,
        )
        let key = self.native_glyph_key(cache_key)
        glyphs.push(
          @wgpu_renderer.NativeGlyphPlacement::new(
            key~,
            x=physical.x.to_double() / scale,
            y=physical.y.to_double() / scale - baseline,
          ),
        )
      }
    }
  }
  Some(
    @wgpu_renderer.NativeTextLayout::new(
      size=@core.Size::new(width~, height~),
      baseline~,
      glyphs~,
    ),
  )
}

///|
fn cosmic_text_glyph_is_whitespace(
  run : @core.TextRun,
  glyph : @moon_cosmic.LayoutGlyph,
) -> Bool {
  cosmic_text_source_range_is_whitespace(
    cosmic_text_safe_text(run.text),
    glyph.start,
    glyph.end,
  )
}

///|
fn CosmicTextCache::native_glyph_key(
  self : CosmicTextCache,
  key : @moon_cosmic.CacheKey,
) -> @wgpu_renderer.NativeGlyphKey {
  let cache_key = cosmic_glyph_cache_key(key)
  self.glyph_keys[cache_key] = key
  @wgpu_renderer.native_platform_glyph_key(
    cache_key~,
    payload=Bytes::from_array([]),
  )
}

///|
fn cosmic_glyph_cache_key(key : @moon_cosmic.CacheKey) -> String {
  "cosmic:" + key.to_string()
}

///|
fn cosmic_text_cache_key_with_fallback(
  cache : CosmicTextCache,
  run : @core.TextRun,
  glyph : @moon_cosmic.LayoutGlyph,
  cache_key : @moon_cosmic.CacheKey,
) -> @moon_cosmic.CacheKey {
  match cosmic_text_codepoint_at(cosmic_text_safe_text(run.text), glyph.start) {
    None => cache_key
    Some(codepoint) =>
      if cosmic_text_glyph_matches_codepoint(cache, glyph, codepoint) {
        cache_key
      } else {
        cosmic_text_fallback_cache_key(cache, run, cache_key, codepoint)
      }
  }
}

///|
fn cosmic_text_glyph_matches_codepoint(
  cache : CosmicTextCache,
  glyph : @moon_cosmic.LayoutGlyph,
  codepoint : UInt,
) -> Bool {
  if glyph.glyph_id == 0 {
    return false
  }
  if !cosmic_text_codepoint_needs_direct_cmap_check(codepoint) {
    return true
  }
  match cache.font_system.get_font_entry(glyph.font_id) {
    None => false
    Some(entry) => {
      let charmap = entry.charmap_proxy.materialize(entry.font)
      charmap.map(codepoint).to_int() == glyph.glyph_id
    }
  }
}

///|
fn cosmic_text_codepoint_needs_direct_cmap_check(codepoint : UInt) -> Bool {
  (codepoint >= 0x2E80U && codepoint <= 0x9FFFU) ||
  (codepoint >= 0xF900U && codepoint <= 0xFAFFU) ||
  (codepoint >= 0x20000U && codepoint <= 0x2FA1FU) ||
  (codepoint >= 0x3040U && codepoint <= 0x30FFU) ||
  (codepoint >= 0x3100U && codepoint <= 0x312FU) ||
  (codepoint >= 0xAC00U && codepoint <= 0xD7AFU)
}

///|
fn cosmic_text_fallback_cache_key(
  cache : CosmicTextCache,
  run : @core.TextRun,
  cache_key : @moon_cosmic.CacheKey,
  codepoint : UInt,
) -> @moon_cosmic.CacheKey {
  match
    cache.font_system.resolve_for_codepoint(
      cosmic_text_attrs_for_font(run.font),
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
              Float::reinterpret_from_uint(cache_key.font_size_bits),
              (cache_key.x_bin.as_float(), cache_key.y_bin.as_float()),
              cache_key.font_weight,
              cache_key.flags,
            )
            fallback_key
          }
        }
      }
  }
}

///|
fn cosmic_text_codepoint_at(text : String, index : Int) -> UInt? {
  match cosmic_text_char_at(text, index) {
    Some(ch) => Some(ch.to_uint())
    None => None
  }
}

///|
fn cosmic_text_char_at(text : String, index : Int) -> Char? {
  if index < 0 {
    return None
  }
  for pair in text.iter2() {
    if pair.0 == index {
      return Some(pair.1)
    }
    if pair.0 > index {
      return None
    }
  }
  None
}

///|
fn cosmic_text_source_range_is_whitespace(
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  if end <= start {
    return false
  }
  let from = start.max(0)
  let to = end.max(from)
  let mut saw_char = false
  for pair in text.iter2() {
    let index = pair.0
    if index >= from && index < to {
      saw_char = true
      if !pair.1.is_whitespace() {
        return false
      }
    }
  }
  saw_char
}

///|
fn cosmic_text_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn CosmicTextCache::raster_glyph(
  self : CosmicTextCache,
  cache_key : String,
) -> @wgpu_renderer.NativeRasterGlyph? {
  match self.glyph_keys.get(cache_key) {
    Some(key) => self.raster_cosmic_glyph(key)
    None => None
  }
}

///|
fn CosmicTextCache::raster_cosmic_glyph(
  self : CosmicTextCache,
  cache_key : @moon_cosmic.CacheKey,
) -> @wgpu_renderer.NativeRasterGlyph? {
  let pixels : Array[RasterGlyphPixel] = []
  self.swash_cache.with_pixels(
    self.font_system,
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
    Some(
      @wgpu_renderer.NativeRasterGlyph::new(
        width=max_x - min_x + 1,
        height=max_y - min_y + 1,
        bearing_x=min_x,
        bearing_y=min_y,
        pixels=Bytes::from_array(bytes),
      ),
    )
  }
}
