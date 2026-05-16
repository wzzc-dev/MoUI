///|
priv enum NativeDrawItem {
  NativeVisual(Int, Int)
  NativeText(Int, Int)
}

///|
priv struct NativeDrawPlan {
  visual_vertices : Array[VisualVertex]
  text_vertices : Array[TextVertex]
  items : Array[NativeDrawItem]
  atlas_dirty : Bool
}

///|
priv struct VisualVertex {
  x : Double
  y : Double
  local_x : Double
  local_y : Double
  width : Double
  height : Double
  radius : Double
  mode : Double
  stroke_width : Double
  blur_radius : Double
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
  r0 : Double
  g0 : Double
  b0 : Double
  a0 : Double
  r1 : Double
  g1 : Double
  b1 : Double
  a1 : Double
}

///|
fn build_native_draw_plan(
  cache : NativeFontCache,
  atlas : GlyphAtlas,
  commands : Array[@core.DrawCommand],
  size : @core.Size,
) -> NativeDrawPlan {
  let was_dirty = atlas.dirty
  for attempt in 0..<2 {
    let visual_vertices : Array[VisualVertex] = []
    let text_vertices : Array[TextVertex] = []
    let items : Array[NativeDrawItem] = []
    let mut full = false
    for command in commands {
      if !full {
        match command {
          @core.DrawCommand::Clear(_) => ()
          @core.DrawCommand::FillRect(rect, color) =>
            append_visual_item(
              visual_vertices,
              items,
              rect,
              radius=0.0,
              brush=@core.Brush::solid(color),
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              size~,
            )
          @core.DrawCommand::StrokeRect(rect, color, width) =>
            append_visual_item(
              visual_vertices,
              items,
              rect,
              radius=0.0,
              brush=@core.Brush::solid(color),
              mode=visual_mode_stroke,
              stroke_width=width,
              blur_radius=0.0,
              size~,
            )
          @core.DrawCommand::FillRoundedRect(rounded, color) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush=@core.Brush::solid(color),
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              size~,
            )
          @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush=@core.Brush::solid(color),
              mode=visual_mode_stroke,
              stroke_width=width,
              blur_radius=0.0,
              size~,
            )
          @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush~,
              mode=visual_mode_fill,
              stroke_width=0.0,
              blur_radius=0.0,
              size~,
            )
          @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
            append_visual_item(
              visual_vertices,
              items,
              rounded.rect,
              radius=rounded.radius,
              brush~,
              mode=visual_mode_stroke,
              stroke_width=width,
              blur_radius=0.0,
              size~,
            )
          @core.DrawCommand::DrawShadow(shadow) =>
            append_shadow_item(visual_vertices, items, shadow, size)
          @core.DrawCommand::DrawText(run) => {
            let start = text_vertices.length()
            let result = build_native_text_run(cache, atlas, run, size)
            for vertex in result.vertices {
              text_vertices.push(vertex)
            }
            let count = text_vertices.length() - start
            if count > 0 {
              items.push(NativeDrawItem::NativeText(start, count))
            }
            full = result.atlas_full
          }
          @core.DrawCommand::DrawImage(_)
          | @core.DrawCommand::PushClip(_)
          | @core.DrawCommand::PopClip
          | @core.DrawCommand::PushTransform(_)
          | @core.DrawCommand::PopTransform
          | @core.DrawCommand::PushOpacity(_)
          | @core.DrawCommand::PopOpacity => ()
        }
      }
    }
    if !full {
      return {
        visual_vertices,
        text_vertices,
        items,
        atlas_dirty: was_dirty || atlas.dirty,
      }
    }
    atlas.clear()
    if attempt == 1 {
      return {
        visual_vertices: [],
        text_vertices: [],
        items: [],
        atlas_dirty: true,
      }
    }
  }
  {
    visual_vertices: [],
    text_vertices: [],
    items: [],
    atlas_dirty: atlas.dirty,
  }
}

