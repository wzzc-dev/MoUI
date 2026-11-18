///|
/// PNG encoding for `Image`: 8-bit straight RGBA, non-interlaced, filter 0
/// rows. The output is the same byte format `from_png_bytes` accepts, and the
/// MoUI adapter reuses it for `DrawImage` data URIs.

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
  crc_input.write_bytes(kind)
  crc_input.write_bytes(data)
  out.write_bytes(kind)
  out.write_bytes(data)
  out.write_uint_be(png_encode_crc32(crc_input.to_bytes()))
}

///|
/// Encodes the image as an 8-bit RGBA PNG.
pub fn Image::to_png_bytes(self : Image) -> Bytes {
  let width = self.width_
  let height = self.height_
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
  out.write_bytes(b"\x89PNG\r\n\x1a\n")
  png_encode_chunk(out, b"IHDR", ihdr.to_bytes())
  png_encode_chunk(out, b"IDAT", idat)
  png_encode_chunk(out, b"IEND", b"")
  out.to_bytes()
}

///|
/// Writes the image to `path` as a PNG. Returns false when the path cannot be
/// written (for example on a wasm host without filesystem access).
pub fn Image::save(self : Image, path : String) -> Bool {
  try {
    @fs.write_bytes_to_file(path, self.to_png_bytes())
    true
  } catch {
    _ => false
  }
}
