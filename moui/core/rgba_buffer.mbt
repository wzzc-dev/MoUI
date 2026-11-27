///|
/// A writable, renderer-neutral RGBA8 pixel buffer.
///
/// Pixels are stored as straight (non-premultiplied) RGBA in row-major order.
/// This is the framework's one neutral pixel buffer: hosts, renderers, and
/// domain addons keep their own naming on top of it instead of adding another
/// frame type. Draw it by wrapping the encoded bytes in a source
/// (`to_png_bytes` yields a PNG the renderer image path can decode) and
/// emitting `DrawCommand::DrawImage`.
pub(all) struct RgbaBuffer {
  width : Int32
  height : Int32
  pixels : FixedArray[Byte]
}

///|
pub fn RgbaBuffer::new(
  width~ : Int32,
  height~ : Int32,
  fill~ : Color = Color::transparent(),
) -> RgbaBuffer {
  let width = width.max(0)
  let height = height.max(0)
  let buffer = {
    width,
    height,
    pixels: FixedArray::make(width * height * 4, (0 : Byte)),
  }
  buffer.fill(fill)
  buffer
}

///|
pub fn RgbaBuffer::row_bytes(self : RgbaBuffer) -> Int32 {
  self.width * 4
}

///|
pub fn RgbaBuffer::is_empty(self : RgbaBuffer) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
/// Wraps existing straight RGBA bytes. Returns `None` when the dimensions and
/// buffer length do not match.
pub fn RgbaBuffer::from_rgba(
  width~ : Int32,
  height~ : Int32,
  pixels~ : FixedArray[Byte],
) -> RgbaBuffer? {
  if width < 0 || height < 0 || pixels.length() != width * height * 4 {
    None
  } else {
    Some({ width, height, pixels, })
  }
}

///|
pub fn RgbaBuffer::copy(self : RgbaBuffer) -> RgbaBuffer {
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
pub fn RgbaBuffer::fill(self : RgbaBuffer, color : Color) -> Unit {
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
pub fn RgbaBuffer::set(
  self : RgbaBuffer,
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
pub fn RgbaBuffer::get(self : RgbaBuffer, x : Int32, y : Int32) -> Color {
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

///|
fn png_encode_crc32(data : Bytes) -> UInt32 {
  let mut crc = 0xFFFFFFFFU
  for index in 0..<data.length() {
    crc = crc ^ data[index].to_uint()
    for _ in 0..<8 {
      if (crc & 1U) == 1U {
        crc = (crc >> 1) ^ 0xEDB88320U
      } else {
        crc = crc >> 1
      }
    }
  }
  crc ^ 0xFFFFFFFFU
}

///|
fn png_encode_chunk(out : @buffer.Buffer, kind : Bytes, data : Bytes) -> Unit {
  out.write_int_be(data.length())
  let crc_input = @buffer.Buffer()
  crc_input.write_bytesview(kind)
  crc_input.write_bytesview(data)
  out.write_bytesview(kind)
  out.write_bytesview(data)
  out.write_uint_be(png_encode_crc32(crc_input.to_bytes()))
}

///|
/// Encodes the buffer as an 8-bit straight-RGBA, non-interlaced PNG (filter 0
/// rows). This is the framework's one public PNG encode entry: it takes the
/// width/height from the buffer and returns the encoded bytes, so callers do
/// not need a renderer or a concrete codec package. Domain addons that own
/// their own codec naming (for example `moui_p5`) may delegate here.
pub fn RgbaBuffer::to_png_bytes(self : RgbaBuffer) -> Bytes {
  let width = self.width
  let height = self.height
  let raw = @buffer.Buffer()
  for y in 0..<height {
    raw.write_byte(b'\x00')
    let base = y * width * 4
    for offset in 0..<(width * 4) {
      raw.write_byte(self.pixels[base + offset])
    }
  }
  let idat = @zlib.compress(raw.to_bytes()[:])
  let ihdr = @buffer.Buffer()
  ihdr.write_int_be(width)
  ihdr.write_int_be(height)
  ihdr.write_byte(b'\x08')
  ihdr.write_byte(b'\x06')
  ihdr.write_byte(b'\x00')
  ihdr.write_byte(b'\x00')
  ihdr.write_byte(b'\x00')
  let out = @buffer.Buffer()
  out.write_bytesview(b"\x89PNG\r\n\x1a\n")
  png_encode_chunk(out, b"IHDR", ihdr.to_bytes())
  png_encode_chunk(out, b"IDAT", idat)
  png_encode_chunk(out, b"IEND", b"")
  out.to_bytes()
}
