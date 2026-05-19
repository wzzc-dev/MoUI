///|
priv enum NativeDrawItem {
  NativeVisual(Int, Int, NativeScissor?)
  NativeText(Int, Int, NativeScissor?)
}

///|
priv struct NativeDrawPlan {
  visual_vertices : Array[VisualVertex]
  text_vertices : Array[TextVertex]
  items : Array[NativeDrawItem]
  atlas_dirty : Bool
}

///|
priv struct NativeScissor {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
priv struct NativePaintState {
  opacity : Double
  transform : @core.Transform2D
  clip : @core.Rect?
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
    let mut state = native_paint_state_default()
    let state_stack : Array[NativePaintState] = []
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
              state~,
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
              state~,
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
              state~,
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
              state~,
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
              state~,
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
              state~,
              size~,
            )
          @core.DrawCommand::DrawShadow(shadow) =>
            append_shadow_item(visual_vertices, items, shadow, state, size)
          @core.DrawCommand::DrawText(run) => {
            let start = text_vertices.length()
            let result = build_native_text_run(cache, atlas, run, state, size)
            for vertex in result.vertices {
              text_vertices.push(vertex)
            }
            let count = text_vertices.length() - start
            if count > 0 {
              items.push(
                NativeDrawItem::NativeText(
                  start,
                  count,
                  native_scissor_for_state(state, size),
                ),
              )
            }
            full = result.atlas_full
          }
          @core.DrawCommand::DrawImage(run) =>
            append_image_placeholder_item(
              visual_vertices, items, run, state, size,
            )
          @core.DrawCommand::PushClip(rect) => {
            state_stack.push(state)
            state = { ..state, clip: intersect_clip(state.clip, rect) }
          }
          @core.DrawCommand::PopClip =>
            state = pop_native_paint_state(state_stack, state)
          @core.DrawCommand::PushTransform(transform) => {
            state_stack.push(state)
            state = {
              ..state,
              transform: multiply_transform(state.transform, transform),
            }
          }
          @core.DrawCommand::PopTransform =>
            state = pop_native_paint_state(state_stack, state)
          @core.DrawCommand::PushOpacity(opacity) => {
            state_stack.push(state)
            state = { ..state, opacity: state.opacity * clamp_opacity(opacity) }
          }
          @core.DrawCommand::PopOpacity =>
            state = pop_native_paint_state(state_stack, state)
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
fn native_paint_state_default() -> NativePaintState {
  { opacity: 1.0, transform: @core.Transform2D::identity(), clip: None }
}

///|
fn pop_native_paint_state(
  stack : Array[NativePaintState],
  fallback : NativePaintState,
) -> NativePaintState {
  match stack.pop() {
    Some(state) => state
    None => fallback
  }
}

///|
fn clamp_opacity(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn multiply_transform(
  a : @core.Transform2D,
  b : @core.Transform2D,
) -> @core.Transform2D {
  {
    a: a.a * b.a + a.c * b.b,
    b: a.b * b.a + a.d * b.b,
    c: a.a * b.c + a.c * b.d,
    d: a.b * b.c + a.d * b.d,
    tx: a.a * b.tx + a.c * b.ty + a.tx,
    ty: a.b * b.tx + a.d * b.ty + a.ty,
  }
}

///|
fn transform_point(
  transform : @core.Transform2D,
  x : Double,
  y : Double,
) -> @core.Point {
  @core.Point::new(
    x=transform.a * x + transform.c * y + transform.tx,
    y=transform.b * x + transform.d * y + transform.ty,
  )
}

///|
fn transform_rect(
  rect : @core.Rect,
  transform : @core.Transform2D,
) -> @core.Rect {
  let p0 = transform_point(transform, rect.origin.x, rect.origin.y)
  let p1 = transform_point(
    transform,
    rect.origin.x + rect.size.width,
    rect.origin.y,
  )
  let p2 = transform_point(
    transform,
    rect.origin.x + rect.size.width,
    rect.origin.y + rect.size.height,
  )
  let p3 = transform_point(
    transform,
    rect.origin.x,
    rect.origin.y + rect.size.height,
  )
  let min_x = p0.x.min(p1.x).min(p2.x).min(p3.x)
  let max_x = p0.x.max(p1.x).max(p2.x).max(p3.x)
  let min_y = p0.y.min(p1.y).min(p2.y).min(p3.y)
  let max_y = p0.y.max(p1.y).max(p2.y).max(p3.y)
  @core.Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
}

///|
fn intersect_clip(current : @core.Rect?, next : @core.Rect) -> @core.Rect? {
  match current {
    Some(current) => rect_intersection(current, next)
    None => Some(next)
  }
}

///|
fn rect_intersection(a : @core.Rect, b : @core.Rect) -> @core.Rect? {
  let x0 = a.origin.x.max(b.origin.x)
  let y0 = a.origin.y.max(b.origin.y)
  let x1 = (a.origin.x + a.size.width).min(b.origin.x + b.size.width)
  let y1 = (a.origin.y + a.size.height).min(b.origin.y + b.size.height)
  if x1 <= x0 || y1 <= y0 {
    None
  } else {
    Some(@core.Rect::new(x=x0, y=y0, width=x1 - x0, height=y1 - y0))
  }
}

///|
fn native_scissor_for_state(
  state : NativePaintState,
  size : @core.Size,
) -> NativeScissor? {
  match state.clip {
    Some(clip) =>
      Some(native_scissor_for_rect(transform_rect(clip, state.transform), size))
    None => None
  }
}

///|
fn native_scissor_for_rect(
  rect : @core.Rect,
  size : @core.Size,
) -> NativeScissor {
  let x0 = rect.origin.x.max(0.0).min(size.width.max(0.0))
  let y0 = rect.origin.y.max(0.0).min(size.height.max(0.0))
  let x1 = (rect.origin.x + rect.size.width).max(0.0).min(size.width.max(0.0))
  let y1 = (rect.origin.y + rect.size.height).max(0.0).min(size.height.max(0.0))
  {
    x: x0.floor().to_int(),
    y: y0.floor().to_int(),
    width: (x1 - x0).ceil().max(0.0).to_int(),
    height: (y1 - y0).ceil().max(0.0).to_int(),
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
  state~ : NativePaintState,
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
    state~,
    size~,
  )
  items.push(
    NativeDrawItem::NativeVisual(
      start,
      vertices.length() - start,
      native_scissor_for_state(state, size),
    ),
  )
}

///|
fn append_shadow_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  shadow : @core.ShadowSpec,
  state : NativePaintState,
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
    state~,
    size~,
  )
}

