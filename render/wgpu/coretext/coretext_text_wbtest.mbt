///|
fn caret_positions_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
fn bytes_has_nonzero(bytes : Bytes) -> Bool {
  for byte in bytes {
    if byte != b'\x00' {
      return true
    }
  }
  false
}

///|
fn glyph_nonzero_row_bounds(
  glyph : @wgpu_renderer.NativeRasterGlyph,
) -> (Int, Int)? {
  let mut min_y = glyph.height
  let mut max_y = -1
  for y in 0..<glyph.height {
    for x in 0..<glyph.width {
      if glyph.pixels[y * glyph.width + x] != b'\x00' {
        min_y = min_y.min(y)
        max_y = max_y.max(y)
      }
    }
  }
  if max_y >= 0 {
    Some((min_y, max_y))
  } else {
    None
  }
}

///|
test "coretext private payload length checks avoid unchecked products" {
  inspect(
    coretext_payload_covers_records(
      total_len=24 + 3 * 8,
      header=24,
      count=3,
      record_size=8,
    ),
    content="true",
  )
  inspect(
    coretext_payload_covers_records(
      total_len=24 + 2 * 8,
      header=24,
      count=3,
      record_size=8,
    ),
    content="false",
  )
  inspect(
    coretext_payload_covers_pixels(total_len=32 + 12, width=3, height=4),
    content="true",
  )
  inspect(
    coretext_payload_covers_pixels(total_len=32 + 11, width=3, height=4),
    content="false",
  )
}

///|
test "coretext glyph payload is private and versioned" {
  let payload = coretext_glyph_payload({
    codepoint: 'A'.to_int(),
    size_key: coretext_size_key(18.0),
    weight: 600,
    style: @core.FontStyle::Italic,
    scale_key: coretext_scale_key(2.0),
  })
  inspect(payload.length(), content="24")
  guard coretext_glyph_key_from_payload(payload) is Some(key) else {
    fail("expected versioned coretext glyph payload")
  }
  inspect(key.codepoint, content="65")
  inspect(key.size_key, content="1152")
  inspect(key.weight, content="600")
  assert_true(key.style == @core.FontStyle::Italic)
  inspect(key.scale_key, content="128")
  let legacy : Array[Byte] = []
  push_i32_le(legacy, 'A'.to_int())
  push_i32_le(legacy, coretext_size_key(18.0))
  push_i32_le(legacy, 600)
  push_i32_le(legacy, 1)
  push_i32_le(legacy, coretext_scale_key(2.0))
  inspect(
    coretext_glyph_key_from_payload(Bytes::from_array(legacy)) is None,
    content="true",
  )
}

///|
test "coretext text engine measures mixed system text" {
  let input = @core.TextLayoutInput::new(
    text="aM你🙂",
    font=@core.FontSpec::new(size=17.0, weight=600),
  )
  match coretext_measure_layout(input) {
    Some(layout) => {
      inspect(layout.size.width > 0.0, content="true")
      inspect(layout.size.height > 0.0, content="true")
      inspect(layout.baseline > 0.0, content="true")
      inspect(layout.caret_positions.length(), content="5")
      inspect(
        caret_positions_are_monotonic(layout.caret_positions),
        content="true",
      )
    }
    None => inspect("missing", content="available")
  }
}

///|
test "coretext text engine exposes platform engine id" {
  let measurer = @wgpu_renderer.native_text_measurer_with_engine(
    coretext_text_engine(),
  )
  inspect(measurer.id(), content="native-wgpu-coretext-system")
}

///|
test "coretext text engine rasterizes system glyphs" {
  match
    coretext_raster_system_glyph(
      codepoint='a'.to_int(),
      size=18.0,
      weight=400,
      style=@core.FontStyle::Italic,
      scale_factor=1.0,
    ) {
    Some(glyph) => {
      inspect(glyph.width > 0, content="true")
      inspect(glyph.height > 0, content="true")
      inspect(glyph.pixels.length() > 0, content="true")
      inspect(bytes_has_nonzero(glyph.pixels), content="true")
      inspect(glyph.bearing_x > -128 && glyph.bearing_x < 128, content="true")
      inspect(glyph.bearing_y > -128 && glyph.bearing_y < 128, content="true")
    }
    None => inspect("missing", content="available")
  }
}

///|
test "coretext raster glyph rows follow top-left baseline convention" {
  match
    coretext_raster_system_glyph(
      codepoint='H'.to_int(),
      size=32.0,
      weight=700,
      style=@core.FontStyle::Normal,
      scale_factor=1.0,
    ) {
    Some(glyph) =>
      match glyph_nonzero_row_bounds(glyph) {
        Some((min_row, max_row)) => {
          let baseline_row = -glyph.bearing_y
          inspect(min_row > 0, content="true")
          inspect(baseline_row > 0, content="true")
          inspect(baseline_row < glyph.height, content="true")
          inspect(max_row < baseline_row, content="true")
        }
        None => fail("expected non-empty coretext glyph alpha")
      }
    None => inspect("missing", content="available")
  }
}
