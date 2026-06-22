///|
/// Convert grayscale pixels to RGBA for display
pub fn grayscale_to_rgba(
  pixels : FixedArray[Byte],
  width : Int,
  height : Int,
) -> FixedArray[Byte] {
  let rgba_size = width * height * 4
  let rgba = FixedArray::make(rgba_size, b"\x00"[0])

  for y in 0..<height {
    for x in 0..<width {
      let gray_idx = y * width + x
      let rgba_idx = gray_idx * 4
      let gray = pixels[gray_idx]
      rgba[rgba_idx] = b"\xff"[0] // R
      rgba[rgba_idx + 1] = b"\xff"[0] // G
      rgba[rgba_idx + 2] = b"\xff"[0] // B
      rgba[rgba_idx + 3] = gray // A (use grayscale as alpha)
    }
  }

  rgba
}
