///|
/// The Metal frame's wire format: every number the host reads back out of a
/// frame buffer, and the code values the MSL source interprets.
///
/// One 76-byte vertex (19 float32), 9 int32 per item, 36 floats per shape
/// record, 11 words per layer record, all little-endian and all written here —
/// `metal_renderer.mm` reads the same layout, so the two files are one contract
/// and a constant that changes in only one of them is a mis-draw, not a
/// compile error. That is why the mode, mask, filter-kind, shader-effect and
/// blend codes are named constants instead of literals at each call site.
///
/// The brush payload lives here too. It is the one place where a colour is
/// flattened for the shader: a solid brush becomes a degenerate linear gradient
/// whose endpoints share a colour, and a box's gradient endpoints move into the
/// space the box SDF measures itself from, because that space is not the space a
/// path mesh carries.

///|
let metal_vertex_bytes : Int32 = 76

///|
/// Fragment modes, matching `moui_wgpu_renderer/native_visual_shader.mbt` so the
/// two diagnostic renderers agree on what each shape means.
let metal_mode_fill : Double = 0.0

///|
let metal_mode_stroke : Double = 1.0

///|
let metal_mode_shadow : Double = 2.0

///|
let metal_mode_path : Double = 3.0

///|
let metal_mode_composite : Double = 4.0

///|
/// Brush kinds as the fragment shader reads them: a linear gradient runs along
/// `start`→`end`, a radial one reads `start` as its centre and `end.x` as a
/// radius rather than a second point.
let metal_brush_linear : Double = 0.0

///|
let metal_brush_radial : Double = 1.0

///|
/// Layer mask kinds as the composite shader reads them.
let metal_mask_none : Double = 0.0

///|
let metal_mask_rounded : Double = 1.0

///|
/// Filter kinds as the composite shader reads them; `metal_blend_code` and these
/// share the numbering of `moui_wgpu_renderer/native_visual_advanced.mbt`.
let metal_filter_none : Double = 0.0

///|
let metal_filter_blur : Double = 1.0

///|
let metal_filter_saturate : Double = 2.0

///|
let metal_filter_brightness : Double = 3.0

///|
let metal_filter_contrast : Double = 4.0

///|
let metal_filter_matrix : Double = 5.0

///|
/// This route's own separable blur stages. `moui_wgpu_renderer` numbers no stage
/// kinds -- it convolves in one pass -- so these extend the shared numbering above
/// rather than sharing it: the horizontal pass writes the intermediate target and
/// the vertical pass is what the enclosing composite reads.
let metal_filter_blur_x : Double = 6.0

///|
let metal_filter_blur_y : Double = 7.0

///|
/// Shader-effect kinds the visual fragment draws per fragment, sharing the
/// numbering of `moui_wgpu_renderer/native_shader_kind`. `metal_effect_none` is
/// "no effect": the item is painted with its brush as usual, which is what an
/// effect name this route has no formulation for falls back to.
let metal_effect_none : Double = 0.0

///|
let metal_effect_checker : Double = 1.0

///|
let metal_effect_solid : Double = 2.0

///|
let metal_effect_gradient_debug : Double = 3.0

///|
let metal_effect_vignette : Double = 4.0

///|
/// Blend modes this route can express as a fixed-function Metal blend state.
/// `@core.Overlay` is not: it needs a snapshot of the backdrop, which Metal
/// cannot sample while rendering into it, so it is counted, not approximated.
let metal_blend_source_over : Int32 = 0

///|
let metal_blend_multiply : Int32 = 1

///|
let metal_blend_screen : Int32 = 2

///|
let metal_blend_darken : Int32 = 4

///|
let metal_blend_lighten : Int32 = 5

///|
priv struct MetalBrushPayload {
  kind : Double
  start : @core.Point
  end : @core.Point
  color0 : @core.Color
  color1 : @core.Color
}

///|
/// The per-item parameter blob as built by the CPU side.
priv struct MetalShapePayload {
  width : Double
  height : Double
  radius : Double
  mode : Double
  stroke_width : Double
  blur_radius : Double
  effect_kind : Double
  effect_amount : Double
  layer_opacity : Double
  mask_kind : Double
  mask_radius : Double
  filter_kind : Double
  filter_amount : Double
  texel_x : Double
  texel_y : Double
  matrix : Array[Double]
}

