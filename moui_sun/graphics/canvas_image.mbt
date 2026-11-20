///|
/// Draw a grayscale coverage mask with the given paint
pub fn Canvas::draw_mask(
  self : Canvas,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  mask : FixedArray[Byte],
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 && mask.length() >= width * height else {
    return
  }
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    x,
    y,
    x + width,
    y + height,
  )
  guard x_start < x_end && y_start < y_end else { return }
  // Mask compositing is the text path: build the sampler once for the whole
  // mask so a gradient fill pays one matrix inversion instead of one per glyph
  // pixel, and a solid fill samples a precomputed constant. Dirty bounds are
  // accumulated per row, matching the coverage path.
  let sampler = self.paint_sampler(paint)
  for py in y_start..<y_end {
    let mut dirty_start = x_end
    let mut dirty_end = x_start
    for px in x_start..<x_end {
      let mask_x = px - x
      let mask_y = py - y
      let coverage = mask[mask_y * width + mask_x].to_int()
      if coverage > 0 {
        let color = sampler.sample(px.to_double() + 0.5, py.to_double() + 0.5)
        let alpha = (color.a.to_int() * coverage + 127) / 255
        if blend_sampled_source_pixel(
            self.pixmap,
            px,
            py,
            color.with_alpha(clamp_byte(alpha)),
            paint.blend_mode,
          ) {
          dirty_start = dirty_start.min(px)
          dirty_end = dirty_end.max(px + 1)
        }
      }
    }
    if dirty_start < dirty_end {
      self.mark_dirty_bounds(dirty_start, py, dirty_end, py + 1)
    }
  }
}

///|
/// Draw a source rectangle from a grayscale coverage mask with the given paint.
pub fn Canvas::draw_mask_rect(
  self : Canvas,
  x : Int32,
  y : Int32,
  mask_width : Int32,
  mask_height : Int32,
  mask : FixedArray[Byte],
  src_rect : PixelRect,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard mask_width > 0 &&
    mask_height > 0 &&
    mask.length() >= mask_width * mask_height else {
    return
  }
  let mask_bounds = PixelRect::new(
    x=0,
    y=0,
    width=mask_width,
    height=mask_height,
  )
  match src_rect.clip_to(mask_bounds) {
    Some(clipped_src) => {
      let dst_x = x + clipped_src.x - src_rect.x
      let dst_y = y + clipped_src.y - src_rect.y
      let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
        self,
        dst_x,
        dst_y,
        dst_x + clipped_src.width,
        dst_y + clipped_src.height,
      )
      guard x_start < x_end && y_start < y_end else { return }
      let sampler = self.paint_sampler(paint)
      for py in y_start..<y_end {
        let mut dirty_start = x_end
        let mut dirty_end = x_start
        for px in x_start..<x_end {
          let mask_x = clipped_src.x + px - dst_x
          let mask_y = clipped_src.y + py - dst_y
          let coverage = mask[mask_y * mask_width + mask_x].to_int()
          if coverage > 0 {
            let color = sampler.sample(
              px.to_double() + 0.5,
              py.to_double() + 0.5,
            )
            let alpha = (color.a.to_int() * coverage + 127) / 255
            if blend_sampled_source_pixel(
                self.pixmap,
                px,
                py,
                color.with_alpha(clamp_byte(alpha)),
                paint.blend_mode,
              ) {
              dirty_start = dirty_start.min(px)
              dirty_end = dirty_end.max(px + 1)
            }
          }
        }
        if dirty_start < dirty_end {
          self.mark_dirty_bounds(dirty_start, py, dirty_end, py + 1)
        }
      }
    }
    None => ()
  }
}

///|
/// Draw a source pixmap at the given destination position.
pub fn Canvas::draw_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    x,
    y,
    x + src.get_width(),
    y + src.get_height(),
  )
  guard x_start < x_end && y_start < y_end else { return }
  // The common case — source-over with no filter — is byte identical to the
  // per-pixel path but runs straight over the pixel buffers, and reports the
  // touched bounding box so the dirty region gets one rect instead of one per
  // pixel. Shadow masks and layer composites (hundreds of thousands of pixels
  // per frame) go through here.
  if paint.blend_mode is SourceOver &&
    paint_filter_option_is_none_or_identity(paint.get_filter()) {
    match
      self.pixmap.blend_pixmap_source_over(
        src,
        x,
        y,
        x_start,
        y_start,
        x_end,
        y_end,
        paint.opacity,
      ) {
      Some(rect) =>
        self.mark_dirty_bounds(
          rect.x,
          rect.y,
          rect.x + rect.width,
          rect.y + rect.height,
        )
      None => ()
    }
    return
  }
  for py in y_start..<y_end {
    for px in x_start..<x_end {
      let color = paint.sample_source_color(src.get_pixel(px - x, py - y))
      if should_blend_source_color(color, paint.blend_mode) {
        self.pixmap.blend_pixel_with_mode(px, py, color, paint.blend_mode)
        self.mark_dirty_bounds(px, py, px + 1, py + 1)
      }
    }
  }
}

