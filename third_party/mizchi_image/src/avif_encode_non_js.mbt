///|
pub fn encode_avif(_img : ImageData) -> Bytes raise EncodeError {
  raise InvalidData("AVIF encoder is only available on js target")
}
