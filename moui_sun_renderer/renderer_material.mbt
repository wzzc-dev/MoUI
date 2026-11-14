///|
/// Blur the pixels already painted (the backdrop) and redraw them inside the
/// material frame, then toning with the fallback brush. Rectangular clip only:
/// the rounded corner is a Skia/native-vibrancy refinement.
fn SunRasterRenderer::draw_backdrop_blur_effect(
  self : SunRasterRenderer,
  frame : @core.Rect,
  spec : @core.ShaderEffectSpec,
  opacity : Double,
) -> Unit {
  let blur = spec.uniforms.get(0).unwrap_or(16.0)
  let device = sun_transformed_rect_bounds(self.canvas.get_transform(), frame)
  let x = device.x.to_int()
  let y = device.y.to_int()
  let width = device.width.to_int()
  let height = device.height.to_int()
  if blur > 0.0 && width > 0 && height > 0 {
    let pixmap = self.canvas.get_pixmap()
    let blurred = sun_box_blur_pixmap(pixmap, blur)
    self.canvas.save()
    self.canvas.intersect_clip_rect(
      @sun_graphics.Rect::new(
        x=x.to_double(),
        y=y.to_double(),
        width=width.to_double(),
        height=height.to_double(),
      ),
    )
    self.canvas.draw_pixmap(blurred, 0, 0, @sun_graphics.Paint::new())
    ignore(self.canvas.restore())
  }
  self.canvas.fill_rect(
    device.x,
    device.y,
    device.width,
    device.height,
    sun_paint(spec.fallback.fallback_color(), opacity),
  )
}
