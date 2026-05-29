///|
test "native text protocol encodes utf32 bytes" {
  let bytes = native_utf32_bytes("A你")
  inspect(bytes.length(), content="8")
  inspect(bytes[0].to_int(), content="65")
  inspect(bytes[4].to_int(), content="96")
  inspect(bytes[5].to_int(), content="79")
}

///|
test "native text protocol encodes and parses font spec payload" {
  let bytes = native_font_spec_bytes(
    @core.FontSpec::new(
      families=@core.FontFamilyStack::named("Acme Sans")
        .with_fallback(@core.FontFamily::UiSansSerif)
        .with_fallback(@core.FontFamily::SansSerif),
      size=17.5,
      weight=650,
      style=@core.FontStyle::Italic,
    ),
  )
  match native_font_spec_from_bytes(bytes) {
    Some(payload) => {
      inspect(payload.size, content="17.5")
      inspect(payload.size_key, content="1120")
      inspect(payload.weight, content="650")
      assert_true(payload.style == @core.FontStyle::Italic)
      inspect(payload.family_names.length(), content="3")
      inspect(payload.family_names[0].length(), content="9")
      inspect(payload.family_names[0][0].to_int(), content="65")
      inspect(payload.family_names[1][0].to_int(), content="117")
    }
    None => fail("expected versioned font spec payload to parse")
  }
}

///|
test "native text protocol encodes empty font stack as system-ui" {
  let bytes = native_font_spec_bytes(
    @core.FontSpec::new(
      families={ families: [] },
      size=16.0,
      weight=400,
      style=@core.FontStyle::Normal,
    ),
  )
  match native_font_spec_from_bytes(bytes) {
    Some(payload) => {
      inspect(payload.family_names.length(), content="1")
      inspect(payload.family_names[0].length(), content="9")
      inspect(payload.family_names[0][0].to_int(), content="115")
    }
    None => fail("expected fallback system-ui font spec payload")
  }
}

///|
test "native text protocol rejects malformed font spec payload" {
  let wrong_version : Array[Byte] = []
  push_i32_le(wrong_version, 0)
  push_i32_le(wrong_version, 1024)
  push_i32_le(wrong_version, 400)
  push_i32_le(wrong_version, 0)
  push_i32_le(wrong_version, 1)
  push_i32_le(wrong_version, 9)
  wrong_version.push(b's')
  inspect(
    native_font_spec_from_bytes(Bytes::from_array(wrong_version)) is None,
    content="true",
  )
  let invalid_style : Array[Byte] = []
  push_i32_le(invalid_style, native_font_spec_protocol_version)
  push_i32_le(invalid_style, 1024)
  push_i32_le(invalid_style, 400)
  push_i32_le(invalid_style, 99)
  push_i32_le(invalid_style, 0)
  inspect(
    native_font_spec_from_bytes(Bytes::from_array(invalid_style)) is None,
    content="true",
  )
  let trailing : Array[Byte] = []
  push_i32_le(trailing, native_font_spec_protocol_version)
  push_i32_le(trailing, 1024)
  push_i32_le(trailing, 400)
  push_i32_le(trailing, 0)
  push_i32_le(trailing, 1)
  push_i32_le(trailing, 1)
  trailing.push(b'a')
  trailing.push(b'\xff')
  inspect(
    native_font_spec_from_bytes(Bytes::from_array(trailing)) is None,
    content="true",
  )
}

///|
test "native text protocol encodes font registration payload" {
  let bytes = native_font_registration_bytes(
    family_name=Bytes::from_array([b'A', b'c', b'm', b'e']),
    data=Bytes::from_array([b'\x01', b'\x02']),
  )
  inspect(bytes.length(), content="18")
  inspect(bytes[0].to_int(), content="1")
  inspect(bytes[4].to_int(), content="4")
  inspect(bytes[8].to_int(), content="2")
  inspect(bytes[12].to_int(), content="65")
  inspect(bytes[16].to_int(), content="1")
}

