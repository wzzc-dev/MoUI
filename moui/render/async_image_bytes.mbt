///|
/// Read a little-endian i32 from `data` at `offset`.
///
/// Single shared implementation for decoding async image load-completion
/// payloads; platform providers (skia/sun on macos/linux/windows) used to
/// carry six identical private copies.
pub fn async_image_read_i32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}
