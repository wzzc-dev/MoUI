///|
/// Pixel buffer for 2D rendering (RGBA format)
pub struct Pixmap {
  width : Int
  height : Int
  pixels : FixedArray[Byte]
} derive(Debug)

///|
/// Sampling mode used when scaling source pixmaps.
pub(all) enum ImageSampling {
  Nearest
  Bilinear
  Bicubic
} derive(Eq, Debug)

///|
/// Image quality strategy for callers that prefer intent over a concrete
/// sampling algorithm.
pub(all) enum ImageQuality {
  Fast
  Balanced
  High
} derive(Eq, Debug)

///|
/// Return the concrete sampling mode selected by this quality strategy.
pub fn ImageQuality::to_sampling(self : ImageQuality) -> ImageSampling {
  match self {
    ImageQuality::Fast => ImageSampling::Nearest
    ImageQuality::Balanced => ImageSampling::Bilinear
    ImageQuality::High => ImageSampling::Bicubic
  }
}

///|
/// Insets used for nine-patch image scaling.
pub struct NinePatchInsets {
  left : Int
  top : Int
  right : Int
  bottom : Int
} derive(Eq, Debug)

///|
pub fn NinePatchInsets::new(
  left~ : Int,
  top~ : Int,
  right~ : Int,
  bottom~ : Int,
) -> NinePatchInsets {
  { left, top, right, bottom }
}

///|
struct NinePatchSlices {
  src_left : Int
  src_right : Int
  src_top : Int
  src_bottom : Int
  dst_left : Int
  dst_right : Int
  dst_top : Int
  dst_bottom : Int
} derive(Debug)

///|
/// Create a new pixmap filled with transparent pixels
pub fn Pixmap::new(width : Int, height : Int) -> Pixmap {
  let size = width * height * 4
  { width, height, pixels: FixedArray::make(size, 0) }
}

///|
/// Get the width of the pixmap
pub fn Pixmap::get_width(self : Pixmap) -> Int {
  self.width
}

///|
/// Get the height of the pixmap
pub fn Pixmap::get_height(self : Pixmap) -> Int {
  self.height
}

///|
/// Get the raw pixel data
pub fn Pixmap::get_pixels(self : Pixmap) -> FixedArray[Byte] {
  self.pixels
}

///|
/// Copy this pixmap and its raw pixel storage.
pub fn Pixmap::copy(self : Pixmap) -> Pixmap {
  { width: self.width, height: self.height, pixels: copy_pixmap_pixels(self) }
}

///|
/// Return a deterministic lightweight checksum of the raw RGBA pixel bytes.
/// This is intended for compact regression assertions and smoke telemetry, not
/// for cryptographic or collision-resistant validation.
pub fn Pixmap::checksum(self : Pixmap) -> Int {
  checksum_rgba_bytes(self.pixels)
}

///|
/// Set a pixel at the given coordinates
pub fn Pixmap::set_pixel(
  self : Pixmap,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else { return }
  let idx = (y * self.width + x) * 4
  self.pixels[idx] = color.r
  self.pixels[idx + 1] = color.g
  self.pixels[idx + 2] = color.b
  self.pixels[idx + 3] = color.a
}

///|
fn copy_pixmap_pixels(pixmap : Pixmap) -> FixedArray[Byte] {
  let src = pixmap.get_pixels()
  let dst : FixedArray[Byte] = FixedArray::make(src.length(), 0)
  for i in 0..<src.length() {
    dst[i] = src[i]
  }
  dst
}

///|
fn checksum_rgba_bytes(pixels : FixedArray[Byte]) -> Int {
  let mut checksum = 0
  for i in 0..<pixels.length() {
    checksum = (checksum + pixels[i].to_int() * (i % 251 + 1)) % 1000003
  }
  checksum
}

///|
/// Composite a pixel over the existing pixel at the given coordinates
pub fn Pixmap::blend_pixel(
  self : Pixmap,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else { return }
  self.set_pixel(x, y, color.blend_over(self.get_pixel(x, y)))
}

///|
fn Pixmap::blend_pixel_with_mode(
  self : Pixmap,
  x : Int,
  y : Int,
  color : Color,
  blend_mode : BlendMode,
) -> Unit {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else { return }
  self.set_pixel(x, y, color.blend_with(self.get_pixel(x, y), blend_mode))
}

///|
/// Get the color at the given coordinates
pub fn Pixmap::get_pixel(self : Pixmap, x : Int, y : Int) -> Color {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else {
    return Color::transparent()
  }
  let idx = (y * self.width + x) * 4
  Color::new(
    r=self.pixels[idx],
    g=self.pixels[idx + 1],
    b=self.pixels[idx + 2],
    a=self.pixels[idx + 3],
  )
}

///|
/// Clear the pixmap with a color
pub fn Pixmap::clear(self : Pixmap, color : Color) -> Unit {
  for y in 0..<self.height {
    for x in 0..<self.width {
      self.set_pixel(x, y, color)
    }
  }
}