///|
test "native text protocol parses font registration payload" {
  let bytes = native_font_registration_bytes(
    family_name=Bytes::from_array([b'A', b'c', b'm', b'e']),
    data=Bytes::from_array([b'\x01', b'\x02']),
  )
  match native_font_registration_from_bytes(bytes) {
    Some(payload) => {
      inspect(payload.family_name.length(), content="4")
      inspect(payload.family_name[0].to_int(), content="65")
      inspect(payload.data.length(), content="2")
      inspect(payload.data[1].to_int(), content="2")
    }
    None => fail("expected versioned registration payload to parse")
  }
}

///|
test "native text protocol rejects malformed font registration payload" {
  let wrong_version : Array[Byte] = []
  push_i32_le(wrong_version, 0)
  push_i32_le(wrong_version, 4)
  push_i32_le(wrong_version, 2)
  wrong_version.push(b'A')
  wrong_version.push(b'c')
  wrong_version.push(b'm')
  wrong_version.push(b'e')
  wrong_version.push(b'\x01')
  wrong_version.push(b'\x02')
  inspect(
    native_font_registration_from_bytes(Bytes::from_array(wrong_version))
    is None,
    content="true",
  )
  let missing_data : Array[Byte] = []
  push_i32_le(missing_data, native_font_registration_protocol_version)
  push_i32_le(missing_data, 4)
  push_i32_le(missing_data, 2)
  missing_data.push(b'A')
  missing_data.push(b'c')
  missing_data.push(b'm')
  missing_data.push(b'e')
  missing_data.push(b'\x01')
  inspect(
    native_font_registration_from_bytes(Bytes::from_array(missing_data)) is None,
    content="true",
  )
  let trailing : Array[Byte] = []
  push_i32_le(trailing, native_font_registration_protocol_version)
  push_i32_le(trailing, 4)
  push_i32_le(trailing, 2)
  trailing.push(b'A')
  trailing.push(b'c')
  trailing.push(b'm')
  trailing.push(b'e')
  trailing.push(b'\x01')
  trailing.push(b'\x02')
  trailing.push(b'\xff')
  inspect(
    native_font_registration_from_bytes(Bytes::from_array(trailing)) is None,
    content="true",
  )
}

///|
test "native text protocol parses versioned measure layout" {
  let input = @core.TextLayoutInput::new(
    text="AB",
    font=@core.FontSpec::new(size=14.0, weight=400),
    max_width=12.0,
  )
  let bytes : Array[Byte] = []
  push_i32_le(bytes, 2)
  push_i32_le(bytes, native_measure_layout_protocol_version)
  push_f64_bits_le(bytes, 0x4030000000000000UL)
  push_f64_bits_le(bytes, 0x4024000000000000UL)
  push_f64_bits_le(bytes, 0UL)
  push_f64_bits_le(bytes, 0x4020000000000000UL)
  push_f64_bits_le(bytes, 0x4030000000000000UL)
  match native_measure_layout_from_bytes(input, Bytes::from_array(bytes)) {
    Some(layout) => {
      inspect(layout.size.width, content="12")
      inspect(layout.size.height, content="16")
      inspect(layout.baseline, content="10")
      inspect(layout.caret_positions.length(), content="3")
      inspect(layout.caret_positions[2], content="12")
    }
    None => fail("expected native text layout payload to parse")
  }
}