///|
/// Draw a source pixmap rectangle at the given destination position.
pub fn Canvas::draw_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let src_bounds = PixelRect::new(
    x=0,
    y=0,
    width=src.get_width(),
    height=src.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) => {
      let dst_x = x + clipped_src.x - src_rect.x
      let dst_y = y + clipped_src.y - src_rect.y
      let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
        self,
        dst_x,
        dst_y,
        dst_x + clipped_src.width,
        dst_y + clipped_src.height,
      )
      guard x_start < x_end && y_start < y_end else { return }
      if paint.blend_mode is SourceOver &&
        paint_filter_option_is_none_or_identity(paint.get_filter()) {
        match
          self.pixmap.blend_pixmap_source_over(
            src,
            dst_x - clipped_src.x,
            dst_y - clipped_src.y,
            x_start,
            y_start,
            x_end,
            y_end,
            paint.opacity,
          ) {
          Some(rect) =>
            self.mark_dirty_bounds(
              rect.x,
              rect.y,
              rect.x + rect.width,
              rect.y + rect.height,
            )
          None => ()
        }
        return
      }
      for py in y_start..<y_end {
        for px in x_start..<x_end {
          let src_x = clipped_src.x + px - dst_x
          let src_y = clipped_src.y + py - dst_y
          let color = paint.sample_source_color(src.get_pixel(src_x, src_y))
          if should_blend_source_color(color, paint.blend_mode) {
            self.pixmap.blend_pixel_with_mode(px, py, color, paint.blend_mode)
            self.mark_dirty_bounds(px, py, px + 1, py + 1)
          }
        }
      }
    }
    None => ()
  }
}

///|
fn Canvas::draw_layer_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  paint : Paint,
) -> Unit {
  guard paint.has_shader() else {
    self.draw_pixmap(src, x, y, paint)
    return
  }
  self.draw_layer_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=src.get_width(), height=src.get_height()),
    x,
    y,
    paint,
  )
}

///|
fn Canvas::draw_layer_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  paint : Paint,
) -> Unit {
  guard paint.has_shader() else {
    self.draw_pixmap_rect(src, src_rect, x, y, paint)
    return
  }
  guard paint.style is Fill else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let src_bounds = PixelRect::new(
    x=0,
    y=0,
    width=src.get_width(),
    height=src.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) => {
      let dst_x = x + clipped_src.x - src_rect.x
      let dst_y = y + clipped_src.y - src_rect.y
      let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
        self,
        dst_x,
        dst_y,
        dst_x + clipped_src.width,
        dst_y + clipped_src.height,
      )
      guard x_start < x_end && y_start < y_end else { return }
      for py in y_start..<y_end {
        for px in x_start..<x_end {
          let src_x = clipped_src.x + px - dst_x
          let src_y = clipped_src.y + py - dst_y
          let color = paint.sample_masked_source_color(
            src.get_pixel(src_x, src_y),
            px.to_double() + 0.5,
            py.to_double() + 0.5,
          )
          if should_blend_source_color(color, paint.blend_mode) {
            self.pixmap.blend_pixel_with_mode(px, py, color, paint.blend_mode)
            self.mark_dirty_bounds(px, py, px + 1, py + 1)
          }
        }
      }
    }
    None => ()
  }
}

///|
/// Draw a source pixmap scaled to the given destination rectangle.
pub fn Canvas::draw_scaled_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    x,
    y,
    x + width,
    y + height,
  )
  guard x_start < x_end && y_start < y_end else { return }
  if blend_scaled_pixmap_region(
      self.pixmap,
      x,
      y,
      width,
      height,
      src,
      paint.opacity,
      paint.filter,
      paint.blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
  }
}

///|
/// Draw a source pixmap scaled with bilinear sampling.
pub fn Canvas::draw_scaled_pixmap_bilinear(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    x,
    y,
    x + width,
    y + height,
  )
  guard x_start < x_end && y_start < y_end else { return }
  if blend_scaled_pixmap_bilinear_region(
      self.pixmap,
      x,
      y,
      width,
      height,
      src,
      paint.opacity,
      paint.filter,
      paint.blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
  }
}

