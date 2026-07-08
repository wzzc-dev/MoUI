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
