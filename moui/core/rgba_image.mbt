///|
/// A writable, renderer-neutral RGBA8 image buffer.
///
/// Pixels are stored as straight (non-premultiplied) RGBA in row-major order.
/// Draw it by wrapping the bytes in an encoded source (the p5 adapter uses a
/// PNG data URI) and emitting `DrawCommand::DrawImage`; renderers without a
/// raw-pixel command can still decode the same source through their image path.
pub(all) struct RgbaImage {
  width : Int32
  height : Int32
  pixels : FixedArray[Byte]
}

///|
pub fn RgbaImage::new(
  width~ : Int32,
  height~ : Int32,
  fill~ : Color = Color::transparent(),
) -> RgbaImage {
  let width = width.max(0)
  let height = height.max(0)
  let image = {
    width,
    height,
    pixels: FixedArray::make(width * height * 4, (0 : Byte)),
  }
  image.fill(fill)
  image
}

///|
pub fn RgbaImage::row_bytes(self : RgbaImage) -> Int32 {
  self.width * 4
}

///|
pub fn RgbaImage::is_empty(self : RgbaImage) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
/// Wraps existing straight RGBA bytes. Returns `None` when the dimensions and
/// buffer length do not match.
pub fn RgbaImage::from_rgba(
  width~ : Int32,
  height~ : Int32,
  pixels~ : FixedArray[Byte],
) -> RgbaImage? {
  if width < 0 || height < 0 || pixels.length() != width * height * 4 {
    None
  } else {
    Some({ width, height, pixels, })
  }
}

///|
pub fn RgbaImage::copy(self : RgbaImage) -> RgbaImage {
  { width: self.width, height: self.height, pixels: self.pixels.copy(), }
}

///|
fn rgba_byte(value : Double) -> Byte {
  (value.max(0.0).min(1.0) * 255.0 + 0.5).to_int().to_byte()
}

///|
fn rgba_unit(value : Byte) -> Double {
  value.to_uint().to_double() / 255.0
}

///|
pub fn RgbaImage::fill(self : RgbaImage, color : Color) -> Unit {
  let r = rgba_byte(color.r)
  let g = rgba_byte(color.g)
  let b = rgba_byte(color.b)
  let a = rgba_byte(color.a)
  let mut offset = 0
  while offset + 3 < self.pixels.length() {
    self.pixels[offset] = r
    self.pixels[offset + 1] = g
    self.pixels[offset + 2] = b
    self.pixels[offset + 3] = a
    offset = offset + 4
  }
}

///|
pub fn RgbaImage::set(
  self : RgbaImage,
  x : Int32,
  y : Int32,
  color : Color,
) -> Unit {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return
  }
  let offset = (y * self.width + x) * 4
  self.pixels[offset] = rgba_byte(color.r)
  self.pixels[offset + 1] = rgba_byte(color.g)
  self.pixels[offset + 2] = rgba_byte(color.b)
  self.pixels[offset + 3] = rgba_byte(color.a)
}

///|
pub fn RgbaImage::get(self : RgbaImage, x : Int32, y : Int32) -> Color {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return Color::transparent()
  }
  let offset = (y * self.width + x) * 4
  Color::rgba(
    r=rgba_unit(self.pixels[offset]),
    g=rgba_unit(self.pixels[offset + 1]),
    b=rgba_unit(self.pixels[offset + 2]),
    a=rgba_unit(self.pixels[offset + 3]),
  )
}