///|
/// Fill a rectangle with a color
pub fn Pixmap::fill_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
) -> Unit {
  for dy in 0..<h {
    for dx in 0..<w {
      self.set_pixel(x + dx, y + dy, color)
    }
  }
}

///|
/// Composite a rectangle over the existing pixels
pub fn Pixmap::blend_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
) -> Unit {
  for dy in 0..<h {
    for dx in 0..<w {
      self.blend_pixel(x + dx, y + dy, color)
    }
  }
}

///|
fn Pixmap::blend_rect_with_mode(
  self : Pixmap,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  color : Color,
  blend_mode : BlendMode,
) -> Unit {
  for dy in 0..<h {
    for dx in 0..<w {
      self.blend_pixel_with_mode(x + dx, y + dy, color, blend_mode)
    }
  }
}

///|
/// Composite a grayscale coverage mask over the existing pixels
pub fn Pixmap::blend_mask(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  mask : FixedArray[Byte],
  color : Color,
) -> Unit {
  guard width > 0 && height > 0 && mask.length() >= width * height else {
    return
  }
  for my in 0..<height {
    for mx in 0..<width {
      let coverage = mask[my * width + mx].to_int()
      if coverage > 0 {
        let alpha = (color.a.to_int() * coverage + 127) / 255
        self.blend_pixel(x + mx, y + my, color.with_alpha(clamp_byte(alpha)))
      }
    }
  }
}

///|
/// Composite a source rectangle from a grayscale coverage mask over this pixmap.
pub fn Pixmap::blend_mask_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  mask_width : Int,
  mask_height : Int,
  mask : FixedArray[Byte],
  src_rect : PixelRect,
  color : Color,
) -> Unit {
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
      let x_start = dst_x.max(0)
      let y_start = dst_y.max(0)
      let x_end = (dst_x + clipped_src.width).min(self.width)
      let y_end = (dst_y + clipped_src.height).min(self.height)
      guard x_start < x_end && y_start < y_end else { return }
      for py in y_start..<y_end {
        for px in x_start..<x_end {
          let mask_x = clipped_src.x + px - dst_x
          let mask_y = clipped_src.y + py - dst_y
          let coverage = mask[mask_y * mask_width + mask_x].to_int()
          if coverage > 0 {
            let alpha = (color.a.to_int() * coverage + 127) / 255
            self.blend_pixel(px, py, color.with_alpha(clamp_byte(alpha)))
          }
        }
      }
    }
    None => ()
  }
}

///|
/// Composite another pixmap over this pixmap at the given destination position.
pub fn Pixmap::blend_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  src : Pixmap,
  opacity : Double,
) -> Unit {
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let x_start = x.max(0)
  let y_start = y.max(0)
  let x_end = (x + src.get_width()).min(self.width)
  let y_end = (y + src.get_height()).min(self.height)
  guard x_start < x_end && y_start < y_end else { return }
  for py in y_start..<y_end {
    for px in x_start..<x_end {
      let src_color = src.get_pixel(px - x, py - y).scale_alpha(opacity)
      if src_color.a.to_int() > 0 {
        self.blend_pixel(px, py, src_color)
      }
    }
  }
}

///|
/// Composite a source pixmap rectangle over this pixmap at the destination
/// position corresponding to the requested source rectangle's top-left corner.
pub fn Pixmap::blend_pixmap_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
) -> Unit {
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
      let x_start = dst_x.max(0)
      let y_start = dst_y.max(0)
      let x_end = (dst_x + clipped_src.width).min(self.width)
      let y_end = (dst_y + clipped_src.height).min(self.height)
      guard x_start < x_end && y_start < y_end else { return }
      for py in y_start..<y_end {
        for px in x_start..<x_end {
          let src_x = clipped_src.x + px - dst_x
          let src_y = clipped_src.y + py - dst_y
          let src_color = src.get_pixel(src_x, src_y).scale_alpha(opacity)
          if src_color.a.to_int() > 0 {
            self.blend_pixel(px, py, src_color)
          }
        }
      }
    }
    None => ()
  }
}

///|
/// Composite another pixmap scaled to the given destination size.
pub fn Pixmap::blend_scaled_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
) -> Unit {
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let x_start = x.max(0)
  let y_start = y.max(0)
  let x_end = (x + width).min(self.width)
  let y_end = (y + height).min(self.height)
  guard x_start < x_end && y_start < y_end else { return }
  ignore(
    blend_scaled_pixmap_region(
      self,
      x,
      y,
      width,
      height,
      src,
      opacity,
      None,
      BlendMode::SourceOver,
      x_start,
      y_start,
      x_end,
      y_end,
    ),
  )
}

///|
/// Composite another pixmap scaled with bilinear sampling.
pub fn Pixmap::blend_scaled_pixmap_bilinear(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
) -> Unit {
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let x_start = x.max(0)
  let y_start = y.max(0)
  let x_end = (x + width).min(self.width)
  let y_end = (y + height).min(self.height)
  guard x_start < x_end && y_start < y_end else { return }
  ignore(
    blend_scaled_pixmap_bilinear_region(
      self,
      x,
      y,
      width,
      height,
      src,
      opacity,
      None,
      BlendMode::SourceOver,
      x_start,
      y_start,
      x_end,
      y_end,
    ),
  )
}

