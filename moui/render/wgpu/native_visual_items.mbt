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
  scale_factor~ : Double,
) -> Unit {
  if !native_paint_state_visible(state) {
    return
  }
  if rect.size.width <= 0.0 || rect.size.height <= 0.0 {
    return
  }
  if mode == visual_mode_stroke && stroke_width <= 0.0 {
    return
  }
  let scissor = native_scissor_for_state(state, size, scale_factor)
  if !native_scissor_visible(scissor) {
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
    NativeDrawItem::NativeVisual(start, vertices.length() - start, scissor),
  )
}

///|
fn append_shadow_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  shadow : @core.ShadowSpec,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
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
    scale_factor~,
  )
}

///|
fn append_image_item(
  vertices : Array[ImageVertex],
  items : Array[NativeDrawItem],
  run : @core.ImageRun,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> Unit {
  if !native_paint_state_visible(state) {
    return
  }
  if run.frame.size.width <= 0.0 || run.frame.size.height <= 0.0 {
    return
  }
  let scissor = native_scissor_for_state(state, size, scale_factor)
  if !native_scissor_visible(scissor) {
    return
  }
  let start = vertices.length()
  items.push(
    NativeDrawItem::NativeImage(start, vertices.length() - start, scissor, {
      source: run.source,
      frame: run.frame,
      opacity: clamp_opacity(run.opacity) * state.opacity,
      fit: run.fit,
      transform: state.transform,
    }),
  )
}

///|
fn append_path_item(
  vertices : Array[VisualVertex],
  items : Array[NativeDrawItem],
  path : @core.PathSpec,
  state : NativePaintState,
  size : @core.Size,
  scale_factor : Double,
) -> Unit {
  if !native_paint_state_visible(state) {
    return
  }
  let scissor = native_scissor_for_state(state, size, scale_factor)
  if !native_scissor_visible(scissor) {
    return
  }
  let mesh = @render.tessellate_path(path)
  let start = vertices.length()
  for vertex in mesh.vertices() {
    push_path_visual_vertex(vertices, vertex, state, size)
  }
  let count = vertices.length() - start
  if count > 0 {
    items.push(NativeDrawItem::NativeVisual(start, count, scissor))
  }
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
  let shader_brush_kind = if mode < visual_mode_shadow {
    visual_brush_kind(brush)
  } else {
    blur_radius
  }
  let start_x = visual_brush_start_x(brush, gradient, rect)
  let start_y = visual_brush_start_y(brush, gradient, rect)
  let end_x = visual_brush_end_x(brush, gradient, rect)
  let end_y = visual_brush_end_y(brush, gradient, rect)
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
    blur_radius: shader_brush_kind,
    start_x,
    start_y,
    end_x,
    end_y,
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
fn push_path_visual_vertex(
  vertices : Array[VisualVertex],
  vertex : @render.PathVertex,
  state : NativePaintState,
  size : @core.Size,
) -> Unit {
  let components = vertex.components()
  let x = components[0]
  let y = components[1]
  let transformed = transform_point(state.transform, x, y)
  vertices.push({
    x: visual_pixel_x_to_ndc(transformed.x, size.width),
    y: visual_pixel_y_to_ndc(transformed.y, size.height),
    local_x: x,
    local_y: y,
    width: 0.0,
    height: 0.0,
    radius: 0.0,
    mode: visual_mode_path,
    stroke_width: 0.0,
    blur_radius: components[2],
    start_x: components[3],
    start_y: components[4],
    end_x: components[5],
    end_y: components[6],
    r0: components[7],
    g0: components[8],
    b0: components[9],
    a0: components[10] * state.opacity,
    r1: components[11],
    g1: components[12],
    b1: components[13],
    a1: components[14] * state.opacity,
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
    @core.Brush::RadialGradient(gradient) =>
      @core.LinearGradientSpec::new(
        start=gradient.center,
        end=@core.Point::new(
          x=gradient.center.x + gradient.radius.max(1.0),
          y=gradient.center.y,
        ),
        start_color=gradient.center_color,
        end_color=gradient.edge_color,
      )
  }
}

///|
fn visual_brush_kind(brush : @core.Brush) -> Double {
  match brush {
    @core.Brush::RadialGradient(_) => 1.0
    _ => 0.0
  }
}

///|
fn visual_brush_start_x(
  brush : @core.Brush,
  gradient : @core.LinearGradientSpec,
  rect : @core.Rect,
) -> Double {
  match brush {
    @core.Brush::RadialGradient(radial) => radial.center.x - rect.origin.x
    _ => gradient.start.x - rect.origin.x
  }
}

///|
fn visual_brush_start_y(
  brush : @core.Brush,
  gradient : @core.LinearGradientSpec,
  rect : @core.Rect,
) -> Double {
  match brush {
    @core.Brush::RadialGradient(radial) => radial.center.y - rect.origin.y
    _ => gradient.start.y - rect.origin.y
  }
}

///|
fn visual_brush_end_x(
  brush : @core.Brush,
  gradient : @core.LinearGradientSpec,
  rect : @core.Rect,
) -> Double {
  match brush {
    @core.Brush::RadialGradient(radial) => radial.radius.max(1.0)
    _ => gradient.end.x - rect.origin.x
  }
}

///|
fn visual_brush_end_y(
  brush : @core.Brush,
  gradient : @core.LinearGradientSpec,
  rect : @core.Rect,
) -> Double {
  match brush {
    @core.Brush::RadialGradient(_) => 0.0
    _ => gradient.end.y - rect.origin.y
  }
}
