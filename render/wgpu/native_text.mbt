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
  loaded_paths : Map[String, Bool]
  warned_paths : Map[String, Bool]
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
  mut entries : Map[@moon_cosmic.CacheKey, GlyphAtlasEntry]
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
fn NativeFontCache::new() -> NativeFontCache {
  {
    font_system: @moon_cosmic.FontSystem::new(),
    swash_cache: @moon_cosmic.SwashCache::new(),
    loaded_paths: {},
    warned_paths: {},
  }
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
    "/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/Hiragino Sans GB.ttc", "/System/Library/Fonts/Supplemental/Arial.ttf",
  ])
}

///|
fn macos_bold_font_path() -> String {
  first_existing_font_path([
    "/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/Hiragino Sans GB.ttc", "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
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
fn first_existing_font_path(paths : Array[String]) -> String {
  for path in paths {
    if @fs.path_exists(path) {
      return path
    }
  }
  paths[0]
}

///|
fn native_text_font_path_for_spec(font : @core.FontSpec) -> String {
  if font.weight >= 600 {
    native_bold_font_path()
  } else {
    native_regular_font_path()
  }
}

///|
fn native_text_fallback_font_paths_for_spec(
  font : @core.FontSpec,
) -> Array[String] {
  [native_text_font_path_for_spec(font), native_cjk_font_path()]
}

///|
fn NativeFontCache::ensure_fonts_for_font(
  self : NativeFontCache,
  font : @core.FontSpec,
) -> Unit {
  for path in native_text_fallback_font_paths_for_spec(font) {
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
fn native_text_attrs_for_font(font : @core.FontSpec) -> @moon_cosmic.Attrs {
  @moon_cosmic.Attrs::new()
  .family(native_text_family_for_font(font))
  .weight(@moon_cosmic.Weight::new(font.weight))
}

///|
fn native_text_family_for_font(font : @core.FontSpec) -> @moon_cosmic.Family {
  if font.family.contains("monospace") ||
    font.family.contains("Mono") ||
    font.family.contains("Menlo") ||
    font.family.contains("Consolas") {
    @moon_cosmic.Family::UiMonospace
  } else if font.family != "" {
    @moon_cosmic.Family::Name(font.family)
  } else {
    @moon_cosmic.Family::UiSansSerif
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
fn native_text_vertical_extra(
  frame : @core.Rect,
  layout_run : @moon_cosmic.LayoutRun,
) -> Double {
  let extra = frame.size.height - layout_run.line_height.to_double()
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
  let runs = native_text_layout_runs(cache, run)
  if runs.is_empty() || !cache.has_loaded_fonts() {
    return false
  }
  let scale = native_text_scale(scale_factor)
  for layout_run in runs {
    let start_extra = text_align_extra(
      run.align,
      run.frame.size.width,
      layout_run.line_w.to_double(),
    )
    let vertical_extra = native_text_vertical_extra(run.frame, layout_run)
    let offset = (
      Float::from_double((run.frame.origin.x + start_extra) * scale),
      Float::from_double(
        (run.frame.origin.y + vertical_extra + layout_run.line_y.to_double()) *
        scale,
      ),
    )
    for glyph in layout_run.glyphs {
      let physical = glyph.physical(offset, Float::from_double(scale))
      match atlas.ensure_glyph(cache, physical.cache_key) {
        GlyphReady(entry) =>
          if entry.width > 0 && entry.height > 0 {
            append_text_quad(
              vertices,
              (physical.x.to_double() + entry.bearing_x.to_double()) / scale,
              (physical.y.to_double() + entry.bearing_y.to_double()) / scale,
              entry,
              atlas,
              state,
              size,
              scale,
              run.color.multiply_alpha(state.opacity),
            )
          }
        GlyphMissing => ()
        GlyphAtlasFull => return true
      }
    }
  }
  false
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
  cache_key : @moon_cosmic.CacheKey,
) -> GlyphLookup {
  match self.entries.get(cache_key) {
    Some(entry) => GlyphReady(entry)
    None =>
      match raster_glyph(cache, cache_key) {
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
              self.entries[cache_key] = entry
              self.dirty = true
              GlyphReady(entry)
            }
          }
      }
  }
}

///|
priv struct RasterGlyph {
  width : Int
  height : Int
  bearing_x : Int
  bearing_y : Int
  pixels : Array[RasterGlyphPixel]
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
) -> RasterGlyph? {
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
    Some({
      width: max_x - min_x + 1,
      height: max_y - min_y + 1,
      bearing_x: min_x,
      bearing_y: min_y,
      pixels,
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
  raster : RasterGlyph,
) -> Unit {
  for pixel in raster.pixels {
    let x = dst_x + pixel.x - raster.bearing_x
    let y = dst_y + pixel.y - raster.bearing_y
    let dst = (y * self.width + x) * 4
    self.pixels[dst] = pixel.color.r()
    self.pixels[dst + 1] = pixel.color.g()
    self.pixels[dst + 2] = pixel.color.b()
    self.pixels[dst + 3] = pixel.color.a()
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
