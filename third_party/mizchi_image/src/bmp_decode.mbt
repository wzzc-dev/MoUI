///|
fn read_u32le(data : Bytes, offset : Int) -> UInt {
  let b0 = data[offset].to_int() & 0xFF
  let b1 = data[offset + 1].to_int() & 0xFF
  let b2 = data[offset + 2].to_int() & 0xFF
  let b3 = data[offset + 3].to_int() & 0xFF
  (b3 << 24).lor(b2 << 16).lor(b1 << 8).lor(b0).reinterpret_as_uint()
}

///|
fn read_i32le(data : Bytes, offset : Int) -> Int {
  let b0 = data[offset].to_int() & 0xFF
  let b1 = data[offset + 1].to_int() & 0xFF
  let b2 = data[offset + 2].to_int() & 0xFF
  let b3 = data[offset + 3].to_int() & 0xFF
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
fn read_u16le(data : Bytes, offset : Int) -> Int {
  let b0 = data[offset].to_int() & 0xFF
  let b1 = data[offset + 1].to_int() & 0xFF
  (b1 << 8) | b0
}

///|
priv struct BmpDecodeInfo {
  width : Int
  height : Int
  bpp : Int
  bytes_per_px : Int
  pixel_offset : Int
  padded_row_size : Int
  top_down : Bool
}

///|
fn parse_bmp_info(raw : Bytes) -> BmpDecodeInfo raise DecodeError {
  if raw.length() < 54 {
    raise CorruptData("BMP file too short")
  }
  if raw[0] != b'\x42' || raw[1] != b'\x4D' {
    raise InvalidSignature("not a BMP file")
  }
  let pixel_offset = read_u32le(raw, 10).reinterpret_as_int()
  let dib_size = read_u32le(raw, 14).reinterpret_as_int()
  if dib_size < 40 {
    raise UnsupportedFeature(
      "unsupported DIB header size: " + dib_size.to_string(),
    )
  }
  let width = read_i32le(raw, 18)
  let raw_height = read_i32le(raw, 22)
  let top_down = raw_height < 0
  let height = if top_down { 0 - raw_height } else { raw_height }
  if width <= 0 || height <= 0 {
    raise CorruptData("invalid BMP dimensions")
  }
  let bpp = read_u16le(raw, 28)
  let compression = read_u32le(raw, 30).reinterpret_as_int()
  if compression != 0 {
    raise UnsupportedFeature(
      "compressed BMP not supported (compression=" +
      compression.to_string() +
      ")",
    )
  }
  if bpp != 24 && bpp != 32 {
    raise UnsupportedFeature(
      "unsupported BMP bits per pixel: " + bpp.to_string(),
    )
  }
  let bytes_per_px = bpp / 8
  let row_size = width * bytes_per_px
  let padded_row_size = (row_size + 3) / 4 * 4
  let required_size = pixel_offset + padded_row_size * height
  if raw.length() < required_size {
    raise CorruptData("BMP file too short for pixel data")
  }

  { width, height, bpp, bytes_per_px, pixel_offset, padded_row_size, top_down }
}

///|
fn decode_bmp_rows(
  raw : Bytes,
  info : BmpDecodeInfo,
  on_row : (Int, Bytes) -> Unit,
) -> Unit {
  for y in 0..<info.height {
    let src_y = if info.top_down { y } else { info.height - 1 - y }
    let src_row_offset = info.pixel_offset + src_y * info.padded_row_size
    let row_buf = FixedArray::make(info.width * 4, b'\x00')
    for x in 0..<info.width {
      let src_idx = src_row_offset + x * info.bytes_per_px
      let dst_idx = x * 4
      let b_val = raw[src_idx]
      let g_val = raw[src_idx + 1]
      let r_val = raw[src_idx + 2]
      let a_val : Byte = if info.bpp == 32 { raw[src_idx + 3] } else { b'\xFF' }
      row_buf[dst_idx] = r_val
      row_buf[dst_idx + 1] = g_val
      row_buf[dst_idx + 2] = b_val
      row_buf[dst_idx + 3] = a_val
    }
    on_row(y, Bytes::from_array(row_buf))
  }
}

///|
pub fn decode_bmp_stream(
  raw : Bytes,
  on_row~ : (Int, Bytes) -> Unit,
) -> (Int, Int) raise DecodeError {
  let info = parse_bmp_info(raw)
  decode_bmp_rows(raw, info, on_row)
  (info.width, info.height)
}

///|
pub fn decode_bmp(raw : Bytes) -> ImageData raise DecodeError {
  let info = parse_bmp_info(raw)
  let rgba_buf = FixedArray::make(info.width * info.height * 4, b'\x00')
  decode_bmp_rows(raw, info, fn(y, row) {
    let dst_offset = y * info.width * 4
    rgba_buf.blit_from_bytes(dst_offset, row, 0, info.width * 4)
  })
  { width: info.width, height: info.height, data: Bytes::from_array(rgba_buf) }
}