///|
/// One offscreen pass. `device_*` is the padded device-pixel target the layer
/// clip resolves to; it is also the origin the pass transform and the composite
/// uv are derived from, so the layer content and the quad that draws it land on
/// the same texels.
priv struct MetalLayerRecord {
  device_x : Int32
  device_y : Int32
  device_width : Int32
  device_height : Int32
  child_first : Int32
  child_count : Int32
  blend_mode : Int32
  pass_scale_x : Double
  pass_scale_y : Double
  pass_offset_x : Double
  pass_offset_y : Double
}

///|
fn metal_box_shape(
  width : Double,
  height : Double,
  radius : Double,
  mode : Double,
  stroke_width~ : Double = 0.0,
  blur_radius~ : Double = 0.0,
  effect_kind~ : Double = metal_effect_none,
  effect_amount~ : Double = 0.0,
) -> MetalShapePayload {
  MetalShapePayload::{
    width,
    height,
    radius,
    mode,
    stroke_width,
    blur_radius,
    effect_kind,
    effect_amount,
    layer_opacity: 1.0,
    mask_kind: metal_mask_none,
    mask_radius: 0.0,
    filter_kind: metal_filter_none,
    filter_amount: 0.0,
    texel_x: 0.0,
    texel_y: 0.0,
    matrix: metal_identity_color_matrix(),
  }
}

///|
fn metal_identity_color_matrix() -> Array[Double] {
  // Row-major with each row's translation last, because that is the order
  // `metal_color_matrix` copies an app's CSS values into and the order
  // `moui_matrix_filter` reads: `m[0..4]` is the red row, `m[15..19]` the alpha
  // row. The array `moui_wgpu_renderer` carries has the same numbers but means
  // something else there -- its shader indexes a `mat4x5f` by column -- so
  // copying it here made the "identity" map every channel onto red.
  [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
  ]
}

///|
fn metal_color_matrix(values : Array[Double]) -> Array[Double] {
  let matrix = metal_identity_color_matrix()
  let count = values.length().min(20)
  for index in 0..<count {
    matrix[index] = values[index]
  }
  matrix
}

///|
/// The filter payload the composite shader needs, flattened the same way the
/// WGPU route flattens it.
priv struct MetalFilterPayload {
  kind : Double
  amount : Double
  matrix : Array[Double]
}

///|
fn metal_filter_payload(filter : @core.FilterEffect) -> MetalFilterPayload {
  match filter {
    @core.FilterEffect::Blur(radius) =>
      MetalFilterPayload::{
        kind: metal_filter_blur,
        amount: radius.max(0.0),
        matrix: metal_identity_color_matrix(),
      }
    @core.FilterEffect::Saturate(amount) =>
      MetalFilterPayload::{
        kind: metal_filter_saturate,
        amount,
        matrix: metal_identity_color_matrix(),
      }
    Brightness(amount) =>
      MetalFilterPayload::{
        kind: metal_filter_brightness,
        amount,
        matrix: metal_identity_color_matrix(),
      }
    Contrast(amount) =>
      MetalFilterPayload::{
        kind: metal_filter_contrast,
        amount,
        matrix: metal_identity_color_matrix(),
      }
    ColorMatrix(values) =>
      MetalFilterPayload::{
        kind: metal_filter_matrix,
        amount: 1.0,
        matrix: metal_color_matrix(values),
      }
  }
}

///|
fn metal_unknown_filter_payload() -> MetalFilterPayload {
  MetalFilterPayload::{
    kind: metal_filter_none,
    amount: 0.0,
    matrix: metal_identity_color_matrix(),
  }
}

///|
/// The four names `builtin_shader_names()` declares, mapped to the codes the
/// visual fragment reads. A name outside that list is `metal_effect_none`: the
/// item then paints the brush the spec carries as its fallback, which is the
/// degradation the spec was written to allow.
fn metal_shader_effect_kind(name : String) -> Double {
  match name {
    "checker" => metal_effect_checker
    "solid" => metal_effect_solid
    "linear-gradient-debug" => metal_effect_gradient_debug
    "vignette" => metal_effect_vignette
    _ => metal_effect_none
  }
}

