///|
fn SunRasterRenderer::draw_shadow(
  self : SunRasterRenderer,
  shadow : @core.ShadowSpec,
  opacity : Double,
) -> Unit {
  let rect = shadow.rect.rect
  let corner_radius = shadow.rect.radius.max(0.0)
  let base_color = shadow.color
  let spread = shadow.spread.max(0.0)
  let blur_r = shadow.blur_radius.max(0.0)
  guard opacity > 0.0 else { return }
  guard base_color.a > 0.0 else { return }
  // The offscreen shadow pixmap is rasterised in device pixels, so spread and
  // size scale by the surface scale factor; otherwise a DPR=2 surface renders
  // a shadow half the intended size. The blur kernel stays at `blur_radius`
  // device pixels to match the Skia mask-filter sigma, which is not
  // CTM-scaled; three box passes give a support of 3 * radius per side.
  let transform = self.canvas.get_transform()
  let scale = self.metrics.scale_factor
  let blur_px = blur_r
  let spread_dev = spread * scale
  let pad = (blur_px * 3.0).ceil().to_int().max(1)
  let inner_w = rect.size.width * scale + spread_dev * 2.0
  let inner_h = rect.size.height * scale + spread_dev * 2.0
  let shadow_w = inner_w.ceil().to_int().max(1) + pad * 2
  let shadow_h = inner_h.ceil().to_int().max(1) + pad * 2
  let shadow_pixmap = @sun_graphics.Pixmap::new(shadow_w, shadow_h)
  let shadow_color = @sun_graphics.Color::new(
    r=sun_channel(base_color.r),
    g=sun_channel(base_color.g),
    b=sun_channel(base_color.b),
    a=sun_channel(sun_clamp_unit(base_color.a * opacity)),
  )
  let cx = pad.to_double() + inner_w * 0.5
  let cy = pad.to_double() + inner_h * 0.5
  let hx = inner_w * 0.5
  let hy = inner_h * 0.5
  let scaled_radius = (corner_radius * scale).min(hx).min(hy)
  for sy in 0..<shadow_h {
    for sx in 0..<shadow_w {
      let px = sx.to_double() + 0.5
      let py = sy.to_double() + 0.5
      let qx = (px - cx).abs() - (hx - scaled_radius)
      let qy = (py - cy).abs() - (hy - scaled_radius)
      let outside_dist = if qx > 0.0 && qy > 0.0 {
        (qx * qx + qy * qy).sqrt()
      } else if qx > 0.0 {
        qx
      } else if qy > 0.0 {
        qy
      } else {
        0.0
      }
      let d = outside_dist - scaled_radius
      if d < 0.5 {
        shadow_pixmap.set_pixel(sx, sy, shadow_color)
      }
    }
  }
  let blurred = if blur_r > 0.5 {
    sun_box_blur_pixmap(shadow_pixmap, blur_px)
  } else {
    shadow_pixmap
  }
  // Device-space blit: the shadow pixmap is rasterised in device pixels, so its
  // placement comes from the canvas transform instead of raw logical offsets.
  let (device_x, device_y) = transform.apply(
    rect.origin.x + shadow.offset.x - spread,
    rect.origin.y + shadow.offset.y - spread,
  )
  let draw_x = device_x.floor().to_int() - pad
  let draw_y = device_y.floor().to_int() - pad
  self.canvas.draw_pixmap(
    blurred,
    draw_x,
    draw_y,
    @sun_graphics.Paint::new().set_opacity(1.0),
  )
}