///|
fn append_visual_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  rect : @core.Rect,
  radius~ : Double,
  brush~ : @core.Brush,
  mode~ : Double,
  stroke_width~ : Double,
  blur_radius~ : Double,
  size~ : @core.Size,
) -> Unit {
  if rect.size.width <= 0.0 || rect.size.height <= 0.0 {
    return
  }
  if mode == visual_mode_stroke && stroke_width <= 0.0 {
    return
  }
  let start = vertices.length()
  append_visual_quad(
    vertices,
    rect,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
  items.push(NativeDrawItem::NativeVisual(start, vertices.length() - start))
}

///|
fn append_shadow_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  shadow : @core.ShadowSpec,
  size : @core.Size,
) -> Unit {
  let blur = shadow.blur_radius.max(0.0)
  let spread = shadow.spread.max(0.0)
  let grow = blur * 2.0 + spread
  let rect = @core.Rect::new(
    x=shadow.rect.rect.origin.x + shadow.offset.x - grow,
    y=shadow.rect.rect.origin.y + shadow.offset.y - grow,
    width=shadow.rect.rect.size.width + grow * 2.0,
    height=shadow.rect.rect.size.height + grow * 2.0,
  )
  append_visual_item(
    vertices,
    items,
    rect,
    radius=shadow.rect.radius + grow,
    brush=@core.Brush::solid(shadow.color),
    mode=visual_mode_shadow,
    stroke_width=0.0,
    blur_radius=blur,
    size~,
  )
}