///|
/// Composite another pixmap scaled with bicubic sampling.
pub fn Pixmap::blend_scaled_pixmap_bicubic(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
) -> Unit {
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let x_start = x.max(0)
  let y_start = y.max(0)
  let x_end = (x + width).min(self.width)
  let y_end = (y + height).min(self.height)
  guard x_start < x_end && y_start < y_end else { return }
  ignore(
    blend_scaled_pixmap_bicubic_region(
      self,
      x,
      y,
      width,
      height,
      src,
      opacity,
      None,
      BlendMode::SourceOver,
      x_start,
      y_start,
      x_end,
      y_end,
    ),
  )
}

///|
/// Composite another pixmap scaled with an explicit sampling mode.
pub fn Pixmap::blend_sampled_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
  sampling : ImageSampling,
) -> Unit {
  match sampling {
    ImageSampling::Nearest =>
      self.blend_scaled_pixmap(x, y, width, height, src, opacity)
    ImageSampling::Bilinear =>
      self.blend_scaled_pixmap_bilinear(x, y, width, height, src, opacity)
    ImageSampling::Bicubic =>
      self.blend_scaled_pixmap_bicubic(x, y, width, height, src, opacity)
  }
}

///|
/// Composite another pixmap scaled with a quality strategy.
pub fn Pixmap::blend_quality_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
  quality : ImageQuality,
) -> Unit {
  self.blend_sampled_pixmap(
    x,
    y,
    width,
    height,
    src,
    opacity,
    quality.to_sampling(),
  )
}

///|
/// Composite a source pixmap rectangle scaled to the given destination size.
pub fn Pixmap::blend_scaled_pixmap_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
) -> Unit {
  self.blend_sampled_pixmap_rect(
    x,
    y,
    width,
    height,
    src,
    src_rect,
    opacity,
    ImageSampling::Nearest,
  )
}

///|
/// Composite a source pixmap rectangle scaled with bilinear sampling.
pub fn Pixmap::blend_scaled_pixmap_rect_bilinear(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
) -> Unit {
  self.blend_sampled_pixmap_rect(
    x,
    y,
    width,
    height,
    src,
    src_rect,
    opacity,
    ImageSampling::Bilinear,
  )
}

///|
/// Composite a source pixmap rectangle scaled with bicubic sampling.
pub fn Pixmap::blend_scaled_pixmap_rect_bicubic(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
) -> Unit {
  self.blend_sampled_pixmap_rect(
    x,
    y,
    width,
    height,
    src,
    src_rect,
    opacity,
    ImageSampling::Bicubic,
  )
}

///|
/// Composite a source pixmap rectangle scaled with an explicit sampling mode.
pub fn Pixmap::blend_sampled_pixmap_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  sampling : ImageSampling,
) -> Unit {
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
      let x_start = x.max(0)
      let y_start = y.max(0)
      let x_end = (x + width).min(self.width)
      let y_end = (y + height).min(self.height)
      guard x_start < x_end && y_start < y_end else { return }
      ignore(
        blend_sampled_pixmap_rect_region(
          self,
          x,
          y,
          width,
          height,
          src,
          clipped_src,
          opacity,
          None,
          sampling,
          BlendMode::SourceOver,
          x_start,
          y_start,
          x_end,
          y_end,
        ),
      )
    }
    None => ()
  }
}

///|
/// Composite a source pixmap rectangle scaled with a quality strategy.
pub fn Pixmap::blend_quality_pixmap_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  quality : ImageQuality,
) -> Unit {
  self.blend_sampled_pixmap_rect(
    x,
    y,
    width,
    height,
    src,
    src_rect,
    opacity,
    quality.to_sampling(),
  )
}

///|
/// Composite a source pixmap rectangle repeatedly into the destination area.
pub fn Pixmap::blend_tiled_pixmap_rect(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
) -> Unit {
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
      let x_start = x.max(0)
      let y_start = y.max(0)
      let x_end = (x + width).min(self.width)
      let y_end = (y + height).min(self.height)
      guard x_start < x_end && y_start < y_end else { return }
      ignore(
        blend_tiled_pixmap_rect_region(
          self,
          x,
          y,
          width,
          height,
          src,
          clipped_src,
          opacity,
          None,
          BlendMode::SourceOver,
          x_start,
          y_start,
          x_end,
          y_end,
        ),
      )
    }
    None => ()
  }
}

