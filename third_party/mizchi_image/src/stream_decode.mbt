///|
fn is_png_signature(raw : Bytes) -> Bool {
  if raw.length() < 8 {
    return false
  }
  for i in 0..<8 {
    if raw[i] != png_signature[i] {
      return false
    }
  }
  true
}

///|
fn is_bmp_signature(raw : Bytes) -> Bool {
  raw.length() >= 2 && raw[0] == b'\x42' && raw[1] == b'\x4D'
}

///|
pub fn decode_image_stream(
  raw : Bytes,
  on_row~ : (Int, Bytes) -> Unit,
) -> StreamImageInfo raise DecodeError {
  if is_png_signature(raw) {
    let ihdr = decode_png_stream(raw, on_row~)
    return { format: Png, width: ihdr.width, height: ihdr.height }
  }
  if is_bmp_signature(raw) {
    let (width, height) = decode_bmp_stream(raw, on_row~)
    return { format: Bmp, width, height }
  }
  raise InvalidSignature("unknown image format")
}