///|
fn append_visual_quad(
  vertices : Array[VisualVertex],
  rect : @core.Rect,
  radius~ : Double,
  brush~ : @core.Brush,
  mode~ : Double,
  stroke_width~ : Double,
  blur_radius~ : Double,
  size~ : @core.Size,
) -> Unit {
  let x0 = rect.origin.x
  let y0 = rect.origin.y
  let x1 = rect.origin.x + rect.size.width
  let y1 = rect.origin.y + rect.size.height
  push_visual_vertex(
    vertices,
    rect,
    x0,
    y0,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x0,
    y1,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x1,
    y1,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x0,
    y0,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x1,
    y1,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
  push_visual_vertex(
    vertices,
    rect,
    x1,
    y0,
    radius~,
    brush~,
    mode~,
    stroke_width~,
    blur_radius~,
    size~,
  )
}

///|
fn push_visual_vertex(
  vertices : Array[VisualVertex],
  rect : @core.Rect,
  x : Double,
  y : Double,
  radius~ : Double,
  brush~ : @core.Brush,
  mode~ : Double,
  stroke_width~ : Double,
  blur_radius~ : Double,
  size~ : @core.Size,
) -> Unit {
  let gradient = visual_gradient(brush)
  vertices.push({
    x: visual_pixel_x_to_ndc(x, size.width),
    y: visual_pixel_y_to_ndc(y, size.height),
    local_x: x - rect.origin.x,
    local_y: y - rect.origin.y,
    width: rect.size.width,
    height: rect.size.height,
    radius: radius.min(rect.size.width.min(rect.size.height) / 2.0).max(0.0),
    mode,
    stroke_width,
    blur_radius,
    start_x: gradient.start.x - rect.origin.x,
    start_y: gradient.start.y - rect.origin.y,
    end_x: gradient.end.x - rect.origin.x,
    end_y: gradient.end.y - rect.origin.y,
    r0: gradient.start_color.r,
    g0: gradient.start_color.g,
    b0: gradient.start_color.b,
    a0: gradient.start_color.a,
    r1: gradient.end_color.r,
    g1: gradient.end_color.g,
    b1: gradient.end_color.b,
    a1: gradient.end_color.a,
  })
}

///|
fn visual_gradient(brush : @core.Brush) -> @core.LinearGradientSpec {
  match brush {
    @core.Brush::Solid(color) =>
      @core.LinearGradientSpec::new(
        start=@core.Point::new(x=0.0, y=0.0),
        end=@core.Point::new(x=1.0, y=0.0),
        start_color=color,
        end_color=color,
      )
    @core.Brush::LinearGradient(gradient) => gradient
  }
}

///|
fn visual_vertices_to_bytes(vertices : Array[VisualVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_visual_f32le(out, vertex.x)
    push_visual_f32le(out, vertex.y)
    push_visual_f32le(out, vertex.local_x)
    push_visual_f32le(out, vertex.local_y)
    push_visual_f32le(out, vertex.width)
    push_visual_f32le(out, vertex.height)
    push_visual_f32le(out, vertex.radius)
    push_visual_f32le(out, vertex.mode)
    push_visual_f32le(out, vertex.stroke_width)
    push_visual_f32le(out, vertex.blur_radius)
    push_visual_f32le(out, vertex.start_x)
    push_visual_f32le(out, vertex.start_y)
    push_visual_f32le(out, vertex.end_x)
    push_visual_f32le(out, vertex.end_y)
    push_visual_f32le(out, vertex.r0)
    push_visual_f32le(out, vertex.g0)
    push_visual_f32le(out, vertex.b0)
    push_visual_f32le(out, vertex.a0)
    push_visual_f32le(out, vertex.r1)
    push_visual_f32le(out, vertex.g1)
    push_visual_f32le(out, vertex.b1)
    push_visual_f32le(out, vertex.a1)
  }
  Bytes::from_array(out)
}

///|
fn push_visual_f32le(out : Array[Byte], value : Double) -> Unit {
  let bits : UInt = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
fn visual_pixel_x_to_ndc(x : Double, width : Double) -> Double {
  if width <= 0.0 {
    -1.0
  } else {
    x / width * 2.0 - 1.0
  }
}

///|
fn visual_pixel_y_to_ndc(y : Double, height : Double) -> Double {
  if height <= 0.0 {
    1.0
  } else {
    1.0 - y / height * 2.0
  }
}

///|
let visual_mode_fill : Double = 0.0

///|
let visual_mode_stroke : Double = 1.0

///|
let visual_mode_shadow : Double = 2.0

///|
let visual_vertex_stride : UInt64 = 88UL

///|
fn visual_shader_wgsl() -> String {
  let shader =
    #|struct VSOut {
    #|  @builtin(position) pos: vec4<f32>,
    #|  @location(0) local: vec2<f32>,
    #|  @location(1) size_radius_mode_stroke: vec4<f32>,
    #|  @location(2) blur_start: vec4<f32>,
    #|  @location(3) end: vec2<f32>,
    #|  @location(4) color0: vec4<f32>,
    #|  @location(5) color1: vec4<f32>,
    #|};
    #|
    #|@vertex
    #|fn vs_main(
    #|  @location(0) pos: vec2<f32>,
    #|  @location(1) local: vec2<f32>,
    #|  @location(2) size_radius_mode_stroke: vec4<f32>,
    #|  @location(3) blur_start: vec4<f32>,
    #|  @location(4) end: vec2<f32>,
    #|  @location(5) color0: vec4<f32>,
    #|  @location(6) color1: vec4<f32>,
    #|) -> VSOut {
    #|  var out: VSOut;
    #|  out.pos = vec4<f32>(pos, 0.0, 1.0);
    #|  out.local = local;
    #|  out.size_radius_mode_stroke = size_radius_mode_stroke;
    #|  out.blur_start = blur_start;
    #|  out.end = end;
    #|  out.color0 = color0;
    #|  out.color1 = color1;
    #|  return out;
    #|}
    #|
    #|fn rounded_box_sdf(p: vec2<f32>, half_size: vec2<f32>, radius: f32) -> f32 {
    #|  let r = min(radius, min(half_size.x, half_size.y));
    #|  let q = abs(p) - (half_size - vec2<f32>(r, r));
    #|  return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
    #|}
    #|
    #|fn gradient_color(local: vec2<f32>, start: vec2<f32>, end: vec2<f32>, c0: vec4<f32>, c1: vec4<f32>) -> vec4<f32> {
    #|  let axis = end - start;
    #|  let denom = max(dot(axis, axis), 0.0001);
    #|  let t = clamp(dot(local - start, axis) / denom, 0.0, 1.0);
    #|  return mix(c0, c1, t);
    #|}
    #|
    #|@fragment
    #|fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    #|  let width = in.size_radius_mode_stroke.x;
    #|  let height = in.size_radius_mode_stroke.y;
    #|  let radius = in.size_radius_mode_stroke.z;
    #|  let mode = in.size_radius_mode_stroke.w;
    #|  let stroke_width = in.blur_start.x;
    #|  let blur_radius = in.blur_start.y;
    #|  let start = in.blur_start.zw;
    #|  let end = in.end;
    #|  let center = vec2<f32>(width * 0.5, height * 0.5);
    #|  let half_size = center;
    #|  let dist = rounded_box_sdf(in.local - center, half_size, radius);
    #|  var alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
    #|  if mode > 1.5 {
    #|    let spread = max(blur_radius, 1.0);
    #|    alpha = 1.0 - smoothstep(-spread, spread, dist);
    #|    alpha = alpha * alpha * in.color0.a;
    #|    return vec4<f32>(in.color0.rgb, alpha);
    #|  }
    #|  if mode > 0.5 {
    #|    let inner_radius = max(radius - stroke_width, 0.0);
    #|    let inner_half = max(half_size - vec2<f32>(stroke_width, stroke_width), vec2<f32>(0.0, 0.0));
    #|    let inner_dist = rounded_box_sdf(in.local - center, inner_half, inner_radius);
    #|    let inner_alpha = 1.0 - smoothstep(-0.5, 0.5, inner_dist);
    #|    alpha = max(alpha - inner_alpha, 0.0);
    #|  }
    #|  let color = gradient_color(in.local, start, end, in.color0, in.color1);
    #|  return vec4<f32>(color.rgb, color.a * alpha);
    #|}
    #|
  shader
}
