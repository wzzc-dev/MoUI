///|
// 1x1 red RGBA PNG generated with known-good encoder
// This is a minimal valid PNG with a single red pixel (255, 0, 0, 255)
test "decode_png 1x1 red pixel" {
  // Build a 1x1 RGBA PNG manually
  // Signature
  let sig = b"\x89\x50\x4E\x47\x0D\x0A\x1A\x0A"
  // IHDR: width=1, height=1, bit_depth=8, color_type=6(RGBA), compression=0, filter=0, interlace=0
  let ihdr_data = b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00"
  let ihdr_chunk = make_chunk(b"\x49\x48\x44\x52", ihdr_data)
  // IDAT: filter=0(None), then RGBA pixel: 255, 0, 0, 255
  let raw_scanline = b"\x00\xFF\x00\x00\xFF"
  let compressed = @zlib.zlib_compress(raw_scanline)
  let idat_chunk = make_chunk(b"\x49\x44\x41\x54", compressed)
  // IEND
  let iend_chunk = make_chunk(b"\x49\x45\x4E\x44", b"")
  let png = concat_bytes([sig, ihdr_chunk, idat_chunk, iend_chunk])
  let img = decode_png(png)
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.data.length(), 4)
  // Red pixel: RGBA = 255, 0, 0, 255
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
  assert_eq(img.data[3].to_int(), 255)
}

///|
test "decode_png 2x2 gradient" {
  let ihdr_data = b"\x00\x00\x00\x02\x00\x00\x00\x02\x08\x06\x00\x00\x00"
  let ihdr_chunk = make_chunk(b"\x49\x48\x44\x52", ihdr_data)
  // 2x2 RGBA image:
  // Row 0: filter=0, pixel(255,0,0,255), pixel(0,255,0,255)
  // Row 1: filter=0, pixel(0,0,255,255), pixel(255,255,255,255)
  let raw = b"\x00\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF"
  let compressed = @zlib.zlib_compress(raw)
  let idat_chunk = make_chunk(b"\x49\x44\x41\x54", compressed)
  let iend_chunk = make_chunk(b"\x49\x45\x4E\x44", b"")
  let png = concat_bytes([
    b"\x89\x50\x4E\x47\x0D\x0A\x1A\x0A", ihdr_chunk, idat_chunk, iend_chunk,
  ])
  let img = decode_png(png)
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.data.length(), 16)
  // pixel(0,0) = red
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
  assert_eq(img.data[3].to_int(), 255)
  // pixel(1,1) = white
  assert_eq(img.data[12].to_int(), 255)
  assert_eq(img.data[13].to_int(), 255)
  assert_eq(img.data[14].to_int(), 255)
  assert_eq(img.data[15].to_int(), 255)
}

///|
test "decode_png invalid signature" {
  let data = b"\x00\x00\x00\x00\x00\x00\x00\x00"
  let mut got_error = false
  try {
    let _ = decode_png(data)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}

///|
// Helper: build a PNG chunk (length + type + data + crc)
fn make_chunk(chunk_type : Bytes, data : Bytes) -> Bytes {
  let len = data.length()
  // Length (4 bytes big-endian)
  let len_bytes = FixedArray::make(4, b'\x00')
  len_bytes[0] = (len.reinterpret_as_uint() >> 24)
    .reinterpret_as_int()
    .land(0xFF)
    .to_byte()
  len_bytes[1] = (len.reinterpret_as_uint() >> 16)
    .reinterpret_as_int()
    .land(0xFF)
    .to_byte()
  len_bytes[2] = (len.reinterpret_as_uint() >> 8)
    .reinterpret_as_int()
    .land(0xFF)
    .to_byte()
  len_bytes[3] = len.land(0xFF).to_byte()
  // CRC over type + data
  let crc_input = FixedArray::make(4 + len, b'\x00')
  crc_input.blit_from_bytes(0, chunk_type, 0, 4)
  crc_input.blit_from_bytes(4, data, 0, len)
  let crc = @zlib.crc32_fixed(crc_input)
  let crc_bytes = FixedArray::make(4, b'\x00')
  crc_bytes[0] = (crc >> 24).land(0xFFU).to_byte()
  crc_bytes[1] = (crc >> 16).land(0xFFU).to_byte()
  crc_bytes[2] = (crc >> 8).land(0xFFU).to_byte()
  crc_bytes[3] = crc.land(0xFFU).to_byte()
  concat_bytes([
    Bytes::from_array(len_bytes),
    chunk_type,
    data,
    Bytes::from_array(crc_bytes),
  ])
}

///|
fn concat_bytes(parts : Array[Bytes]) -> Bytes {
  let total = parts.fold(init=0, fn(acc, b) { acc + b.length() })
  let buf = FixedArray::make(total, b'\x00')
  let mut offset = 0
  for part in parts {
    buf.blit_from_bytes(offset, part, 0, part.length())
    offset += part.length()
  }
  Bytes::from_array(buf)
}
