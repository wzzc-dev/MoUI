///|
/// Minimal PNG encoder for screenshots captured by the offscreen renderer.
///
/// `moui screenshot` receives raw RGBA rows from a generated render package;
/// this module adds the PNG container (signature, IHDR, IDAT, IEND) and deflates
/// the scanlines through the toolchain's zlib. Scanlines use filter 0 so the
/// bytes are exactly what the renderer produced, keeping the encoder small and
/// deterministic.

///|
/// CRC-32 (ISO-HDLC) over a byte buffer, the checksum PNG chunks carry.
fn png_crc32(data : Bytes) -> UInt32 {
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
fn png_write_signature(out : @buffer.Buffer) -> Unit {
  out.write_bytes(b"\x89PNG\r\n\x1a\n")
}

///|
fn png_write_chunk(out : @buffer.Buffer, kind : Bytes, data : Bytes) -> Unit {
  out.write_int_be(data.length())
  let crc_input = @buffer.Buffer()
  crc_input.write_bytes(kind)
  crc_input.write_bytes(data)
  let crc = png_crc32(crc_input.to_bytes())
  out.write_bytes(kind)
  out.write_bytes(data)
  out.write_uint_be(crc)
}

///|
/// Encode `pixels` (RGBA, `row_bytes` may include padding) as an 8-bit RGBA PNG.
fn png_encode_rgba(
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
) -> Bytes raise {
  guard width > 0 && height > 0 else {
    fail("png_encode_rgba: width and height must be positive")
  }
  guard row_bytes >= width * 4 else {
    fail("png_encode_rgba: row_bytes must hold a full RGBA row")
  }
  let required = row_bytes * height
  guard pixels.length() >= required else {
    fail("png_encode_rgba: pixel buffer is shorter than row_bytes * height")
  }
  let raw = @buffer.Buffer()
  for y in 0..<height {
    raw.write_byte(b'\x00')
    let start = y * row_bytes
    if row_bytes == width * 4 {
      raw.write_bytes(pixels[start:start + width * 4])
    } else {
      for x in 0..<(width * 4) {
        raw.write_byte(pixels[start + x])
      }
    }
  }
  let idat = @zlib.compress(raw.to_bytes()[:])
  let ihdr = @buffer.Buffer()
  ihdr.write_int_be(width)
  ihdr.write_int_be(height)
  ihdr.write_byte(b'\x08') // bit depth
  ihdr.write_byte(b'\x06') // color type: RGBA
  ihdr.write_byte(b'\x00') // compression
  ihdr.write_byte(b'\x00') // filter
  ihdr.write_byte(b'\x00') // interlace
  let out = @buffer.Buffer()
  png_write_signature(out)
  png_write_chunk(out, b"IHDR", ihdr.to_bytes())
  png_write_chunk(out, b"IDAT", idat)
  png_write_chunk(out, b"IEND", b"")
  out.to_bytes()
}