///|
/// Draw a source pixmap scaled with bicubic sampling.
pub fn Canvas::draw_scaled_pixmap_bicubic(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    x,
    y,
    x + width,
    y + height,
  )
  guard x_start < x_end && y_start < y_end else { return }
  if blend_scaled_pixmap_bicubic_region(
      self.pixmap,
      x,
      y,
      width,
      height,
      src,
      paint.opacity,
      paint.filter,
      paint.blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
  }
}

///|
/// Draw a source pixmap scaled with an explicit sampling mode.
pub fn Canvas::draw_sampled_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
  sampling : ImageSampling,
) -> Unit {
  match sampling {
    Nearest => self.draw_scaled_pixmap(src, x, y, width, height, paint)
    Bilinear =>
      self.draw_scaled_pixmap_bilinear(src, x, y, width, height, paint)
    Bicubic => self.draw_scaled_pixmap_bicubic(src, x, y, width, height, paint)
  }
}

///|
/// Draw a source pixmap scaled with a quality strategy.
pub fn Canvas::draw_quality_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
  quality : ImageQuality,
) -> Unit {
  self.draw_sampled_pixmap(
    src,
    x,
    y,
    width,
    height,
    paint,
    quality.to_sampling(),
  )
}

///|
/// Draw a source pixmap rectangle scaled to the given destination rectangle.
pub fn Canvas::draw_scaled_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  self.draw_sampled_pixmap_rect(
    src,
    src_rect,
    x,
    y,
    width,
    height,
    paint,
    Nearest,
  )
}

///|
/// Draw a source pixmap rectangle scaled with bilinear sampling.
pub fn Canvas::draw_scaled_pixmap_rect_bilinear(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  self.draw_sampled_pixmap_rect(
    src,
    src_rect,
    x,
    y,
    width,
    height,
    paint,
    Bilinear,
  )
}

///|
/// Draw a source pixmap rectangle scaled with bicubic sampling.
pub fn Canvas::draw_scaled_pixmap_rect_bicubic(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  self.draw_sampled_pixmap_rect(
    src,
    src_rect,
    x,
    y,
    width,
    height,
    paint,
    Bicubic,
  )
}

///|
/// Draw a source pixmap rectangle scaled with an explicit sampling mode.
pub fn Canvas::draw_sampled_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
  sampling : ImageSampling,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let src_bounds = PixelRect::new(
    x=0,
    y=0,
    width=src.get_width(),
    height=src.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) => {
      let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
        self,
        x,
        y,
        x + width,
        y + height,
      )
      guard x_start < x_end && y_start < y_end else { return }
      if blend_sampled_pixmap_rect_region(
          self.pixmap,
          x,
          y,
          width,
          height,
          src,
          clipped_src,
          paint.opacity,
          paint.filter,
          sampling,
          paint.blend_mode,
          x_start,
          y_start,
          x_end,
          y_end,
        ) {
        self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
      }
    }
    None => ()
  }
}

///|
/// Draw a source pixmap rectangle scaled with a quality strategy.
pub fn Canvas::draw_quality_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
  quality : ImageQuality,
) -> Unit {
  self.draw_sampled_pixmap_rect(
    src,
    src_rect,
    x,
    y,
    width,
    height,
    paint,
    quality.to_sampling(),
  )
}

///|
/// Draw a source pixmap transformed by the current canvas transform.
pub fn Canvas::draw_transformed_sampled_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : Paint,
  sampling : ImageSampling,
) -> Unit {
  self.draw_transformed_sampled_pixmap_rect(
    src,
    PixelRect::new(x=0, y=0, width=src.get_width(), height=src.get_height()),
    x,
    y,
    width,
    height,
    paint,
    sampling,
  )
}

///|
/// Draw a source pixmap transformed by the current transform using a quality
/// strategy.
pub fn Canvas::draw_transformed_quality_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : Paint,
  quality : ImageQuality,
) -> Unit {
  self.draw_transformed_sampled_pixmap(
    src,
    x,
    y,
    width,
    height,
    paint,
    quality.to_sampling(),
  )
}

