///|
fn advanced_layer_vertices(
  size : @core.Size,
  layer : NativeLayerRun,
) -> Array[AdvancedVertex] {
  let frame = match layer.mask {
    Some(mask) => mask.rect
    None => @core.Rect::new(x=0.0, y=0.0, width=size.width, height=size.height)
  }
  let mask_radius = match layer.mask {
    Some(mask) => if mask.rounded { mask.radius } else { 0.0 }
    None => 0.0
  }
  let mask_kind = match layer.mask {
    Some(mask) => if mask.rounded { 1.0 } else { 0.0 }
    None => 0.0
  }
  advanced_rect_vertices(
    size,
    frame,
    opacity=layer.opacity,
    blend_mode=layer.blend_mode,
    shader_kind=0.0,
    effect_amount=0.0,
    filter=layer.filter,
    color0=@core.Color::white(),
    color1=@core.Color::white(),
    uv_rect=Some(frame),
    mask_radius~,
    mask_kind~,
  )
}

///|
fn advanced_rect_vertices(
  size : @core.Size,
  rect : @core.Rect,
  opacity~ : Double,
  blend_mode~ : @core.BlendMode,
  shader_kind~ : Double,
  effect_amount~ : Double,
  filter~ : @core.FilterEffect?,
  color0~ : @core.Color,
  color1~ : @core.Color,
  uv_rect? : @core.Rect? = None,
  mask_radius? : Double = 0.0,
  mask_kind? : Double = 0.0,
  transform? : @core.Transform2D = @core.Transform2D::identity(),
) -> Array[AdvancedVertex] {
  let vertices : Array[AdvancedVertex] = []
  let x0 = rect.origin.x
  let y0 = rect.origin.y
  let x1 = rect.origin.x + rect.size.width
  let y1 = rect.origin.y + rect.size.height
  let uv0 = advanced_uv_for_point(size, uv_rect, x0, y0, 0.0, 0.0)
  let uv1 = advanced_uv_for_point(size, uv_rect, x0, y1, 0.0, 1.0)
  let uv2 = advanced_uv_for_point(size, uv_rect, x1, y1, 1.0, 1.0)
  let uv3 = advanced_uv_for_point(size, uv_rect, x1, y0, 1.0, 0.0)
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x0,
    y0,
    uv0.x,
    uv0.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
    transform~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x0,
    y1,
    uv1.x,
    uv1.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
    transform~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x1,
    y1,
    uv2.x,
    uv2.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
    transform~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x0,
    y0,
    uv0.x,
    uv0.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
    transform~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x1,
    y1,
    uv2.x,
    uv2.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
    transform~,
  )
  push_advanced_vertex(
    vertices,
    size,
    rect,
    x1,
    y0,
    uv3.x,
    uv3.y,
    opacity~,
    blend_mode~,
    shader_kind~,
    effect_amount~,
    filter~,
    color0~,
    color1~,
    mask_radius~,
    mask_kind~,
    transform~,
  )
  vertices
}

///|
fn advanced_uv_for_point(
  size : @core.Size,
  uv_rect : @core.Rect?,
  x : Double,
  y : Double,
  fallback_u : Double,
  fallback_v : Double,
) -> @core.Point {
  match uv_rect {
    Some(_) =>
      @core.Point::new(
        x=x / size.width.max(0.0001),
        y=y / size.height.max(0.0001),
      )
    None => @core.Point::new(x=fallback_u, y=fallback_v)
  }
}

