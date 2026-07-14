///|
/// Convert a defiltered scanline to RGBA8 pixels.
/// Returns RGBA bytes (4 bytes per pixel).
fn scanline_to_rgba(
  row : Bytes,
  color_type : ColorType,
  bit_depth : Int,
  palette : Bytes?,
  palette_alpha : Bytes?,
) -> Bytes raise DecodeError {
  match (color_type, bit_depth) {
    (Rgba, 8) =>
      // Already RGBA8 — return as-is (zero-copy)
      row
    (Rgb, 8) => {
      let pixel_count = row.length() / 3
      let buf = FixedArray::make(pixel_count * 4, b'\x00')
      for i in 0..<pixel_count {
        buf[i * 4] = row[i * 3]
        buf[i * 4 + 1] = row[i * 3 + 1]
        buf[i * 4 + 2] = row[i * 3 + 2]
        buf[i * 4 + 3] = b'\xFF'
      }
      Bytes::from_array(buf)
    }
    (Grayscale, 8) => {
      let pixel_count = row.length()
      let buf = FixedArray::make(pixel_count * 4, b'\x00')
      for i in 0..<pixel_count {
        let v = row[i]
        buf[i * 4] = v
        buf[i * 4 + 1] = v
        buf[i * 4 + 2] = v
        buf[i * 4 + 3] = b'\xFF'
      }
      Bytes::from_array(buf)
    }
    (GrayscaleAlpha, 8) => {
      let pixel_count = row.length() / 2
      let buf = FixedArray::make(pixel_count * 4, b'\x00')
      for i in 0..<pixel_count {
        let v = row[i * 2]
        let a = row[i * 2 + 1]
        buf[i * 4] = v
        buf[i * 4 + 1] = v
        buf[i * 4 + 2] = v
        buf[i * 4 + 3] = a
      }
      Bytes::from_array(buf)
    }
    (Indexed, 8) =>
      match palette {
        None => raise MissingChunk("PLTE")
        Some(plte) => {
          let pixel_count = row.length()
          let buf = FixedArray::make(pixel_count * 4, b'\x00')
          let plte_entries = plte.length() / 3
          for i in 0..<pixel_count {
            let idx = row[i].to_int()
            if idx >= plte_entries {
              raise CorruptData(
                "palette index out of range: " + idx.to_string(),
              )
            }
            buf[i * 4] = plte[idx * 3]
            buf[i * 4 + 1] = plte[idx * 3 + 1]
            buf[i * 4 + 2] = plte[idx * 3 + 2]
            buf[i * 4 + 3] = match palette_alpha {
              Some(trns) if idx < trns.length() => trns[idx]
              _ => b'\xFF'
            }
          }
          Bytes::from_array(buf)
        }
      }
    _ =>
      raise UnsupportedFeature(
        "unsupported color type/bit depth: " +
        color_type.to_string() +
        "/" +
        bit_depth.to_string(),
      )
  }
}

///|
test "scanline_to_rgba: rgba passthrough" {
  let row = b"\xFF\x00\x80\xC0"
  let result = scanline_to_rgba(row, Rgba, 8, None, None)
  assert_eq(result, b"\xFF\x00\x80\xC0")
}

///|
test "scanline_to_rgba: rgb to rgba" {
  let row = b"\xFF\x00\x80"
  let result = scanline_to_rgba(row, Rgb, 8, None, None)
  assert_eq(result, b"\xFF\x00\x80\xFF")
}

///|
test "scanline_to_rgba: grayscale to rgba" {
  let row = b"\x80\xFF"
  let result = scanline_to_rgba(row, Grayscale, 8, None, None)
  assert_eq(result, b"\x80\x80\x80\xFF\xFF\xFF\xFF\xFF")
}

///|
test "scanline_to_rgba: grayscale alpha to rgba" {
  let row = b"\x80\xC0"
  let result = scanline_to_rgba(row, GrayscaleAlpha, 8, None, None)
  assert_eq(result, b"\x80\x80\x80\xC0")
}

///|
test "scanline_to_rgba: indexed to rgba" {
  // Palette: entry 0 = red, entry 1 = green
  let palette = b"\xFF\x00\x00\x00\xFF\x00"
  let row = b"\x00\x01"
  let result = scanline_to_rgba(row, Indexed, 8, Some(palette), None)
  assert_eq(result, b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF")
}

///|
test "scanline_to_rgba: indexed applies palette alpha" {
  let palette = b"\xFF\x00\x00\x00\xFF\x00"
  let palette_alpha = b"\x00\x80"
  let row = b"\x00\x01"
  let result = scanline_to_rgba(
    row,
    Indexed,
    8,
    Some(palette),
    Some(palette_alpha),
  )
  assert_eq(result, b"\xFF\x00\x00\x00\x00\xFF\x00\x80")
}