///|
test "native text protocol rejects malformed measure layout" {
  let input = @core.TextLayoutInput::new(
    text="AB",
    font=@core.FontSpec::new(size=14.0, weight=400),
  )
  let old_version : Array[Byte] = []
  push_i32_le(old_version, 2)
  push_i32_le(old_version, 0)
  push_f64_bits_le(old_version, 0x4030000000000000UL)
  push_f64_bits_le(old_version, 0x4024000000000000UL)
  push_f64_bits_le(old_version, 0UL)
  push_f64_bits_le(old_version, 0x4020000000000000UL)
  push_f64_bits_le(old_version, 0x4030000000000000UL)
  inspect(
    native_measure_layout_from_bytes(input, Bytes::from_array(old_version))
    is None,
    content="true",
  )
  let non_monotonic : Array[Byte] = []
  push_i32_le(non_monotonic, 2)
  push_i32_le(non_monotonic, native_measure_layout_protocol_version)
  push_f64_bits_le(non_monotonic, 0x4030000000000000UL)
  push_f64_bits_le(non_monotonic, 0x4024000000000000UL)
  push_f64_bits_le(non_monotonic, 0x4020000000000000UL)
  push_f64_bits_le(non_monotonic, 0UL)
  push_f64_bits_le(non_monotonic, 0x4030000000000000UL)
  inspect(
    native_measure_layout_from_bytes(input, Bytes::from_array(non_monotonic))
    is None,
    content="true",
  )
  non_monotonic.push(b'\xff')
  inspect(
    native_measure_layout_from_bytes(input, Bytes::from_array(non_monotonic))
    is None,
    content="true",
  )
}

///|
test "native text protocol parses versioned run layout" {
  let bytes : Array[Byte] = []
  let cache_key = [b'g', b':', b'4', b'2']
  let payload = [b'\x01', b'\x02', b'\x03']
  push_i32_le(bytes, native_run_layout_protocol_version)
  push_i32_le(bytes, 1)
  push_f64_bits_le(bytes, 0x4050000000000000UL)
  push_f64_bits_le(bytes, 0x4030000000000000UL)
  push_f64_bits_le(bytes, 0x4028000000000000UL)
  push_f64_bits_le(bytes, 0x3ff8000000000000UL)
  push_f64_bits_le(bytes, 0x4000000000000000UL)
  push_i32_le(bytes, cache_key.length())
  push_i32_le(bytes, payload.length())
  for byte in cache_key {
    bytes.push(byte)
  }
  for byte in payload {
    bytes.push(byte)
  }
  match native_run_layout_from_bytes(Bytes::from_array(bytes)) {
    Some(layout) => {
      inspect(layout.size.width, content="64")
      inspect(layout.size.height, content="16")
      inspect(layout.baseline, content="12")
      inspect(layout.glyphs.length(), content="1")
      inspect(layout.glyphs[0].x, content="1.5")
      inspect(layout.glyphs[0].y, content="2")
    }
    None => fail("expected native run layout payload to parse")
  }
}

///|
test "native text protocol rejects malformed run layout" {
  let truncated : Array[Byte] = []
  push_i32_le(truncated, native_run_layout_protocol_version)
  push_i32_le(truncated, 1)
  push_f64_bits_le(truncated, 0x4050000000000000UL)
  push_f64_bits_le(truncated, 0x4030000000000000UL)
  push_f64_bits_le(truncated, 0x4028000000000000UL)
  inspect(
    native_run_layout_from_bytes(Bytes::from_array(truncated)) is None,
    content="true",
  )
  let missing_payload : Array[Byte] = []
  push_i32_le(missing_payload, native_run_layout_protocol_version)
  push_i32_le(missing_payload, 1)
  push_f64_bits_le(missing_payload, 0x4050000000000000UL)
  push_f64_bits_le(missing_payload, 0x4030000000000000UL)
  push_f64_bits_le(missing_payload, 0x4028000000000000UL)
  push_f64_bits_le(missing_payload, 0UL)
  push_f64_bits_le(missing_payload, 0UL)
  push_i32_le(missing_payload, 4)
  push_i32_le(missing_payload, 0)
  inspect(
    native_run_layout_from_bytes(Bytes::from_array(missing_payload)) is None,
    content="true",
  )
  let trailing : Array[Byte] = []
  push_i32_le(trailing, native_run_layout_protocol_version)
  push_i32_le(trailing, 0)
  push_f64_bits_le(trailing, 0UL)
  push_f64_bits_le(trailing, 0x4030000000000000UL)
  push_f64_bits_le(trailing, 0UL)
  trailing.push(b'\xff')
  inspect(
    native_run_layout_from_bytes(Bytes::from_array(trailing)) is None,
    content="true",
  )
}