///|
fn append_image_placeholder_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  run : @core.ImageRun,
  state : NativePaintState,
  size : @core.Size,
) -> Unit {
  append_visual_item(
    vertices,
    items,
    run.frame,
    radius=0.0,
    brush=image_placeholder_brush(run),
    mode=visual_mode_fill,
    stroke_width=0.0,
    blur_radius=0.0,
    state~,
    size~,
  )
}

///|
fn image_placeholder_brush(run : @core.ImageRun) -> @core.Brush {
  @core.Brush::linear_gradient(
    start=run.frame.origin,
    end=@core.Point::new(
      x=run.frame.origin.x + run.frame.size.width,
      y=run.frame.origin.y + run.frame.size.height,
    ),
    start_color=@core.Color::rgba(r=0.72, g=0.78, b=0.86, a=run.opacity),
    end_color=@core.Color::rgba(r=0.42, g=0.50, b=0.62, a=run.opacity),
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
  state~ : NativePaintState,
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
    state~,
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
    state~,
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
    state~,
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
    state~,
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
    state~,
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
    state~,
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
  state~ : NativePaintState,
  size~ : @core.Size,
) -> Unit {
  let gradient = visual_gradient(brush)
  let transformed = transform_point(state.transform, x, y)
  vertices.push({
    x: visual_pixel_x_to_ndc(transformed.x, size.width),
    y: visual_pixel_y_to_ndc(transformed.y, size.height),
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
    a0: gradient.start_color.a * state.opacity,
    r1: gradient.end_color.r,
    g1: gradient.end_color.g,
    b1: gradient.end_color.b,
    a1: gradient.end_color.a * state.opacity,
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