///|
fn push_advanced_vertex(
  vertices : Array[AdvancedVertex],
  size : @core.Size,
  rect : @core.Rect,
  x : Double,
  y : Double,
  u : Double,
  v : Double,
  opacity~ : Double,
  blend_mode~ : @core.BlendMode,
  shader_kind~ : Double,
  effect_amount~ : Double,
  filter~ : @core.FilterEffect?,
  color0~ : @core.Color,
  color1~ : @core.Color,
  mask_radius~ : Double,
  mask_kind~ : Double,
  transform~ : @core.Transform2D,
) -> Unit {
  let transformed = transform_point(transform, x, y)
  let filter_payload = native_filter_payload(filter)
  vertices.push({
    x: visual_pixel_x_to_ndc(transformed.x, size.width),
    y: visual_pixel_y_to_ndc(transformed.y, size.height),
    u,
    v,
    opacity: clamp_opacity(opacity),
    blend_mode: native_blend_mode_code(blend_mode),
    shader_kind,
    effect_amount,
    local_x: (x - rect.origin.x) / rect.size.width.max(0.0001),
    local_y: (y - rect.origin.y) / rect.size.height.max(0.0001),
    filter_kind: filter_payload.kind,
    filter_amount: filter_payload.amount,
    r0: color0.r,
    g0: color0.g,
    b0: color0.b,
    a0: color0.a,
    r1: color1.r,
    g1: color1.g,
    b1: color1.b,
    a1: color1.a,
    matrix: filter_payload.matrix,
    rect_width: rect.size.width.max(0.0),
    rect_height: rect.size.height.max(0.0),
    mask_radius: mask_radius.max(0.0),
    mask_kind,
  })
}

///|
priv struct NativeFilterPayload {
  kind : Double
  amount : Double
  matrix : Array[Double]
}

///|
fn native_filter_payload(filter : @core.FilterEffect?) -> NativeFilterPayload {
  match filter {
    Some(@core.FilterEffect::Blur(radius)) =>
      {
        kind: 1.0,
        amount: radius.max(0.0),
        matrix: native_identity_color_matrix(),
      }
    Some(@core.FilterEffect::Saturate(amount)) =>
      { kind: 2.0, amount, matrix: native_identity_color_matrix() }
    Some(@core.FilterEffect::Brightness(amount)) =>
      { kind: 3.0, amount, matrix: native_identity_color_matrix() }
    Some(@core.FilterEffect::Contrast(amount)) =>
      { kind: 4.0, amount, matrix: native_identity_color_matrix() }
    Some(@core.FilterEffect::ColorMatrix(values)) =>
      { kind: 5.0, amount: 1.0, matrix: native_color_matrix(values) }
    None => { kind: 0.0, amount: 0.0, matrix: native_identity_color_matrix() }
  }
}

///|
fn native_identity_color_matrix() -> Array[Double] {
  [
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, 0.0, 0.0,
  ]
}

///|
fn native_color_matrix(values : Array[Double]) -> Array[Double] {
  let matrix = native_identity_color_matrix()
  let count = values.length().min(20)
  for index in 0..<count {
    matrix[index] = values[index]
  }
  matrix
}

///|
fn native_blend_mode_code(mode : @core.BlendMode) -> Double {
  match mode {
    @core.BlendMode::SourceOver => 0.0
    @core.BlendMode::Multiply => 1.0
    @core.BlendMode::Screen => 2.0
    @core.BlendMode::Overlay => 3.0
    @core.BlendMode::Darken => 4.0
    @core.BlendMode::Lighten => 5.0
  }
}

///|
fn native_shader_kind(name : String) -> Double {
  match name {
    "checker" => 1.0
    "solid" => 2.0
    "linear-gradient-debug" => 3.0
    "vignette" => 4.0
    _ => 5.0
  }
}

///|
fn native_shader_effect_amount(effect : NativeShaderEffectRun) -> Double {
  match effect.uniforms.get(0) {
    Some(value) => value
    None => 8.0
  }
}

///|
fn native_shader_effect_colors(
  effect : NativeShaderEffectRun,
) -> (@core.Color, @core.Color) {
  match effect.fallback {
    @core.Brush::Solid(color) => (color, color)
    @core.Brush::LinearGradient(gradient) =>
      (gradient.start_color, gradient.end_color)
    @core.Brush::RadialGradient(gradient) =>
      (gradient.center_color, gradient.edge_color)
  }
}