///|
/// Exact axis-aligned one-to-one blit of a source pixmap rectangle.
///
/// Retained-layer composites land here: the layer pixmap is rendered at
/// `logical size x device scale`, and the composite maps it back onto exactly
/// that many device pixels. Every device pixel centre then falls on a source
/// pixel centre, so nearest and bilinear sampling are both an exact copy and
/// the per-pixel matrix inverse plus resample can be skipped.
///
/// Returns `false` and leaves the caller on the general path whenever the
/// mapping is not exact: a fractional device origin, a non-integral scale, a
/// source rect that needs clipping, or bicubic sampling.
fn Canvas::blit_pixmap_rect_exact(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : Paint,
  sampling : ImageSampling,
) -> Bool {
  match sampling {
    Nearest | Bilinear => ()
    _ => return false
  }
  let transform = self.transform
  guard transform.b == 0.0 &&
    transform.c == 0.0 &&
    transform.a > 0.0 &&
    transform.d > 0.0 else {
    return false
  }
  guard src_rect.x >= 0 &&
    src_rect.y >= 0 &&
    src_rect.x + src_rect.width <= src.get_width() &&
    src_rect.y + src_rect.height <= src.get_height() else {
    return false
  }
  // The destination must cover exactly one device pixel per source pixel.
  guard width * transform.a == src_rect.width.to_double() &&
    height * transform.d == src_rect.height.to_double() else {
    return false
  }
  let left = x * transform.a + transform.tx
  let top = y * transform.d + transform.ty
  let left_floor = left.floor()
  let top_floor = top.floor()
  guard left - left_floor < 1.0e-9 && top - top_floor < 1.0e-9 else {
    return false
  }
  let left_int = left_floor.to_int()
  let top_int = top_floor.to_int()
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    left_int,
    top_int,
    left_int + src_rect.width,
    top_int + src_rect.height,
  )
  guard x_start < x_end && y_start < y_end else { return true }
  for py in y_start..<y_end {
    let sy = src_rect.y + (py - top_int)
    let mut dirty_start = x_end
    let mut dirty_end = x_start
    for px in x_start..<x_end {
      let sx = src_rect.x + (px - left_int)
      let color = paint.sample_source_color(src.get_pixel(sx, sy))
      if should_blend_source_color(color, paint.blend_mode) {
        self.pixmap.blend_pixel_with_mode(px, py, color, paint.blend_mode)
        dirty_start = dirty_start.min(px)
        dirty_end = dirty_end.max(px + 1)
      }
    }
    if dirty_start < dirty_end {
      self.mark_dirty_bounds(dirty_start, py, dirty_end, py + 1)
    }
  }
  true
}

///|
/// Draw a source pixmap rectangle transformed by the current canvas transform.
pub fn Canvas::draw_transformed_sampled_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : Paint,
  sampling : ImageSampling,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0.0 && height > 0.0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  if self.blit_pixmap_rect_exact(
      src, src_rect, x, y, width, height, paint, sampling,
    ) {
    return
  }
  let src_bounds = PixelRect::new(
    x=0,
    y=0,
    width=src.get_width(),
    height=src.get_height(),
  )
  match (src_rect.clip_to(src_bounds), self.transform.inverse()) {
    (Some(clipped_src), Some(inverse_transform)) => {
      let (left, top, right, bottom) = transformed_rect_bounds(
        self.transform,
        x,
        y,
        width,
        height,
      )
      let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
        self, left, top, right, bottom,
      )
      guard x_start < x_end && y_start < y_end else { return }
      let local_right = x + width
      let local_bottom = y + height
      let mut dirty_left = x_end
      let mut dirty_top = y_end
      let mut dirty_right = x_start
      let mut dirty_bottom = y_start
      for py in y_start..<y_end {
        for px in x_start..<x_end {
          let (local_x, local_y) = inverse_transform.apply(
            px.to_double() + 0.5,
            py.to_double() + 0.5,
          )
          if local_x >= x &&
            local_x < local_right &&
            local_y >= y &&
            local_y < local_bottom {
            let sampled = sample_transformed_pixmap_rect(
              src, clipped_src, local_x, local_y, x, y, width, height, sampling,
            )
            let color = paint.sample_source_color(sampled)
            if should_blend_source_color(color, paint.blend_mode) {
              self.pixmap.blend_pixel_with_mode(px, py, color, paint.blend_mode)
              dirty_left = dirty_left.min(px)
              dirty_top = dirty_top.min(py)
              dirty_right = dirty_right.max(px + 1)
              dirty_bottom = dirty_bottom.max(py + 1)
            }
          }
        }
      }
      if dirty_left < dirty_right && dirty_top < dirty_bottom {
        self.mark_dirty_bounds(dirty_left, dirty_top, dirty_right, dirty_bottom)
      }
    }
    _ => ()
  }
}