///|
/// The one uniform the builtins read, defaulted per effect the way the mainline
/// routes default it — 8 cells for a checker, 0.8 of the frame radius for a
/// vignette. The per-effect floors (`max(amount, 1.0)`, `max(amount, 0.8)`) are
/// applied in the fragment, as `SkiaRasterRenderer::draw_checker_effect` and
/// `draw_vignette_effect` apply them.
fn metal_shader_effect_amount(
  kind : Double,
  uniforms : Array[Double],
) -> Double {
  match uniforms.get(0) {
    Some(value) => value
    None => if kind == metal_effect_vignette { 0.8 } else { 8.0 }
  }
}

///|
fn metal_blend_code(mode : @core.BlendMode) -> Int32 {
  match mode {
    @core.BlendMode::SourceOver => metal_blend_source_over
    Multiply => metal_blend_multiply
    Screen => metal_blend_screen
    Darken => metal_blend_darken
    Lighten => metal_blend_lighten
    Overlay => -1
  }
}

///|
/// A brush flattened onto the vertex payload. A solid brush becomes a
/// degenerate linear gradient with both endpoints the same colour, which the
/// shader's `mix` resolves to that colour for every fragment.
fn metal_brush_payload(
  brush : @core.Brush,
  opacity : Double,
) -> MetalBrushPayload {
  match brush {
    @core.Solid(color) =>
      MetalBrushPayload::{
        kind: metal_brush_linear,
        start: @core.Point::new(x=0.0, y=0.0),
        end: @core.Point::new(x=1.0, y=0.0),
        color0: color.multiply_alpha(opacity),
        color1: color.multiply_alpha(opacity),
      }
    @core.LinearGradient(gradient) =>
      MetalBrushPayload::{
        kind: metal_brush_linear,
        start: gradient.start,
        end: gradient.end,
        color0: gradient.start_color.multiply_alpha(opacity),
        color1: gradient.end_color.multiply_alpha(opacity),
      }
    @core.RadialGradient(gradient) =>
      MetalBrushPayload::{
        kind: metal_brush_radial,
        start: gradient.center,
        end: @core.Point::new(x=gradient.radius.max(1.0), y=0.0),
        color0: gradient.center_color.multiply_alpha(opacity),
        color1: gradient.edge_color.multiply_alpha(opacity),
      }
  }
}

///|
/// Move a payload into the space a box fragment measures itself from. The box
/// SDF reads `local` relative to the rect origin, while a path mesh carries
/// absolute positions, so a gradient on a rect that does not start at the
/// surface origin has to be shifted by that origin or its axis lands offset.
/// A radial `end.x` is a radius, not a point, so it stays put.
fn metal_box_brush(
  payload : MetalBrushPayload,
  origin : @core.Point,
) -> MetalBrushPayload {
  let end = if payload.kind == metal_brush_radial {
    payload.end
  } else {
    @core.Point::new(x=payload.end.x - origin.x, y=payload.end.y - origin.y)
  }
  MetalBrushPayload::{
    ..payload,
    start: @core.Point::new(
      x=payload.start.x - origin.x,
      y=payload.start.y - origin.y,
    ),
    end,
  }
}

///|
let metal_pipeline_visual : Int32 = 0

///|
let metal_pipeline_text : Int32 = 1

///|
let metal_pipeline_image : Int32 = 2

///|
/// A layer composite: `texture_key` names the offscreen pass slot to sample and
/// the shape blob carries blend, mask and filter parameters.
let metal_pipeline_composite : Int32 = 3

///|
/// Push one draw: an item plus its parameter blob. They travel together because
/// the host indexes `shapes[item]` in lockstep with `items`; an item skipped for
/// an empty scissor must not leave a shape behind, or every later item would read
/// the wrong radius.
fn push_metal_draw(
  geometry : MetalFrameGeometry,
  start : Int32,
  clip : @core.Rect,
  pipeline : Int32,
  shape : MetalShapePayload,
  texture_key~ : Int32 = 0,
) -> Unit {
  let count = geometry.vertex_count - start
  let (x, y, width, height) = metal_scissor(
    clip,
    geometry.size,
    geometry.scale_factor,
  )
  if width <= 0 || height <= 0 || count <= 0 {
    geometry.clipped_away_ops = geometry.clipped_away_ops + 1
    truncate_metal_vertices(geometry, start)
    return
  }
  push_metal_i32le(geometry.items, start)
  push_metal_i32le(geometry.items, count)
  push_metal_i32le(geometry.items, x)
  push_metal_i32le(geometry.items, y)
  push_metal_i32le(geometry.items, width)
  push_metal_i32le(geometry.items, height)
  push_metal_i32le(geometry.items, pipeline)
  push_metal_i32le(geometry.items, texture_key)
  push_metal_i32le(geometry.items, geometry.owner)
  push_metal_shape(geometry.shapes, shape)
  geometry.item_count = geometry.item_count + 1
  geometry.shape_count = geometry.shape_count + 1
}

