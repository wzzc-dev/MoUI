///|
pub fn SunRasterRenderer::draw_platform_view_pixels(
  self : SunRasterRenderer,
  pixels : Bytes,
  src_width : Int,
  src_height : Int,
  src_stride : Int,
  dst_x : Double,
  dst_y : Double,
  dst_width : Double,
  dst_height : Double,
) -> Unit {
  guard src_width > 0 && src_height > 0 && src_stride >= src_width * 4 else {
    return
  }
  guard dst_width > 0.0 && dst_height > 0.0 else { return }
  let packed = sun_tightly_packed_rgba(
    pixels,
    width=src_width,
    height=src_height,
    stride=src_stride,
  )
  match @sun_graphics.Pixmap::from_rgba_bytes(src_width, src_height, packed) {
    Ok(pixmap) =>
      self.canvas.draw_transformed_quality_pixmap_rect(
        pixmap,
        @sun_graphics.PixelRect::new(
          x=0,
          y=0,
          width=src_width,
          height=src_height,
        ),
        dst_x,
        dst_y,
        dst_width,
        dst_height,
        @sun_graphics.Paint::new(),
        @sun_graphics.ImageQuality::Balanced,
      )
    Err(_) => ()
  }
}

///|
pub fn SunRasterRenderer::set_platform_view_draw_fn(
  self : SunRasterRenderer,
  draw_fn : (() -> Unit)?,
) -> Unit {
  self.platform_view_draw_fn = draw_fn
}

///|
fn sun_tightly_packed_rgba(
  pixels : Bytes,
  width~ : Int,
  height~ : Int,
  stride~ : Int,
) -> Bytes {
  let row_bytes = width * 4
  if stride == row_bytes && pixels.length() == row_bytes * height {
    pixels
  } else {
    let packed : Array[Byte] = []
    for y in 0..<height {
      let row_start = y * stride
      for x in 0..<row_bytes {
        let index = row_start + x
        if index < pixels.length() {
          packed.push(pixels[index])
        } else {
          packed.push(0)
        }
      }
    }
    Bytes::from_array(packed)
  }
}
