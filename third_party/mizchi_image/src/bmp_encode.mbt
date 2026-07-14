///|
fn write_u32le(buf : FixedArray[Byte], offset : Int, value : UInt) -> Unit {
  buf[offset] = value.land(0xFFU).to_byte()
  buf[offset + 1] = (value >> 8).land(0xFFU).to_byte()
  buf[offset + 2] = (value >> 16).land(0xFFU).to_byte()
  buf[offset + 3] = (value >> 24).land(0xFFU).to_byte()
}

///|
fn write_u16le(buf : FixedArray[Byte], offset : Int, value : Int) -> Unit {
  buf[offset] = (value & 0xFF).to_byte()
  buf[offset + 1] = ((value >> 8) & 0xFF).to_byte()
}

///|
fn write_i32le(buf : FixedArray[Byte], offset : Int, value : Int) -> Unit {
  write_u32le(buf, offset, value.reinterpret_as_uint())
}

///|
pub fn encode_bmp(img : ImageData) -> Bytes raise EncodeError {
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
  let row_size = width * 4
  let pixel_data_size = row_size * height
  let file_size = 54 + pixel_data_size
  let pixel_offset = 54
  let buf = FixedArray::make(file_size, b'\x00')
  // File header (14 bytes)
  buf[0] = b'\x42' // 'B'
  buf[1] = b'\x4D' // 'M'
  write_u32le(buf, 2, file_size.reinterpret_as_uint())
  write_u32le(buf, 10, pixel_offset.reinterpret_as_uint())
  // DIB header (BITMAPINFOHEADER, 40 bytes)
  write_u32le(buf, 14, 40U)
  write_i32le(buf, 18, width)
  write_i32le(buf, 22, height)
  write_u16le(buf, 26, 1) // planes
  write_u16le(buf, 28, 32) // bits per pixel
  write_u32le(buf, 34, pixel_data_size.reinterpret_as_uint())
  // Pixel data (bottom-up, BGRA)
  for y in 0..<height {
    let src_y = height - 1 - y
    let src_offset = src_y * width * 4
    let dst_offset = pixel_offset + y * row_size
    for x in 0..<width {
      let si = src_offset + x * 4
      let di = dst_offset + x * 4
      buf[di] = img.data[si + 2] // B
      buf[di + 1] = img.data[si + 1] // G
      buf[di + 2] = img.data[si] // R
      buf[di + 3] = img.data[si + 3] // A
    }
  }
  Bytes::from_array(buf)
}