///|
/// `MOUIMetalShape`: four floats per row, the visual fields first so the L1
/// shaders keep reading only the two rows they know.
fn push_metal_shape(out : Array[Byte], shape : MetalShapePayload) -> Unit {
  push_metal_f32le(out, shape.width)
  push_metal_f32le(out, shape.height)
  push_metal_f32le(out, shape.radius)
  push_metal_f32le(out, shape.mode)
  push_metal_f32le(out, shape.stroke_width)
  push_metal_f32le(out, shape.blur_radius)
  push_metal_f32le(out, shape.effect_kind)
  push_metal_f32le(out, shape.effect_amount)
  push_metal_f32le(out, shape.layer_opacity)
  push_metal_f32le(out, shape.mask_kind)
  push_metal_f32le(out, shape.mask_radius)
  push_metal_f32le(out, shape.filter_kind)
  push_metal_f32le(out, shape.filter_amount)
  push_metal_f32le(out, shape.texel_x)
  push_metal_f32le(out, shape.texel_y)
  push_metal_f32le(out, 0.0)
  for value in shape.matrix {
    push_metal_f32le(out, value)
  }
  for _ in shape.matrix.length()..<20 {
    push_metal_f32le(out, 0.0)
  }
}

///|
fn truncate_metal_vertices(geometry : MetalFrameGeometry, keep : Int32) -> Unit {
  let keep_bytes = keep * metal_vertex_bytes
  while geometry.vertices.length() > keep_bytes {
    ignore(geometry.vertices.pop())
  }
  geometry.vertex_count = keep
}

///|
fn push_metal_uv_vertex(
  geometry : MetalFrameGeometry,
  x : Double,
  y : Double,
  local_x : Double,
  local_y : Double,
  u : Double,
  v : Double,
  colour : @core.Color,
) -> Unit {
  push_metal_vertex(
    geometry,
    x,
    y,
    local_x,
    local_y,
    u,
    v,
    0.0,
    0.0,
    1.0,
    0.0,
    colour.r,
    colour.g,
    colour.b,
    colour.a,
    colour.r,
    colour.g,
    colour.b,
    colour.a,
    0.0,
  )
}

///|
fn push_metal_brush_vertex(
  geometry : MetalFrameGeometry,
  x : Double,
  y : Double,
  local_x : Double,
  local_y : Double,
  brush : MetalBrushPayload,
) -> Unit {
  push_metal_brush_vertex_uv(geometry, x, y, local_x, local_y, 0.0, 0.0, brush)
}

///|
fn push_metal_brush_vertex_uv(
  geometry : MetalFrameGeometry,
  x : Double,
  y : Double,
  local_x : Double,
  local_y : Double,
  u : Double,
  v : Double,
  brush : MetalBrushPayload,
) -> Unit {
  push_metal_vertex(
    geometry,
    x,
    y,
    local_x,
    local_y,
    u,
    v,
    brush.start.x,
    brush.start.y,
    brush.end.x,
    brush.end.y,
    brush.color0.r,
    brush.color0.g,
    brush.color0.b,
    brush.color0.a,
    brush.color1.r,
    brush.color1.g,
    brush.color1.b,
    brush.color1.a,
    brush.kind,
  )
}