///|
/// Composite a source pixmap using nine-patch scaling.
pub fn Pixmap::blend_nine_patch_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  insets : NinePatchInsets,
  opacity : Double,
  sampling : ImageSampling,
) -> Unit {
  guard width > 0 && height > 0 else { return }
  guard src.get_width() > 0 && src.get_height() > 0 else { return }
  let x_start = x.max(0)
  let y_start = y.max(0)
  let x_end = (x + width).min(self.width)
  let y_end = (y + height).min(self.height)
  guard x_start < x_end && y_start < y_end else { return }
  ignore(
    blend_nine_patch_pixmap_region(
      self,
      x,
      y,
      width,
      height,
      src,
      insets,
      opacity,
      None,
      sampling,
      BlendMode::SourceOver,
      x_start,
      y_start,
      x_end,
      y_end,
    ),
  )
}

///|
/// Composite a source pixmap using nine-patch scaling and a quality strategy.
pub fn Pixmap::blend_quality_nine_patch_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  insets : NinePatchInsets,
  opacity : Double,
  quality : ImageQuality,
) -> Unit {
  self.blend_nine_patch_pixmap(
    x,
    y,
    width,
    height,
    src,
    insets,
    opacity,
    quality.to_sampling(),
  )
}

///|
fn blend_nine_patch_pixmap_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  insets : NinePatchInsets,
  opacity : Double,
  filter : PaintFilter?,
  sampling : ImageSampling,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  let slices = make_nine_patch_slices(
    src.get_width(),
    src.get_height(),
    width,
    height,
    insets,
  )
  let mut did_blend = false
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      0,
      0,
      slices.dst_left,
      slices.dst_top,
      src,
      PixelRect::new(x=0, y=0, width=slices.src_left, height=slices.src_top),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      slices.dst_left,
      0,
      width - slices.dst_left - slices.dst_right,
      slices.dst_top,
      src,
      PixelRect::new(
        x=slices.src_left,
        y=0,
        width=src.get_width() - slices.src_left - slices.src_right,
        height=slices.src_top,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      width - slices.dst_right,
      0,
      slices.dst_right,
      slices.dst_top,
      src,
      PixelRect::new(
        x=src.get_width() - slices.src_right,
        y=0,
        width=slices.src_right,
        height=slices.src_top,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      0,
      slices.dst_top,
      slices.dst_left,
      height - slices.dst_top - slices.dst_bottom,
      src,
      PixelRect::new(
        x=0,
        y=slices.src_top,
        width=slices.src_left,
        height=src.get_height() - slices.src_top - slices.src_bottom,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      slices.dst_left,
      slices.dst_top,
      width - slices.dst_left - slices.dst_right,
      height - slices.dst_top - slices.dst_bottom,
      src,
      PixelRect::new(
        x=slices.src_left,
        y=slices.src_top,
        width=src.get_width() - slices.src_left - slices.src_right,
        height=src.get_height() - slices.src_top - slices.src_bottom,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      width - slices.dst_right,
      slices.dst_top,
      slices.dst_right,
      height - slices.dst_top - slices.dst_bottom,
      src,
      PixelRect::new(
        x=src.get_width() - slices.src_right,
        y=slices.src_top,
        width=slices.src_right,
        height=src.get_height() - slices.src_top - slices.src_bottom,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      0,
      height - slices.dst_bottom,
      slices.dst_left,
      slices.dst_bottom,
      src,
      PixelRect::new(
        x=0,
        y=src.get_height() - slices.src_bottom,
        width=slices.src_left,
        height=slices.src_bottom,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      slices.dst_left,
      height - slices.dst_bottom,
      width - slices.dst_left - slices.dst_right,
      slices.dst_bottom,
      src,
      PixelRect::new(
        x=slices.src_left,
        y=src.get_height() - slices.src_bottom,
        width=src.get_width() - slices.src_left - slices.src_right,
        height=slices.src_bottom,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  if blend_nine_patch_segment(
      dst,
      x,
      y,
      width - slices.dst_right,
      height - slices.dst_bottom,
      slices.dst_right,
      slices.dst_bottom,
      src,
      PixelRect::new(
        x=src.get_width() - slices.src_right,
        y=src.get_height() - slices.src_bottom,
        width=slices.src_right,
        height=slices.src_bottom,
      ),
      opacity,
      filter,
      sampling,
      blend_mode,
      x_start,
      y_start,
      x_end,
      y_end,
    ) {
    did_blend = true
  }
  did_blend
}

///|
fn make_nine_patch_slices(
  src_width : Int,
  src_height : Int,
  dst_width : Int,
  dst_height : Int,
  insets : NinePatchInsets,
) -> NinePatchSlices {
  let (src_left, src_right) = clamp_edge_pair(
    src_width,
    insets.left,
    insets.right,
  )
  let (src_top, src_bottom) = clamp_edge_pair(
    src_height,
    insets.top,
    insets.bottom,
  )
  let (dst_left, dst_right) = clamp_edge_pair(dst_width, src_left, src_right)
  let (dst_top, dst_bottom) = clamp_edge_pair(dst_height, src_top, src_bottom)
  {
    src_left,
    src_right,
    src_top,
    src_bottom,
    dst_left,
    dst_right,
    dst_top,
    dst_bottom,
  }
}

///|
fn clamp_edge_pair(total : Int, start : Int, end : Int) -> (Int, Int) {
  guard total > 0 else { return (0, 0) }
  let clamped_start = start.max(0).min(total)
  let clamped_end = end.max(0).min(total - clamped_start)
  (clamped_start, clamped_end)
}

///|
fn blend_nine_patch_segment(
  dst : Pixmap,
  patch_x : Int,
  patch_y : Int,
  dst_offset_x : Int,
  dst_offset_y : Int,
  dst_width : Int,
  dst_height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  filter : PaintFilter?,
  sampling : ImageSampling,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  guard dst_width > 0 && dst_height > 0 else { return false }
  guard src_rect.width > 0 && src_rect.height > 0 else { return false }
  let dst_x = patch_x + dst_offset_x
  let dst_y = patch_y + dst_offset_y
  let segment_x_start = x_start.max(dst_x)
  let segment_y_start = y_start.max(dst_y)
  let segment_x_end = x_end.min(dst_x + dst_width)
  let segment_y_end = y_end.min(dst_y + dst_height)
  guard segment_x_start < segment_x_end && segment_y_start < segment_y_end else {
    return false
  }
  blend_sampled_pixmap_rect_region(
    dst, dst_x, dst_y, dst_width, dst_height, src, src_rect, opacity, filter, sampling,
    blend_mode, segment_x_start, segment_y_start, segment_x_end, segment_y_end,
  )
}

///|
fn blend_sampled_pixmap_rect_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  filter : PaintFilter?,
  sampling : ImageSampling,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  match sampling {
    ImageSampling::Nearest =>
      blend_scaled_pixmap_rect_region(
        dst, x, y, width, height, src, src_rect, opacity, filter, blend_mode, x_start,
        y_start, x_end, y_end,
      )
    ImageSampling::Bilinear =>
      blend_scaled_pixmap_rect_bilinear_region(
        dst, x, y, width, height, src, src_rect, opacity, filter, blend_mode, x_start,
        y_start, x_end, y_end,
      )
    ImageSampling::Bicubic =>
      blend_scaled_pixmap_rect_bicubic_region(
        dst, x, y, width, height, src, src_rect, opacity, filter, blend_mode, x_start,
        y_start, x_end, y_end,
      )
  }
}

///|
fn blend_tiled_pixmap_rect_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  guard width > 0 && height > 0 else { return false }
  guard src_rect.width > 0 && src_rect.height > 0 else { return false }
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = src_rect.y + positive_mod(py - y, src_rect.height)
    for px in x_start..<x_end {
      let src_x = src_rect.x + positive_mod(px - x, src_rect.width)
      let src_color = sample_source_color_with_filter(
        src.get_pixel(src_x, src_y),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn blend_scaled_pixmap_rect_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  guard width > 0 && height > 0 else { return false }
  guard src_rect.width > 0 && src_rect.height > 0 else { return false }
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = src_rect.y +
      scaled_source_index(py - y, height, src_rect.height)
    for px in x_start..<x_end {
      let src_x = src_rect.x +
        scaled_source_index(px - x, width, src_rect.width)
      let src_color = sample_source_color_with_filter(
        src.get_pixel(src_x, src_y),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn blend_scaled_pixmap_rect_bilinear_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  guard width > 0 && height > 0 else { return false }
  guard src_rect.width > 0 && src_rect.height > 0 else { return false }
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = src_rect.y.to_double() +
      scaled_source_position(py - y, height, src_rect.height)
    for px in x_start..<x_end {
      let src_x = src_rect.x.to_double() +
        scaled_source_position(px - x, width, src_rect.width)
      let src_color = sample_source_color_with_filter(
        sample_bilinear_rect(src, src_x, src_y, src_rect),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn blend_scaled_pixmap_rect_bicubic_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  src_rect : PixelRect,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  guard width > 0 && height > 0 else { return false }
  guard src_rect.width > 0 && src_rect.height > 0 else { return false }
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = src_rect.y.to_double() +
      scaled_source_position(py - y, height, src_rect.height)
    for px in x_start..<x_end {
      let src_x = src_rect.x.to_double() +
        scaled_source_position(px - x, width, src_rect.width)
      let src_color = sample_source_color_with_filter(
        sample_bicubic_rect(src, src_x, src_y, src_rect),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn blend_scaled_pixmap_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = scaled_source_index(py - y, height, src.get_height())
    for px in x_start..<x_end {
      let src_x = scaled_source_index(px - x, width, src.get_width())
      let src_color = sample_source_color_with_filter(
        src.get_pixel(src_x, src_y),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn scaled_source_index(dst_offset : Int, dst_size : Int, src_size : Int) -> Int {
  guard dst_size > 0 && src_size > 0 else { return 0 }
  let numerator = (dst_offset * 2 + 1) * src_size
  let denominator = dst_size * 2
  (numerator / denominator).max(0).min(src_size - 1)
}

///|
fn blend_scaled_pixmap_bilinear_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = scaled_source_position(py - y, height, src.get_height())
    for px in x_start..<x_end {
      let src_x = scaled_source_position(px - x, width, src.get_width())
      let src_color = sample_source_color_with_filter(
        sample_bilinear(src, src_x, src_y),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn blend_scaled_pixmap_bicubic_region(
  dst : Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  src : Pixmap,
  opacity : Double,
  filter : PaintFilter?,
  blend_mode : BlendMode,
  x_start : Int,
  y_start : Int,
  x_end : Int,
  y_end : Int,
) -> Bool {
  let mut did_blend = false
  for py in y_start..<y_end {
    let src_y = scaled_source_position(py - y, height, src.get_height())
    for px in x_start..<x_end {
      let src_x = scaled_source_position(px - x, width, src.get_width())
      let src_color = sample_source_color_with_filter(
        sample_bicubic(src, src_x, src_y),
        filter,
        opacity,
      )
      if blend_sampled_source_pixel(dst, px, py, src_color, blend_mode) {
        did_blend = true
      }
    }
  }
  did_blend
}

///|
fn blend_sampled_source_pixel(
  dst : Pixmap,
  x : Int,
  y : Int,
  color : Color,
  blend_mode : BlendMode,
) -> Bool {
  guard should_blend_source_color(color, blend_mode) else { return false }
  dst.blend_pixel_with_mode(x, y, color, blend_mode)
  true
}

///|
fn scaled_source_position(
  dst_offset : Int,
  dst_size : Int,
  src_size : Int,
) -> Double {
  guard dst_size > 0 && src_size > 0 else { return 0.0 }
  (dst_offset.to_double() + 0.5) * src_size.to_double() / dst_size.to_double() -
  0.5
}

///|
fn sample_bilinear(src : Pixmap, x : Double, y : Double) -> Color {
  let x_floor = floor_to_int(x)
  let y_floor = floor_to_int(y)
  let x0 = x_floor.max(0).min(src.get_width() - 1)
  let y0 = y_floor.max(0).min(src.get_height() - 1)
  let x1 = (x_floor + 1).max(0).min(src.get_width() - 1)
  let y1 = (y_floor + 1).max(0).min(src.get_height() - 1)
  let tx = (x - x_floor.to_double()).max(0.0).min(1.0)
  let ty = (y - y_floor.to_double()).max(0.0).min(1.0)
  let c00 = src.get_pixel(x0, y0)
  let c10 = src.get_pixel(x1, y0)
  let c01 = src.get_pixel(x0, y1)
  let c11 = src.get_pixel(x1, y1)
  let alpha = bilinear_value(
    c00.a.to_int().to_double(),
    c10.a.to_int().to_double(),
    c01.a.to_int().to_double(),
    c11.a.to_int().to_double(),
    tx,
    ty,
  )
  Color::new(
    r=unpremul_channel(
      bilinear_value(
        premul_channel(c00.r, c00.a),
        premul_channel(c10.r, c10.a),
        premul_channel(c01.r, c01.a),
        premul_channel(c11.r, c11.a),
        tx,
        ty,
      ),
      alpha,
    ),
    g=unpremul_channel(
      bilinear_value(
        premul_channel(c00.g, c00.a),
        premul_channel(c10.g, c10.a),
        premul_channel(c01.g, c01.a),
        premul_channel(c11.g, c11.a),
        tx,
        ty,
      ),
      alpha,
    ),
    b=unpremul_channel(
      bilinear_value(
        premul_channel(c00.b, c00.a),
        premul_channel(c10.b, c10.a),
        premul_channel(c01.b, c01.a),
        premul_channel(c11.b, c11.a),
        tx,
        ty,
      ),
      alpha,
    ),
    a=round_to_byte(alpha),
  )
}

///|
fn sample_bilinear_rect(
  src : Pixmap,
  x : Double,
  y : Double,
  rect : PixelRect,
) -> Color {
  let x_floor = floor_to_int(x)
  let y_floor = floor_to_int(y)
  let left = rect.x.max(0).min(src.get_width() - 1)
  let top = rect.y.max(0).min(src.get_height() - 1)
  let right = rect.right().max(left + 1).min(src.get_width())
  let bottom = rect.bottom().max(top + 1).min(src.get_height())
  let x0 = x_floor.max(left).min(right - 1)
  let y0 = y_floor.max(top).min(bottom - 1)
  let x1 = (x_floor + 1).max(left).min(right - 1)
  let y1 = (y_floor + 1).max(top).min(bottom - 1)
  let tx = (x - x_floor.to_double()).max(0.0).min(1.0)
  let ty = (y - y_floor.to_double()).max(0.0).min(1.0)
  let c00 = src.get_pixel(x0, y0)
  let c10 = src.get_pixel(x1, y0)
  let c01 = src.get_pixel(x0, y1)
  let c11 = src.get_pixel(x1, y1)
  let alpha = bilinear_value(
    c00.a.to_int().to_double(),
    c10.a.to_int().to_double(),
    c01.a.to_int().to_double(),
    c11.a.to_int().to_double(),
    tx,
    ty,
  )
  Color::new(
    r=unpremul_channel(
      bilinear_value(
        premul_channel(c00.r, c00.a),
        premul_channel(c10.r, c10.a),
        premul_channel(c01.r, c01.a),
        premul_channel(c11.r, c11.a),
        tx,
        ty,
      ),
      alpha,
    ),
    g=unpremul_channel(
      bilinear_value(
        premul_channel(c00.g, c00.a),
        premul_channel(c10.g, c10.a),
        premul_channel(c01.g, c01.a),
        premul_channel(c11.g, c11.a),
        tx,
        ty,
      ),
      alpha,
    ),
    b=unpremul_channel(
      bilinear_value(
        premul_channel(c00.b, c00.a),
        premul_channel(c10.b, c10.a),
        premul_channel(c01.b, c01.a),
        premul_channel(c11.b, c11.a),
        tx,
        ty,
      ),
      alpha,
    ),
    a=round_to_byte(alpha),
  )
}

///|
fn sample_bicubic(src : Pixmap, x : Double, y : Double) -> Color {
  let x_floor = floor_to_int(x)
  let y_floor = floor_to_int(y)
  sample_bicubic_clamped(
    src,
    x_floor,
    y_floor,
    (x - x_floor.to_double()).max(0.0).min(1.0),
    (y - y_floor.to_double()).max(0.0).min(1.0),
    0,
    0,
    src.get_width(),
    src.get_height(),
  )
}

///|
fn sample_bicubic_rect(
  src : Pixmap,
  x : Double,
  y : Double,
  rect : PixelRect,
) -> Color {
  let x_floor = floor_to_int(x)
  let y_floor = floor_to_int(y)
  let left = rect.x.max(0).min(src.get_width() - 1)
  let top = rect.y.max(0).min(src.get_height() - 1)
  let right = rect.right().max(left + 1).min(src.get_width())
  let bottom = rect.bottom().max(top + 1).min(src.get_height())
  sample_bicubic_clamped(
    src,
    x_floor,
    y_floor,
    (x - x_floor.to_double()).max(0.0).min(1.0),
    (y - y_floor.to_double()).max(0.0).min(1.0),
    left,
    top,
    right,
    bottom,
  )
}

///|
fn sample_bicubic_clamped(
  src : Pixmap,
  x_floor : Int,
  y_floor : Int,
  tx : Double,
  ty : Double,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> Color {
  let x0 = (x_floor - 1).max(left).min(right - 1)
  let x1 = x_floor.max(left).min(right - 1)
  let x2 = (x_floor + 1).max(left).min(right - 1)
  let x3 = (x_floor + 2).max(left).min(right - 1)
  let y0 = (y_floor - 1).max(top).min(bottom - 1)
  let y1 = y_floor.max(top).min(bottom - 1)
  let y2 = (y_floor + 1).max(top).min(bottom - 1)
  let y3 = (y_floor + 2).max(top).min(bottom - 1)
  let c00 = src.get_pixel(x0, y0)
  let c10 = src.get_pixel(x1, y0)
  let c20 = src.get_pixel(x2, y0)
  let c30 = src.get_pixel(x3, y0)
  let c01 = src.get_pixel(x0, y1)
  let c11 = src.get_pixel(x1, y1)
  let c21 = src.get_pixel(x2, y1)
  let c31 = src.get_pixel(x3, y1)
  let c02 = src.get_pixel(x0, y2)
  let c12 = src.get_pixel(x1, y2)
  let c22 = src.get_pixel(x2, y2)
  let c32 = src.get_pixel(x3, y2)
  let c03 = src.get_pixel(x0, y3)
  let c13 = src.get_pixel(x1, y3)
  let c23 = src.get_pixel(x2, y3)
  let c33 = src.get_pixel(x3, y3)
  let alpha = bicubic_grid_value(
      c00.a.to_int().to_double(),
      c10.a.to_int().to_double(),
      c20.a.to_int().to_double(),
      c30.a.to_int().to_double(),
      c01.a.to_int().to_double(),
      c11.a.to_int().to_double(),
      c21.a.to_int().to_double(),
      c31.a.to_int().to_double(),
      c02.a.to_int().to_double(),
      c12.a.to_int().to_double(),
      c22.a.to_int().to_double(),
      c32.a.to_int().to_double(),
      c03.a.to_int().to_double(),
      c13.a.to_int().to_double(),
      c23.a.to_int().to_double(),
      c33.a.to_int().to_double(),
      tx,
      ty,
    )
    .max(0.0)
    .min(255.0)
  Color::new(
    r=unpremul_channel(
      clamp_premul_channel(
        bicubic_grid_value(
          premul_channel(c00.r, c00.a),
          premul_channel(c10.r, c10.a),
          premul_channel(c20.r, c20.a),
          premul_channel(c30.r, c30.a),
          premul_channel(c01.r, c01.a),
          premul_channel(c11.r, c11.a),
          premul_channel(c21.r, c21.a),
          premul_channel(c31.r, c31.a),
          premul_channel(c02.r, c02.a),
          premul_channel(c12.r, c12.a),
          premul_channel(c22.r, c22.a),
          premul_channel(c32.r, c32.a),
          premul_channel(c03.r, c03.a),
          premul_channel(c13.r, c13.a),
          premul_channel(c23.r, c23.a),
          premul_channel(c33.r, c33.a),
          tx,
          ty,
        ),
        alpha,
      ),
      alpha,
    ),
    g=unpremul_channel(
      clamp_premul_channel(
        bicubic_grid_value(
          premul_channel(c00.g, c00.a),
          premul_channel(c10.g, c10.a),
          premul_channel(c20.g, c20.a),
          premul_channel(c30.g, c30.a),
          premul_channel(c01.g, c01.a),
          premul_channel(c11.g, c11.a),
          premul_channel(c21.g, c21.a),
          premul_channel(c31.g, c31.a),
          premul_channel(c02.g, c02.a),
          premul_channel(c12.g, c12.a),
          premul_channel(c22.g, c22.a),
          premul_channel(c32.g, c32.a),
          premul_channel(c03.g, c03.a),
          premul_channel(c13.g, c13.a),
          premul_channel(c23.g, c23.a),
          premul_channel(c33.g, c33.a),
          tx,
          ty,
        ),
        alpha,
      ),
      alpha,
    ),
    b=unpremul_channel(
      clamp_premul_channel(
        bicubic_grid_value(
          premul_channel(c00.b, c00.a),
          premul_channel(c10.b, c10.a),
          premul_channel(c20.b, c20.a),
          premul_channel(c30.b, c30.a),
          premul_channel(c01.b, c01.a),
          premul_channel(c11.b, c11.a),
          premul_channel(c21.b, c21.a),
          premul_channel(c31.b, c31.a),
          premul_channel(c02.b, c02.a),
          premul_channel(c12.b, c12.a),
          premul_channel(c22.b, c22.a),
          premul_channel(c32.b, c32.a),
          premul_channel(c03.b, c03.a),
          premul_channel(c13.b, c13.a),
          premul_channel(c23.b, c23.a),
          premul_channel(c33.b, c33.a),
          tx,
          ty,
        ),
        alpha,
      ),
      alpha,
    ),
    a=round_to_byte(alpha),
  )
}

///|
fn floor_to_int(value : Double) -> Int {
  let truncated = value.to_int()
  if truncated.to_double() > value {
    truncated - 1
  } else {
    truncated
  }
}

///|
fn positive_mod(value : Int, modulus : Int) -> Int {
  guard modulus > 0 else { return 0 }
  let mut result = value % modulus
  if result < 0 {
    result = result + modulus
  }
  result
}

///|
fn bilinear_value(
  v00 : Double,
  v10 : Double,
  v01 : Double,
  v11 : Double,
  tx : Double,
  ty : Double,
) -> Double {
  let top = v00 * (1.0 - tx) + v10 * tx
  let bottom = v01 * (1.0 - tx) + v11 * tx
  top * (1.0 - ty) + bottom * ty
}

///|
fn bicubic_grid_value(
  v00 : Double,
  v10 : Double,
  v20 : Double,
  v30 : Double,
  v01 : Double,
  v11 : Double,
  v21 : Double,
  v31 : Double,
  v02 : Double,
  v12 : Double,
  v22 : Double,
  v32 : Double,
  v03 : Double,
  v13 : Double,
  v23 : Double,
  v33 : Double,
  tx : Double,
  ty : Double,
) -> Double {
  bicubic_value(
    bicubic_value(v00, v10, v20, v30, tx),
    bicubic_value(v01, v11, v21, v31, tx),
    bicubic_value(v02, v12, v22, v32, tx),
    bicubic_value(v03, v13, v23, v33, tx),
    ty,
  )
}

///|
fn bicubic_value(
  v0 : Double,
  v1 : Double,
  v2 : Double,
  v3 : Double,
  t : Double,
) -> Double {
  let t2 = t * t
  let t3 = t2 * t
  0.5 *
  (
    2.0 * v1 +
    (v2 - v0) * t +
    (2.0 * v0 - 5.0 * v1 + 4.0 * v2 - v3) * t2 +
    (-v0 + 3.0 * v1 - 3.0 * v2 + v3) * t3
  )
}

///|
fn premul_channel(channel : Byte, alpha : Byte) -> Double {
  channel.to_int().to_double() * alpha.to_int().to_double() / 255.0
}

///|
fn clamp_premul_channel(premul : Double, alpha : Double) -> Double {
  premul.max(0.0).min(alpha)
}

///|
fn unpremul_channel(premul : Double, alpha : Double) -> Byte {
  guard alpha > 0.0 else { return clamp_byte(0) }
  round_to_byte(premul * 255.0 / alpha)
}

///|
fn round_to_byte(value : Double) -> Byte {
  clamp_byte((value + 0.5).to_int())
}
