///|
let atlas_width : Int = 1024

///|
let atlas_height : Int = 1024

///|
let atlas_padding : Int = 1

///|
priv struct NativeFontFace {
  key : String
  path : String
  face_index : Int
  ft_face : @ft_base.FaceRec
  hb_font : @hb_font.Font
}

///|
priv struct NativeFontCache {
  faces : Map[String, Array[NativeFontFace]]
  warned_paths : Map[String, Bool]
}

///|
priv struct ShapedGlyph {
  glyph_id : UInt
  unicode : UInt
  x_offset : Double
  y_offset : Double
}

///|
priv struct RenderGlyph {
  face : NativeFontFace
  glyph_id : UInt
  x_advance : Double
  x_offset : Double
  y_offset : Double
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
fn NativeFontCache::new() -> NativeFontCache {
  { faces: {}, warned_paths: {} }
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
  "/System/Library/Fonts/Supplemental/Arial.ttf"
}

///|
fn macos_bold_font_path() -> String {
  "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
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
fn NativeFontCache::faces_for_path(
  self : NativeFontCache,
  path : String,
) -> Array[NativeFontFace] {
  match self.faces.get(path) {
    Some(faces) => faces
    None => {
      if !@fs.path_exists(path) {
        self.warn_font_once(path)
        return []
      }
      try {
        let bytes = @fs.read_file_to_bytes(path)
        let probe_face = @freetype.from_bytes(bytes)
        let face_count = native_font_face_count(probe_face)
        let faces : Array[NativeFontFace] = []
        for face_index in 0..<face_count {
          match load_native_font_face(path, bytes, face_index) {
            Some(face) => faces.push(face)
            None => ()
          }
        }
        if faces.is_empty() {
          self.warn_font_once(path)
        }
        self.faces[path] = faces
        faces
      } catch {
        _ => {
          self.warn_font_once(path)
          []
        }
      }
    }
  }
}

///|
fn native_font_face_count(face : @ft_base.FaceRec) -> Int {
  let count = face.num_faces().to_int()
  if count < 1 {
    1
  } else {
    count
  }
}

///|
fn load_native_font_face(
  path : String,
  bytes : Bytes,
  face_index : Int,
) -> NativeFontFace? {
  try {
    let ft_face = @freetype.from_bytes(bytes, face_index~)
    let hb_face = @hb_face.Face::from_bytes(bytes, index=face_index)
    let hb_font = @hb_font.Font::new(hb_face)
    Some({
      key: native_font_face_key(path, face_index),
      path,
      face_index,
      ft_face,
      hb_font,
    })
  } catch {
    _ => None
  }
}

///|
fn native_font_face_key(path : String, face_index : Int) -> String {
  "\{path}#\{face_index}"
}

///|
fn NativeFontCache::faces_for_font(
  self : NativeFontCache,
  font : @core.FontSpec,
) -> Array[NativeFontFace] {
  let faces : Array[NativeFontFace] = []
  for path in native_text_fallback_font_paths_for_spec(font) {
    for face in self.faces_for_path(path) {
      if !faces.any(existing => same_native_font_face(existing, face)) {
        faces.push(face)
      }
    }
  }
  faces
}

///|
fn same_native_font_face(left : NativeFontFace, right : NativeFontFace) -> Bool {
  left.path == right.path && left.face_index == right.face_index
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
fn text_pixel_size(font : @core.FontSpec) -> Int {
  let size = font.size.round().to_int()
  if size < 1 {
    1
  } else {
    size
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
fn shape_text(
  face : NativeFontFace,
  text : String,
  pixel_size : Int,
) -> Array[ShapedGlyph] {
  if text == "" {
    return []
  }
  let scale = pixel_size * 64
  face.hb_font.set_scale(scale, scale)
  face.hb_font.set_ppem(pixel_size, pixel_size)
  let buffer = @hb_buffer.Buffer::new()
  buffer.add_string(text)
  match @hb_shape.shape(face.hb_font, buffer) {
    Ok(_) => shaped_glyphs_from_buffer(buffer)
    Err(_) => {
      let fallback = @hb_buffer.Buffer::new()
      fallback.add_string(text)
      match fallback.shape_basic(face.hb_font) {
        Ok(_) => shaped_glyphs_from_buffer(fallback)
        Err(_) => []
      }
    }
  }
}

///|
fn shaped_glyphs_from_buffer(buffer : @hb_buffer.Buffer) -> Array[ShapedGlyph] {
  let infos = buffer.infos()
  let positions = buffer.positions()
  let glyphs : Array[ShapedGlyph] = []
  let count = infos.length().min(positions.length())
  for i in 0..<count {
    let info = infos[i]
    let pos = positions[i]
    glyphs.push({
      glyph_id: info.codepoint,
      unicode: info.unicode,
      x_offset: fixed_26_6_to_double(pos.x_offset),
      y_offset: fixed_26_6_to_double(pos.y_offset),
    })
  }
  glyphs
}

///|
fn fixed_26_6_to_double(value : Int) -> Double {
  value.to_double() / 64.0
}

///|
fn build_native_text_run(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  run : @core.TextRun,
  state : NativePaintState,
  size : @core.Size,
) -> TextRunBuildResult {
  let vertices : Array[TextVertex] = []
  let atlas_full = append_text_run_vertices(
    cache, atlas, run, state, size, vertices,
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
  vertices : Array[TextVertex],
) -> Bool {
  let faces = cache.faces_for_font(run.font)
  if faces.length() == 0 {
    false
  } else {
    let face = faces[0]
    let pixel_size = text_pixel_size(run.font)
    let shaped = shape_text(face, run.text, pixel_size)
    if shaped.is_empty() {
      return false
    }
    let resolved = resolve_shaped_glyphs(
      faces,
      face,
      shaped,
      pixel_size,
      run.font,
    )
    if resolved.is_empty() {
      return false
    }
    let mut total_width = 0.0
    for glyph in resolved {
      total_width = total_width + glyph.x_advance
    }
    let frame = run.frame
    let start_extra = text_align_extra(run.align, frame.size.width, total_width)
    let mut cursor_x = frame.origin.x + start_extra
    let center_ascent = pixel_size.to_double() * 0.72
    let baseline_extra = (frame.size.height + center_ascent) / 2.0
    let baseline = frame.origin.y + pixel_size.to_double().max(baseline_extra)
    for glyph in resolved {
      match
        atlas.ensure_glyph(glyph.face, run.font, pixel_size, glyph.glyph_id) {
        GlyphReady(entry) => {
          if entry.width > 0 && entry.height > 0 {
            let gx = cursor_x + glyph.x_offset + entry.bearing_x.to_double()
            let gy = baseline - glyph.y_offset - entry.bearing_y.to_double()
            append_text_quad(
              vertices,
              gx,
              gy,
              entry,
              atlas,
              state,
              size,
              run.color.multiply_alpha(state.opacity),
            )
          }
          cursor_x = cursor_x + glyph.x_advance
        }
        GlyphMissing => cursor_x = cursor_x + glyph.x_advance
        GlyphAtlasFull => return true
      }
    }
    false
  }
}

///|
fn resolve_shaped_glyphs(
  faces : Array[NativeFontFace],
  primary : NativeFontFace,
  shaped : Array[ShapedGlyph],
  pixel_size : Int,
  font : @core.FontSpec,
) -> Array[RenderGlyph] {
  let resolved : Array[RenderGlyph] = []
  for glyph in shaped {
    resolved.push(resolve_shaped_glyph(faces, primary, glyph, pixel_size, font))
  }
  resolved
}

///|
fn resolve_shaped_glyph(
  faces : Array[NativeFontFace],
  primary : NativeFontFace,
  glyph : ShapedGlyph,
  pixel_size : Int,
  font : @core.FontSpec,
) -> RenderGlyph {
  if glyph.glyph_id != 0U {
    return render_glyph_for_face(primary, glyph, font)
  }
  match fallback_face_for_codepoint(faces, primary, glyph.unicode) {
    Some(face) =>
      match shape_codepoint(face, glyph.unicode, pixel_size) {
        Some(fallback_glyph) =>
          render_glyph_for_face(face, fallback_glyph, font)
        None => render_glyph_for_face(primary, glyph, font)
      }
    None => render_glyph_for_face(primary, glyph, font)
  }
}

///|
fn render_glyph_for_face(
  face : NativeFontFace,
  glyph : ShapedGlyph,
  font : @core.FontSpec,
) -> RenderGlyph {
  {
    face,
    glyph_id: glyph.glyph_id,
    x_advance: @core.text_layout_codepoint_advance(font, glyph.unicode),
    x_offset: glyph.x_offset,
    y_offset: glyph.y_offset,
  }
}

///|
fn fallback_face_for_codepoint(
  faces : Array[NativeFontFace],
  primary : NativeFontFace,
  codepoint : UInt,
) -> NativeFontFace? {
  for face in faces {
    if face.key != primary.key && face_supports_codepoint(face, codepoint) {
      return Some(face)
    }
  }
  None
}

///|
fn face_supports_codepoint(face : NativeFontFace, codepoint : UInt) -> Bool {
  @freetype.get_char_index(face.ft_face, codepoint) != 0U
}

///|
fn shape_codepoint(
  face : NativeFontFace,
  codepoint : UInt,
  pixel_size : Int,
) -> ShapedGlyph? {
  match shape_codepoint_with_harfbuzz(face, codepoint, pixel_size) {
    Some(glyph) => Some(glyph)
    None => shape_codepoint_with_freetype(face, codepoint, pixel_size)
  }
}

///|
fn shape_codepoint_with_harfbuzz(
  face : NativeFontFace,
  codepoint : UInt,
  pixel_size : Int,
) -> ShapedGlyph? {
  let scale = pixel_size * 64
  face.hb_font.set_scale(scale, scale)
  face.hb_font.set_ppem(pixel_size, pixel_size)
  let buffer = @hb_buffer.Buffer::new()
  buffer.add_codepoint(codepoint)
  match @hb_shape.shape(face.hb_font, buffer) {
    Ok(_) => first_non_missing_glyph(buffer)
    Err(_) => {
      let fallback = @hb_buffer.Buffer::new()
      fallback.add_codepoint(codepoint)
      match fallback.shape_basic(face.hb_font) {
        Ok(_) => first_non_missing_glyph(fallback)
        Err(_) => None
      }
    }
  }
}

///|
fn shape_codepoint_with_freetype(
  face : NativeFontFace,
  codepoint : UInt,
  pixel_size : Int,
) -> ShapedGlyph? {
  let glyph_id = @freetype.get_char_index(face.ft_face, codepoint)
  if glyph_id == 0U {
    return None
  }
  try {
    let size = pixel_size.reinterpret_as_uint()
    @freetype.set_pixel_sizes(face.ft_face, 0U, size)
    @freetype.load_glyph(
      face.ft_face,
      glyph_id,
      load_flags=@ft_base.LOAD_DEFAULT,
    )
    Some({ glyph_id, unicode: codepoint, x_offset: 0.0, y_offset: 0.0 })
  } catch {
    _ => Some({ glyph_id, unicode: codepoint, x_offset: 0.0, y_offset: 0.0 })
  }
}

///|
fn first_non_missing_glyph(buffer : @hb_buffer.Buffer) -> ShapedGlyph? {
  for glyph in shaped_glyphs_from_buffer(buffer) {
    if glyph.glyph_id != 0U {
      return Some(glyph)
    }
  }
  None
}

///|
fn GlyphAtlas::ensure_glyph(
  self : GlyphAtlas,
  face : NativeFontFace,
  font : @core.FontSpec,
  pixel_size : Int,
  glyph_id : UInt,
) -> GlyphLookup {
  let key = glyph_cache_key(face.key, pixel_size, font.weight, glyph_id)
  match self.entries.get(key) {
    Some(entry) => GlyphReady(entry)
    None =>
      match raster_glyph(face, pixel_size, glyph_id) {
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
              self.entries[key] = entry
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
  bitmap : @ft_types.Bitmap
}

///|
fn raster_glyph(
  face : NativeFontFace,
  pixel_size : Int,
  glyph_id : UInt,
) -> RasterGlyph? {
  try {
    let size = pixel_size.reinterpret_as_uint()
    @freetype.set_pixel_sizes(face.ft_face, 0U, size)
    @freetype.load_glyph(
      face.ft_face,
      glyph_id,
      load_flags=@ft_base.LOAD_RENDER,
    )
    let slot = face.ft_face.glyph()
    let bitmap = slot.bitmap()
    let width = bitmap.width().reinterpret_as_int()
    let height = bitmap.rows().reinterpret_as_int()
    Some({
      width,
      height,
      bearing_x: slot.bitmap_left(),
      bearing_y: slot.bitmap_top(),
      bitmap,
    })
  } catch {
    _ => None
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
  for y in 0..<raster.height {
    for x in 0..<raster.width {
      let alpha = bitmap_alpha_at(raster.bitmap, x, y)
      let idx = ((dst_y + y) * self.width + dst_x + x) * 4
      self.pixels[idx] = b'\xff'
      self.pixels[idx + 1] = b'\xff'
      self.pixels[idx + 2] = b'\xff'
      self.pixels[idx + 3] = alpha
    }
  }
}

///|
fn bitmap_alpha_at(bitmap : @ft_types.Bitmap, x : Int, y : Int) -> Byte {
  let buf = bitmap.buffer()
  let pitch = bitmap.pitch()
  let abs_pitch = if pitch < 0 { -pitch } else { pitch }
  let rows = bitmap.rows().reinterpret_as_int()
  let row = if pitch < 0 { rows - 1 - y } else { y }
  match bitmap.pixel_mode() {
    @ft_types.PixelMode::Gray => {
      let idx = row * abs_pitch + x
      if idx >= 0 && idx < buf.length() {
        buf[idx]
      } else {
        b'\x00'
      }
    }
    @ft_types.PixelMode::Bgra => {
      let idx = row * abs_pitch + x * 4 + 3
      if idx >= 0 && idx < buf.length() {
        buf[idx]
      } else {
        b'\x00'
      }
    }
    @ft_types.PixelMode::Lcd => {
      let idx = row * abs_pitch + x * 3
      if idx + 2 < buf.length() {
        let sum = buf[idx].to_int() +
          buf[idx + 1].to_int() +
          buf[idx + 2].to_int()
        (sum / 3).to_byte()
      } else {
        b'\x00'
      }
    }
    @ft_types.PixelMode::LcdV => {
      let idx = row * abs_pitch + x
      if idx < buf.length() {
        buf[idx]
      } else {
        b'\x00'
      }
    }
    @ft_types.PixelMode::Mono => {
      let idx = row * abs_pitch + x / 8
      if idx < buf.length() {
        let bit = 7 - x % 8
        if ((buf[idx].to_uint() >> bit) & 1U) == 1U {
          b'\xff'
        } else {
          b'\x00'
        }
      } else {
        b'\x00'
      }
    }
    _ => b'\x00'
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
  color : @core.Color,
) -> Unit {
  let p0 = transform_point(state.transform, x, y)
  let p1 = transform_point(state.transform, x, y + entry.height.to_double())
  let p2 = transform_point(
    state.transform,
    x + entry.width.to_double(),
    y + entry.height.to_double(),
  )
  let p3 = transform_point(state.transform, x + entry.width.to_double(), y)
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
fn glyph_cache_key(
  path : String,
  pixel_size : Int,
  weight : Int,
  glyph_id : UInt,
) -> String {
  "\{path}|\{pixel_size}|\{weight}|\{glyph_id}"
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