///|
test "native text protocol parses versioned raster glyph" {
  let bytes : Array[Byte] = []
  push_i32_le(bytes, 2)
  push_i32_le(bytes, 2)
  push_i32_le(bytes, 1)
  push_i32_le(bytes, -3)
  push_i32_le(bytes, native_raster_glyph_protocol_version)
  push_i32_le(bytes, 0)
  push_f64_bits_le(bytes, 0x4010000000000000UL)
  bytes.push(b'\x00')
  bytes.push(b'\xff')
  bytes.push(b'\x7f')
  bytes.push(b'\x01')
  match native_raster_glyph_from_bytes(Bytes::from_array(bytes)) {
    Some(glyph) => {
      inspect(glyph.width, content="2")
      inspect(glyph.height, content="2")
      inspect(glyph.bearing_x, content="1")
      inspect(glyph.bearing_y, content="-3")
      assert_true(
        glyph.format == @wgpu_renderer.NativeRasterGlyphFormat::AlphaMask,
      )
      inspect(glyph.pixels.length(), content="4")
    }
    None => fail("expected native raster glyph payload to parse")
  }
}

///|
test "native text protocol rejects malformed raster glyph" {
  let wrong_version : Array[Byte] = []
  push_i32_le(wrong_version, 2)
  push_i32_le(wrong_version, 2)
  push_i32_le(wrong_version, 0)
  push_i32_le(wrong_version, 0)
  push_i32_le(wrong_version, 0)
  push_i32_le(wrong_version, 0)
  push_f64_bits_le(wrong_version, 0UL)
  wrong_version.push(b'\xff')
  wrong_version.push(b'\xff')
  wrong_version.push(b'\xff')
  wrong_version.push(b'\xff')
  inspect(
    native_raster_glyph_from_bytes(Bytes::from_array(wrong_version)) is None,
    content="true",
  )
  let short_pixels : Array[Byte] = []
  push_i32_le(short_pixels, 2)
  push_i32_le(short_pixels, 2)
  push_i32_le(short_pixels, 0)
  push_i32_le(short_pixels, 0)
  push_i32_le(short_pixels, native_raster_glyph_protocol_version)
  push_i32_le(short_pixels, 0)
  push_f64_bits_le(short_pixels, 0UL)
  short_pixels.push(b'\xff')
  inspect(
    native_raster_glyph_from_bytes(Bytes::from_array(short_pixels)) is None,
    content="true",
  )
}

///|
fn push_f64_bits_le(out : Array[Byte], bits : UInt64) -> Unit {
  for index in 0..<8 {
    out.push(((bits >> (index * 8)) & 0xFFUL).to_byte())
  }
}

///|
test "native text protocol parses color raster glyph" {
  let bytes : Array[Byte] = []
  push_i32_le(bytes, 1)
  push_i32_le(bytes, 2)
  push_i32_le(bytes, 0)
  push_i32_le(bytes, -2)
  push_i32_le(bytes, native_raster_glyph_protocol_version)
  push_i32_le(bytes, 1)
  push_f64_bits_le(bytes, 0UL)
  bytes.push(b'\x10')
  bytes.push(b'\x20')
  bytes.push(b'\x30')
  bytes.push(b'\xff')
  bytes.push(b'\x40')
  bytes.push(b'\x50')
  bytes.push(b'\x60')
  bytes.push(b'\x80')
  match native_raster_glyph_from_bytes(Bytes::from_array(bytes)) {
    Some(glyph) => {
      inspect(glyph.width, content="1")
      inspect(glyph.height, content="2")
      assert_true(
        glyph.format == @wgpu_renderer.NativeRasterGlyphFormat::ColorRgba,
      )
      inspect(glyph.pixels.length(), content="8")
    }
    None => fail("expected color native raster glyph payload to parse")
  }
}