///|
/// One 76-byte vertex: clip-space position, shape-local point, atlas uv,
/// gradient endpoints, the two brush colours and the brush kind. Colours ride
/// per vertex rather than per item because the shared path mesh mixes brushes.
fn push_metal_vertex(
  geometry : MetalFrameGeometry,
  x : Double,
  y : Double,
  local_x : Double,
  local_y : Double,
  u : Double,
  v : Double,
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
  red0 : Double,
  green0 : Double,
  blue0 : Double,
  alpha0 : Double,
  red1 : Double,
  green1 : Double,
  blue1 : Double,
  alpha1 : Double,
  kind : Double,
) -> Unit {
  push_metal_f32le(geometry.vertices, pixel_x_to_ndc(x, geometry.size.width))
  push_metal_f32le(geometry.vertices, pixel_y_to_ndc(y, geometry.size.height))
  push_metal_f32le(geometry.vertices, local_x)
  push_metal_f32le(geometry.vertices, local_y)
  push_metal_f32le(geometry.vertices, u)
  push_metal_f32le(geometry.vertices, v)
  push_metal_f32le(geometry.vertices, start_x)
  push_metal_f32le(geometry.vertices, start_y)
  push_metal_f32le(geometry.vertices, end_x)
  push_metal_f32le(geometry.vertices, end_y)
  push_metal_f32le(geometry.vertices, red0)
  push_metal_f32le(geometry.vertices, green0)
  push_metal_f32le(geometry.vertices, blue0)
  push_metal_f32le(geometry.vertices, alpha0)
  push_metal_f32le(geometry.vertices, red1)
  push_metal_f32le(geometry.vertices, green1)
  push_metal_f32le(geometry.vertices, blue1)
  push_metal_f32le(geometry.vertices, alpha1)
  push_metal_f32le(geometry.vertices, kind)
  geometry.vertex_count = geometry.vertex_count + 1
}

///|
fn metal_scissor(
  rect : @core.Rect,
  size : @core.Size,
  scale_factor : Double,
) -> (Int32, Int32, Int32, Int32) {
  let scale = if scale_factor > 0.0 { scale_factor } else { 1.0 }
  let limit_x = size.width.max(0.0)
  let limit_y = size.height.max(0.0)
  let x0 = rect.origin.x.max(0.0).min(limit_x)
  let y0 = rect.origin.y.max(0.0).min(limit_y)
  let x1 = (rect.origin.x + rect.size.width).max(0.0).min(limit_x)
  let y1 = (rect.origin.y + rect.size.height).max(0.0).min(limit_y)
  (
    (x0 * scale).floor().to_int(),
    (y0 * scale).floor().to_int(),
    ((x1 - x0) * scale).ceil().max(0.0).to_int(),
    ((y1 - y0) * scale).ceil().max(0.0).to_int(),
  )
}

///|
fn transform_metal_point(
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
/// The axis-aligned box a transform puts a rect into. Culling has to read this
/// rather than the source rect: an op whose transform carries it into a layer's
/// masked frame is inside that frame, and a route that tests the untransformed
/// rect drops it before a single vertex exists.
fn metal_transformed_bounds(
  rect : @core.Rect,
  transform : @core.Transform2D,
) -> @core.Rect {
  let corners = [
    transform_metal_point(transform, rect.origin.x, rect.origin.y),
    transform_metal_point(
      transform,
      rect.origin.x + rect.size.width,
      rect.origin.y,
    ),
    transform_metal_point(
      transform,
      rect.origin.x,
      rect.origin.y + rect.size.height,
    ),
    transform_metal_point(
      transform,
      rect.origin.x + rect.size.width,
      rect.origin.y + rect.size.height,
    ),
  ]
  let mut min_x = corners[0].x
  let mut min_y = corners[0].y
  let mut max_x = corners[0].x
  let mut max_y = corners[0].y
  for point in corners[1:] {
    min_x = min_x.min(point.x)
    min_y = min_y.min(point.y)
    max_x = max_x.max(point.x)
    max_y = max_y.max(point.y)
  }
  @core.Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y)
}

///|
fn multiply_metal_transform(
  outer : @core.Transform2D,
  inner : @core.Transform2D,
) -> @core.Transform2D {
  @core.Transform2D::{
    a: outer.a * inner.a + outer.c * inner.b,
    b: outer.b * inner.a + outer.d * inner.b,
    c: outer.a * inner.c + outer.c * inner.d,
    d: outer.b * inner.c + outer.d * inner.d,
    tx: outer.a * inner.tx + outer.c * inner.ty + outer.tx,
    ty: outer.b * inner.tx + outer.d * inner.ty + outer.ty,
  }
}

///|
fn clamp_metal_unit(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn empty_metal_rect() -> @core.Rect {
  @core.Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)
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
fn push_metal_f32le(out : Array[Byte], value : Double) -> Unit {
  let bits : UInt32 = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
fn push_metal_i32le(out : Array[Byte], value : Int32) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}
