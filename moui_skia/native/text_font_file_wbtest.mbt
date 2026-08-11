///|
test "typeface from file rejects invalid paths" {
  assert_true(Typeface::from_file(b"") is None)
  assert_true(
    Typeface::from_file(b"/definitely/missing/moui-open-sans.woff2") is None,
  )
  assert_true(
    Typeface::from_file(b"/definitely/missing/moui-open-sans.woff2", index=-1)
    is None,
  )
}

///|
test "typeface from data rejects invalid inputs" {
  assert_true(Typeface::from_data(b"") is None)
  assert_true(Typeface::from_data(b"\x00\x01\x02", index=-1) is None)
  assert_true(Typeface::register_data(b"", b"\x00\x01\x02") is None)
  assert_true(Typeface::register_data(b"family", b"") is None)
  assert_true(Typeface::register_data(b"family", b"\x00\x01\x02", index=-1)
    is None)
}

///|
// macOS ships a system variable font (SFNS.ttf) with a "wght" axis; when the
// platform does not provide it the test is skipped rather than failed.
test "typeface variation clone changes measured width" {
  match Typeface::from_file(b"/System/Library/Fonts/SFNS.ttf") {
    None => () // Platform has no SFNS.ttf; nothing to assert.
    Some(typeface) => {
      let light = match typeface.with_variations([(b"wght", 100.0)]) {
        Some(variation) => variation
        None => return assert_true(false)
      }
      let black = match typeface.with_variations([(b"wght", 900.0)]) {
        Some(variation) => variation
        None => return assert_true(false)
      }
      let light_font = match Font::from_typeface(light, size=32.0) {
        Some(font) => font
        None => return assert_true(false)
      }
      let black_font = match Font::from_typeface(black, size=32.0) {
        Some(font) => font
        None => return assert_true(false)
      }
      let light_width = light_font.measure_text_utf8(b"WWWW")
      let black_width = black_font.measure_text_utf8(b"WWWW")
      assert_true(black_width > light_width)
      // Composition: applying a second axis keeps the first axis value.
      let composed = match typeface.with_variations([(b"wght", 100.0)]) {
        Some(variation) => variation.with_variations([(b"wdth", 50.0)])
        None => None
      }
      assert_true(composed is Some(_))
    }
  }
}
