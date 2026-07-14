///|
pub fn encode_ico(img : ImageData) -> Bytes raise EncodeError {
  validate_rgba8_image(img)
  if img.width > 256 || img.height > 256 {
    raise InvalidDimensions(
      "ICO dimensions must be <= 256x256: " +
      img.width.to_string() +
      "x" +
      img.height.to_string(),
    )
  }
  let png = encode_png(img)
  let header = FixedArray::make(22, b'\x00')
  write_u16le(header, 0, 0)
  write_u16le(header, 2, 1)
  write_u16le(header, 4, 1)
  header[6] = (if img.width == 256 { 0 } else { img.width }).to_byte()
  header[7] = (if img.height == 256 { 0 } else { img.height }).to_byte()
  header[8] = b'\x00'
  header[9] = b'\x00'
  write_u16le(header, 10, 1)
  write_u16le(header, 12, 32)
  write_u32le(header, 14, png.length().reinterpret_as_uint())
  write_u32le(header, 18, 22U)
  concat_bytes([Bytes::from_array(header), png])
}
