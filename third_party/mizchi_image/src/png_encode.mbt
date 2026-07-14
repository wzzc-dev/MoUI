///|
fn write_u32be(buf : FixedArray[Byte], offset : Int, value : UInt) -> Unit {
  buf[offset] = (value >> 24).land(0xFFU).to_byte()
  buf[offset + 1] = (value >> 16).land(0xFFU).to_byte()
  buf[offset + 2] = (value >> 8).land(0xFFU).to_byte()
  buf[offset + 3] = value.land(0xFFU).to_byte()
}

///|
fn encode_chunk(chunk_type : FixedArray[Byte], data : Bytes) -> Bytes {
  let len = data.length()
  let total = 12 + len
  let buf = FixedArray::make(total, b'\x00')
  // Length
  write_u32be(buf, 0, len.reinterpret_as_uint())
  // Type
  buf[4] = chunk_type[0]
  buf[5] = chunk_type[1]
  buf[6] = chunk_type[2]
  buf[7] = chunk_type[3]
  // Data
  buf.blit_from_bytes(8, data, 0, len)
  // CRC over type + data
  let crc_input = FixedArray::make(4 + len, b'\x00')
  chunk_type.blit_to(crc_input, len=4)
  crc_input.blit_from_bytes(4, data, 0, len)
  let crc = @zlib.crc32_fixed(crc_input)
  write_u32be(buf, 8 + len, crc)
  Bytes::from_array(buf)
}

///|
pub fn encode_png(img : ImageData) -> Bytes raise EncodeError {
  let width = img.width
  let height = img.height
  if width <= 0 || height <= 0 {
    raise InvalidDimensions(
      "width and height must be positive: " +
      width.to_string() +
      "x" +
      height.to_string(),
    )
  }
  let expected_len = width * height * 4
  if img.data.length() != expected_len {
    raise InvalidData(
      "expected " +
      expected_len.to_string() +
      " bytes, got " +
      img.data.length().to_string(),
    )
  }
  // Build signature
  let sig = FixedArray::make(8, b'\x00')
  sig[0] = b'\x89'
  sig[1] = b'\x50'
  sig[2] = b'\x4E'
  sig[3] = b'\x47'
  sig[4] = b'\x0D'
  sig[5] = b'\x0A'
  sig[6] = b'\x1A'
  sig[7] = b'\x0A'
  // IHDR data: 13 bytes
  let ihdr_data = FixedArray::make(13, b'\x00')
  write_u32be(ihdr_data, 0, width.reinterpret_as_uint())
  write_u32be(ihdr_data, 4, height.reinterpret_as_uint())
  ihdr_data[8] = b'\x08' // bit depth 8
  ihdr_data[9] = b'\x06' // color type 6 (RGBA)
  // compression=0, filter=0, interlace=0 already zero
  let ihdr_chunk = encode_chunk(
    [b'\x49', b'\x48', b'\x44', b'\x52'],
    Bytes::from_array(ihdr_data),
  )
  // Build raw scanlines with adaptive filtering
  let stride = width * 4
  let bpp = 4
  let raw_len = height * (1 + stride)
  let raw = FixedArray::make(raw_len, b'\x00')
  let mut prev_row = Bytes::new(stride)
  for y in 0..<height {
    let raw_offset = y * (1 + stride)
    let src_offset = y * stride
    let row_buf = FixedArray::make(stride, b'\x00')
    row_buf.blit_from_bytes(0, img.data, src_offset, stride)
    let row = Bytes::from_array(row_buf)
    let (filter_type, filtered) = select_best_filter(row, prev_row, bpp)
    raw[raw_offset] = filter_type.to_byte()
    for i in 0..<stride {
      raw[raw_offset + 1 + i] = filtered[i]
    }
    prev_row = row
  }
  let compressed = @zlib.zlib_compress(Bytes::from_array(raw))
  let idat_chunk = encode_chunk(
    [b'\x49', b'\x44', b'\x41', b'\x54'],
    compressed,
  )
  // IEND
  let iend_chunk = encode_chunk(
    [b'\x49', b'\x45', b'\x4E', b'\x44'],
    Bytes::new(0),
  )
  // Concatenate all parts
  let total_len = 8 +
    ihdr_chunk.length() +
    idat_chunk.length() +
    iend_chunk.length()
  let result = FixedArray::make(total_len, b'\x00')
  let mut pos = 0
  // Signature
  sig.blit_to(result, len=8)
  pos += 8
  // IHDR
  result.blit_from_bytes(pos, ihdr_chunk, 0, ihdr_chunk.length())
  pos += ihdr_chunk.length()
  // IDAT
  result.blit_from_bytes(pos, idat_chunk, 0, idat_chunk.length())
  pos += idat_chunk.length()
  // IEND
  result.blit_from_bytes(pos, iend_chunk, 0, iend_chunk.length())
  pos += iend_chunk.length()
  ignore(pos)
  Bytes::from_array(result)
}

///|
test "encode_png basic" {
  let img : ImageData = { width: 1, height: 1, data: b"\xFF\x00\x00\xFF" }
  let png = encode_png(img)
  // Should start with PNG signature
  assert_eq(png[0].to_int(), 0x89)
  assert_eq(png[1].to_int(), 0x50)
  assert_eq(png[2].to_int(), 0x4E)
  assert_eq(png[3].to_int(), 0x47)
}

///|
test "encode_png roundtrip 1x1" {
  let original : ImageData = { width: 1, height: 1, data: b"\xFF\x00\x80\xC0" }
  let png = encode_png(original)
  let decoded = decode_png(png) catch { _ => panic() }
  assert_eq(decoded.width, original.width)
  assert_eq(decoded.height, original.height)
  assert_eq(decoded.data, original.data)
}

///|
test "encode_png roundtrip 4x4" {
  let width = 4
  let height = 4
  let buf = FixedArray::make(width * height * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * 4
      buf[idx] = (x * 64).to_byte() // R
      buf[idx + 1] = (y * 64).to_byte() // G
      buf[idx + 2] = ((x + y) * 32).to_byte() // B
      buf[idx + 3] = b'\xFF' // A
    }
  }
  let original : ImageData = { width, height, data: Bytes::from_array(buf) }
  let png = encode_png(original)
  let decoded = decode_png(png) catch { _ => panic() }
  assert_eq(decoded.width, original.width)
  assert_eq(decoded.height, original.height)
  assert_eq(decoded.data, original.data)
}

///|
test "encode_png invalid dimensions" {
  let img : ImageData = { width: 0, height: 1, data: Bytes::new(0) }
  let mut got_error = false
  try {
    let _ = encode_png(img)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}

///|
test "encode_png invalid data length" {
  let img : ImageData = { width: 2, height: 2, data: Bytes::new(4) }
  let mut got_error = false
  try {
    let _ = encode_png(img)
  } catch {
    _ => got_error = true
  }
  assert_true(got_error)
}
