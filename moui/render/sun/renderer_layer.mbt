///|
priv struct SunLayerScope {
  spec : @core.LayerSpec
  transform : @sun_graphics.Transform
}

///|
fn SunRasterRenderer::push_transparent_offscreen_canvas(
  self : SunRasterRenderer,
) -> Unit {
  let parent_canvas = self.canvas
  self.canvas_stack.push(parent_canvas)
  let w = parent_canvas.get_pixmap().get_width()
  let h = parent_canvas.get_pixmap().get_height()
  let layer_canvas = @sun_graphics.Canvas::new(w, h)
  layer_canvas.clear(@sun_graphics.Color::new(r=0, g=0, b=0, a=0))
  layer_canvas.set_transform(parent_canvas.get_transform())
  match parent_canvas.get_clip_rect() {
    Some(rect) => layer_canvas.set_clip_rect(rect)
    None => ()
  }
  self.canvas = layer_canvas
}

///|
fn sun_transformed_rect_bounds(
  transform : @sun_graphics.Transform,
  rect : @core.Rect,
) -> @sun_graphics.Rect {
  let x = rect.origin.x
  let y = rect.origin.y
  let width = rect.size.width
  let height = rect.size.height
  let (x0, y0) = transform.apply(x, y)
  let (x1, y1) = transform.apply(x + width, y)
  let (x2, y2) = transform.apply(x, y + height)
  let (x3, y3) = transform.apply(x + width, y + height)
  let left = x0.min(x1).min(x2).min(x3)
  let top = y0.min(y1).min(y2).min(y3)
  let right = x0.max(x1).max(x2).max(x3)
  let bottom = y0.max(y1).max(y2).max(y3)
  let device_left = sun_floor_to_int(left).to_double()
  let device_top = sun_floor_to_int(top).to_double()
  let device_right = sun_ceil_to_int(right).to_double()
  let device_bottom = sun_ceil_to_int(bottom).to_double()
  @sun_graphics.Rect::new(
    x=device_left,
    y=device_top,
    width=(device_right - device_left).max(0.0),
    height=(device_bottom - device_top).max(0.0),
  )
}

///|
fn sun_floor_to_int(value : Double) -> Int {
  let truncated = value.to_int()
  if truncated.to_double() > value {
    truncated - 1
  } else {
    truncated
  }
}

///|
fn sun_ceil_to_int(value : Double) -> Int {
  -sun_floor_to_int(0.0 - value)
}

///|
fn SunRasterRenderer::composite_rounded_clip(
  self : SunRasterRenderer,
  layer_pixmap : @sun_graphics.Pixmap,
  rounded : @core.RoundedRect,
  transform : @sun_graphics.Transform,
  opacity : Double,
) -> Unit {
  let masked = sun_rounded_masked_pixmap(layer_pixmap, rounded, transform)
  self.canvas.draw_pixmap(
    masked,
    0,
    0,
    @sun_graphics.Paint::new().set_opacity(opacity),
  )
}

///|
fn SunRasterRenderer::composite_layer_pixmap(
  self : SunRasterRenderer,
  layer_pixmap : @sun_graphics.Pixmap,
  scope : SunLayerScope,
  opacity : Double,
  blend_mode : @sun_graphics.BlendMode,
) -> Unit {
  let spec = scope.spec
  let paint = @sun_graphics.Paint::new()
    .set_opacity(sun_clamp_unit(opacity * spec.opacity))
    .set_blend_mode(blend_mode)
  match spec.mask {
    @core.LayerMask::NoMask =>
      self.canvas.draw_pixmap(layer_pixmap, 0, 0, paint)
    @core.LayerMask::RectMask(rect) =>
      self.canvas.draw_pixmap(
        sun_rect_masked_pixmap(layer_pixmap, rect, scope.transform),
        0,
        0,
        paint,
      )
    @core.LayerMask::RoundedMask(rounded) =>
      self.canvas.draw_pixmap(
        sun_rounded_masked_pixmap(layer_pixmap, rounded, scope.transform),
        0,
        0,
        paint,
      )
  }
}

///|
fn sun_rounded_masked_pixmap(
  layer_pixmap : @sun_graphics.Pixmap,
  rounded : @core.RoundedRect,
  transform : @sun_graphics.Transform,
) -> @sun_graphics.Pixmap {
  sun_masked_pixmap(layer_pixmap, transform, (x, y) => {
    sun_rounded_mask_coverage(rounded, x, y)
  })
}

///|
fn sun_rect_masked_pixmap(
  layer_pixmap : @sun_graphics.Pixmap,
  rect : @core.Rect,
  transform : @sun_graphics.Transform,
) -> @sun_graphics.Pixmap {
  sun_masked_pixmap(layer_pixmap, transform, (x, y) => {
    if sun_rect_contains(rect, x, y) {
      1.0
    } else {
      0.0
    }
  })
}

///|
fn sun_masked_pixmap(
  layer_pixmap : @sun_graphics.Pixmap,
  transform : @sun_graphics.Transform,
  coverage_at : (Double, Double) -> Double,
) -> @sun_graphics.Pixmap {
  let masked = @sun_graphics.Pixmap::new(
    layer_pixmap.get_width(),
    layer_pixmap.get_height(),
  )
  let w = layer_pixmap.get_width()
  let h = layer_pixmap.get_height()
  match transform.inverse() {
    Some(inverse) =>
      for py in 0..<h {
        for px in 0..<w {
          let src = layer_pixmap.get_pixel(px, py)
          if src.a.to_int() > 0 {
            let (local_x, local_y) = inverse.apply(
              px.to_double() + 0.5,
              py.to_double() + 0.5,
            )
            let coverage = coverage_at(local_x, local_y).max(0.0).min(1.0)
            if coverage > 0.0 {
              let masked_alpha = sun_channel(
                src.a.to_int().to_double() / 255.0 * coverage,
              )
              if masked_alpha.to_int() > 0 {
                masked.set_pixel(px, py, src.with_alpha(masked_alpha))
              }
            }
          }
        }
      }
    None => ()
  }
  masked
}

///|
fn sun_rect_contains(rect : @core.Rect, x : Double, y : Double) -> Bool {
  rect.size.width > 0.0 &&
  rect.size.height > 0.0 &&
  x >= rect.origin.x &&
  x < rect.origin.x + rect.size.width &&
  y >= rect.origin.y &&
  y < rect.origin.y + rect.size.height
}

///|
fn sun_rounded_mask_coverage(
  rounded : @core.RoundedRect,
  x : Double,
  y : Double,
) -> Double {
  let rect = rounded.rect
  let radius = rounded.radius.max(0.0)
  let cx = rect.origin.x + rect.size.width * 0.5
  let cy = rect.origin.y + rect.size.height * 0.5
  let hx = rect.size.width * 0.5
  let hy = rect.size.height * 0.5
  let r = radius.min(hx).min(hy)
  let qx = (x - cx).abs() - (hx - r)
  let qy = (y - cy).abs() - (hy - r)
  let outside_dist = sun_rounded_outside_distance(qx, qy)
  let d = outside_dist - r
  (0.5 - d).max(0.0).min(1.0)
}

///|
fn sun_rounded_outside_distance(qx : Double, qy : Double) -> Double {
  if qx > 0.0 && qy > 0.0 {
    (qx * qx + qy * qy).sqrt()
  } else if qx > 0.0 {
    qx
  } else if qy > 0.0 {
    qy
  } else {
    0.0
  }
}