///|
/// Draw a source pixmap rectangle transformed by the current transform using a
/// quality strategy.
pub fn Canvas::draw_transformed_quality_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : Paint,
  quality : ImageQuality,
) -> Unit {
  self.draw_transformed_sampled_pixmap_rect(
    src,
    src_rect,
    x,
    y,
    width,
    height,
    paint,
    quality.to_sampling(),
  )
}

///|
/// Draw a source pixmap rectangle repeatedly into the destination rectangle.
pub fn Canvas::draw_tiled_pixmap_rect(
  self : Canvas,
  src : Pixmap,
  src_rect : PixelRect,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  paint : Paint,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let src_bounds = PixelRect::new(
    x=0,
    y=0,
    width=src.get_width(),
    height=src.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) => {
      let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
        self,
        x,
        y,
        x + width,
        y + height,
      )
      guard x_start < x_end && y_start < y_end else { return }
      if blend_tiled_pixmap_rect_region(
          self.pixmap,
          x,
          y,
          width,
          height,
          src,
          clipped_src,
          paint.opacity,
          paint.filter,
          paint.blend_mode,
          x_start,
          y_start,
          x_end,
          y_end,
        ) {
        self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
      }
    }
    None => ()
  }
}

///|
/// Draw a source pixmap using nine-patch scaling.
pub fn Canvas::draw_nine_patch_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  insets : NinePatchInsets,
  paint : Paint,
  sampling : ImageSampling,
) -> Unit {
  guard paint.style is Fill else { return }
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    x,
    y,
    x + width,
    y + height,
  )
  guard x_start < x_end && y_start < y_end else { return }
  if blend_nine_patch_pixmap_region(
      self.pixmap,
      x,
      y,
      width,
      height,
      src,
      insets,
      paint.opacity,
      paint.filter,
      sampling,
      paint.blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
  }
}

///|
/// Draw a source pixmap using nine-patch scaling and a quality strategy.
pub fn Canvas::draw_quality_nine_patch_pixmap(
  self : Canvas,
  src : Pixmap,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  insets : NinePatchInsets,
  paint : Paint,
  quality : ImageQuality,
) -> Unit {
  self.draw_nine_patch_pixmap(
    src,
    x,
    y,
    width,
    height,
    insets,
    paint,
    quality.to_sampling(),
  )
}

///|
fn transformed_rect_bounds(
  transform : Transform,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> (Int32, Int32, Int32, Int32) {
  let (x0, y0) = transform.apply(x, y)
  let (x1, y1) = transform.apply(x + width, y)
  let (x2, y2) = transform.apply(x, y + height)
  let (x3, y3) = transform.apply(x + width, y + height)
  let min_x = x0.min(x1).min(x2).min(x3)
  let min_y = y0.min(y1).min(y2).min(y3)
  let max_x = x0.max(x1).max(x2).max(x3)
  let max_y = y0.max(y1).max(y2).max(y3)
  (
    floor_to_int(min_x),
    floor_to_int(min_y),
    ceil_to_int(max_x),
    ceil_to_int(max_y),
  )
}

///|
fn ceil_to_int(value : Double) -> Int32 {
  -floor_to_int(-value)
}

///|
fn sample_transformed_pixmap_rect(
  src : Pixmap,
  src_rect : PixelRect,
  local_x : Double,
  local_y : Double,
  dst_x : Double,
  dst_y : Double,
  dst_width : Double,
  dst_height : Double,
  sampling : ImageSampling,
) -> Color {
  let u = (local_x - dst_x) / dst_width
  let v = (local_y - dst_y) / dst_height
  match sampling {
    Nearest => {
      let src_x = src_rect.x +
        floor_to_int(u * src_rect.width.to_double())
        .max(0)
        .min(src_rect.width - 1)
      let src_y = src_rect.y +
        floor_to_int(v * src_rect.height.to_double())
        .max(0)
        .min(src_rect.height - 1)
      src.get_pixel(src_x, src_y)
    }
    Bilinear => {
      let src_x = src_rect.x.to_double() + u * src_rect.width.to_double() - 0.5
      let src_y = src_rect.y.to_double() + v * src_rect.height.to_double() - 0.5
      sample_bilinear_rect(src, src_x, src_y, src_rect)
    }
    Bicubic => {
      let src_x = src_rect.x.to_double() + u * src_rect.width.to_double() - 0.5
      let src_y = src_rect.y.to_double() + v * src_rect.height.to_double() - 0.5
      sample_bicubic_rect(src, src_x, src_y, src_rect)
    }
  }
}
