///|
fn sun_linear_gradient_debug_paint(
  frame : @core.Rect,
  fallback : @core.Brush,
  opacity : Double,
) -> @sun_graphics.Paint {
  let (start_color, end_color) = sun_shader_effect_colors(fallback)
  sun_brush_paint(
    @core.Brush::linear_gradient(
      start=frame.origin,
      end=@core.Point::new(
        x=frame.origin.x + frame.size.width,
        y=frame.origin.y,
      ),
      start_color~,
      end_color~,
    ),
    opacity,
  )
}

///|
fn SunRasterRenderer::fill_shader_effect_frame(
  self : SunRasterRenderer,
  frame : @core.Rect,
  fallback : @core.Brush,
  opacity : Double,
) -> Unit {
  self.canvas.fill_rect(
    frame.origin.x,
    frame.origin.y,
    frame.size.width,
    frame.size.height,
    sun_brush_paint(fallback, opacity),
  )
}

///|
fn SunRasterRenderer::draw_checker_effect(
  self : SunRasterRenderer,
  frame : @core.Rect,
  fallback : @core.Brush,
  uniforms : Array[Double],
  opacity : Double,
) -> Unit {
  let amount = match uniforms.get(0) {
    Some(value) => value.max(1.0)
    None => 8.0
  }
  let (color_a, color_b) = sun_shader_effect_colors(fallback)
  let cell = (frame.size.width.min(frame.size.height) / amount).max(1.0)
  let columns = (frame.size.width / cell).ceil().to_int().max(1)
  let rows = (frame.size.height / cell).ceil().to_int().max(1)
  let paint = @sun_graphics.Paint::new().set_opacity(opacity)
  for row in 0..<rows {
    for column in 0..<columns {
      ignore(
        paint.set_color(
          sun_color(if (row + column) % 2 == 0 { color_a } else { color_b }),
        ),
      )
      let x = frame.origin.x + column.to_double() * cell
      let y = frame.origin.y + row.to_double() * cell
      self.canvas.fill_rect(
        x,
        y,
        cell.min(frame.origin.x + frame.size.width - x),
        cell.min(frame.origin.y + frame.size.height - y),
        paint,
      )
    }
  }
}

///|
fn SunRasterRenderer::draw_vignette_effect(
  self : SunRasterRenderer,
  frame : @core.Rect,
  fallback : @core.Brush,
  uniforms : Array[Double],
  opacity : Double,
) -> Unit {
  let (color, _) = sun_shader_effect_colors(fallback)
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  let radius = frame.size.width.max(frame.size.height) /
    2.0 *
    sun_vignette_radius_scale(uniforms)
  let outer_color = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=color.a)
  self.canvas.fill_rect(
    frame.origin.x,
    frame.origin.y,
    frame.size.width,
    frame.size.height,
    sun_brush_paint(
      @core.Brush::radial_gradient(
        center~,
        radius~,
        center_color=color,
        edge_color=outer_color,
      ),
      opacity,
    ),
  )
}

///|
fn sun_vignette_radius_scale(uniforms : Array[Double]) -> Double {
  match uniforms.get(0) {
    Some(amount) => amount.max(0.8)
    None => 0.8
  }
}

///|
fn sun_shader_effect_colors(
  fallback : @core.Brush,
) -> (@core.Color, @core.Color) {
  match fallback {
    @core.Brush::Solid(color) => (color, color)
    @core.Brush::LinearGradient(gradient) =>
      (gradient.start_color, gradient.end_color)
    @core.Brush::RadialGradient(gradient) =>
      (gradient.center_color, gradient.edge_color)
  }
}
