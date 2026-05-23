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
fn test_raster_system_glyph(
  codepoint~ : Int,
  size~ : Double,
  weight~ : Int,
  style~ : @core.FontStyle,
  scale_factor~ : Double,
) -> @wgpu_renderer.NativeRasterGlyph? {
  let glyph_id = macos_coretext_glyph_id_for_codepoint(
    codepoint,
    size,
    weight,
    coretext_style_code(style),
  )
  if glyph_id <= 0 {
    None
  } else {
    let font_name = macos_coretext_system_font_name(
      size,
      weight,
      coretext_style_code(style),
    )
    coretext_raster_glyph({
      glyph_id,
      codepoint,
      font_name,
      size_key: coretext_size_key(size),
      weight,
      style,
      scale_key: coretext_scale_key(coretext_text_scale(scale_factor)),
    })
  }
}

///|
test "coretext private run payload length checks avoid unchecked products" {
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
}

///|
test "coretext glyph payload is private and versioned" {
  let payload = coretext_glyph_payload({
    glyph_id: 42,
    codepoint: 'A'.to_int(),
    font_name: Bytes::from_array([b'T', b'e', b's', b't']),
    size_key: coretext_size_key(18.0),
    weight: 600,
    style: @core.FontStyle::Italic,
    scale_key: coretext_scale_key(2.0),
  })
  inspect(payload.length(), content="36")
  guard coretext_glyph_key_from_payload(payload) is Some(key) else {
    fail("expected versioned coretext glyph payload")
  }
  inspect(key.glyph_id, content="42")
  inspect(key.codepoint, content="\{'A'.to_int()}")
  inspect(key.font_name.length(), content="4")
  inspect(key.size_key, content="1152")
  inspect(key.weight, content="600")
  assert_true(key.style == @core.FontStyle::Italic)
  inspect(key.scale_key, content="128")
  let legacy : Array[Byte] = []
  push_i32_le(legacy, 42)
  push_i32_le(legacy, coretext_size_key(18.0))
  push_i32_le(legacy, 600)
  push_i32_le(legacy, 1)
  push_i32_le(legacy, coretext_scale_key(2.0))
  inspect(
    coretext_glyph_key_from_payload(Bytes::from_array(legacy)) is None,
    content="true",
  )
  let missing_font_name : Array[Byte] = []
  push_i32_le(missing_font_name, coretext_glyph_payload_protocol_version)
  push_i32_le(missing_font_name, 42)
  push_i32_le(missing_font_name, coretext_size_key(18.0))
  push_i32_le(missing_font_name, 600)
  push_i32_le(missing_font_name, 1)
  push_i32_le(missing_font_name, coretext_scale_key(2.0))
  push_i32_le(missing_font_name, 'A'.to_int())
  push_i32_le(missing_font_name, 0)
  inspect(
    coretext_glyph_key_from_payload(Bytes::from_array(missing_font_name))
    is None,
    content="true",
  )
}

///|
test "coretext run layout returns shaped glyph placements" {
  let run = @core.TextRun::new(
    text="office",
    frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=32.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match coretext_layout_for_run(run, 2.0) {
    Some(layout) => {
      inspect(layout.glyphs.length() > 0, content="true")
      inspect(layout.caret_positions.length(), content="7")
      inspect(
        caret_positions_are_monotonic(layout.caret_positions),
        content="true",
      )
    }
    None => inspect("missing", content="available")
  }
}

///|
test "coretext run layout rejects glyph records without serialized font identity" {
  let run = @core.TextRun::new(
    text="A",
    frame=@core.Rect::new(x=0.0, y=0.0, width=40.0, height=24.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let bytes : Array[Byte] = []
  push_i32_le(bytes, coretext_run_protocol_version)
  push_i32_le(bytes, 1)
  push_f64_bits_le(bytes, 0x4038000000000000UL)
  push_f64_bits_le(bytes, 0x4032000000000000UL)
  push_f64_bits_le(bytes, 0x402c000000000000UL)
  push_i32_le(bytes, 42)
  push_i32_le(bytes, 0)
  push_f64_bits_le(bytes, 0UL)
  push_f64_bits_le(bytes, 0UL)
  push_i32_le(bytes, 0)
  inspect(
    coretext_layout_glyph_records_from_bytes(run, 1.0, Bytes::from_array(bytes))
    is None,
    content="true",
  )
}

///|
test "coretext run layout parses serialized font identity" {
  let run = @core.TextRun::new(
    text="A",
    frame=@core.Rect::new(x=0.0, y=0.0, width=40.0, height=24.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let bytes : Array[Byte] = []
  let font_name = [b'T', b'e', b's', b't', b'P', b'S']
  push_i32_le(bytes, coretext_run_protocol_version)
  push_i32_le(bytes, 1)
  push_f64_bits_le(bytes, 0x4038000000000000UL)
  push_f64_bits_le(bytes, 0x4032000000000000UL)
  push_f64_bits_le(bytes, 0x402c000000000000UL)
  push_i32_le(bytes, 42)
  push_i32_le(bytes, 0)
  push_f64_bits_le(bytes, 0UL)
  push_f64_bits_le(bytes, 0UL)
  push_i32_le(bytes, font_name.length())
  for byte in font_name {
    bytes.push(byte)
  }
  match
    coretext_layout_glyph_records_from_bytes(run, 1.0, Bytes::from_array(bytes)) {
    Some(records) => inspect(records.length(), content="1")
    None => fail("expected serialized font identity to parse")
  }
}

///|
test "coretext run layout rejects trailing bytes after glyph records" {
  let run = @core.TextRun::new(
    text="A",
    frame=@core.Rect::new(x=0.0, y=0.0, width=40.0, height=24.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  let bytes : Array[Byte] = []
  let font_name = [b'T', b'e', b's', b't', b'P', b'S']
  push_i32_le(bytes, coretext_run_protocol_version)
  push_i32_le(bytes, 1)
  push_f64_bits_le(bytes, 0x4038000000000000UL)
  push_f64_bits_le(bytes, 0x4032000000000000UL)
  push_f64_bits_le(bytes, 0x402c000000000000UL)
  push_i32_le(bytes, 42)
  push_i32_le(bytes, 0)
  push_f64_bits_le(bytes, 0UL)
  push_f64_bits_le(bytes, 0UL)
  push_i32_le(bytes, font_name.length())
  for byte in font_name {
    bytes.push(byte)
  }
  bytes.push(b'\xff')
  inspect(
    coretext_layout_glyph_records_from_bytes(run, 1.0, Bytes::from_array(bytes))
    is None,
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
extern "C" fn macos_coretext_glyph_id_for_codepoint(
  codepoint : Int,
  size : Double,
  weight : Int,
  style : Int,
) -> Int = "moui_macos_coretext_glyph_id_for_codepoint"

///|
extern "C" fn macos_coretext_system_font_name(
  size : Double,
  weight : Int,
  style : Int,
) -> Bytes = "moui_macos_coretext_system_font_name"

///|
#borrow(payload)
extern "C" fn macos_coretext_debug_font_registration_data_len(
  payload : Bytes,
) -> Int = "moui_macos_coretext_debug_font_registration_data_len"

///|
extern "C" fn macos_coretext_debug_font_spec_protocol_version() -> Int = "moui_macos_coretext_debug_font_spec_protocol_version"

///|
extern "C" fn macos_coretext_debug_font_registration_protocol_version() -> Int = "moui_macos_coretext_debug_font_registration_protocol_version"

///|
#borrow(family_name)
extern "C" fn macos_coretext_debug_generic_font_name_len(
  family_name : Bytes,
) -> Int = "moui_macos_coretext_debug_generic_font_name_len"

///|
test "coretext native protocol versions match shared text protocol" {
  inspect(
    macos_coretext_debug_font_spec_protocol_version(),
    content="\{@text_protocol.native_font_spec_protocol_version}",
  )
  inspect(
    macos_coretext_debug_font_registration_protocol_version(),
    content="\{@text_protocol.native_font_registration_protocol_version}",
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
test "coretext text engine rasterizes cjk glyphs with serialized run fonts" {
  let run = @core.TextRun::new(
    text="中文",
    frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=40.0),
    font=@core.FontSpec::new(size=20.0, weight=400),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match coretext_layout_glyph_records_for_run(run, 2.0) {
    Some(records) => {
      inspect(records.length() >= 2, content="true")
      for index, record in records {
        let codepoint = run.text.to_array()[index].to_int()
        inspect(record.key.codepoint, content="\{codepoint}")
        inspect(record.key.font_name.length() > 0, content="true")
        match coretext_raster_glyph(record.key) {
          Some(glyph) => {
            inspect(glyph.width > 0, content="true")
            inspect(glyph.height > 0, content="true")
            inspect(bytes_has_nonzero(glyph.pixels), content="true")
          }
          None => fail("expected cjk glyph to rasterize")
        }
      }
    }
    None => fail("expected cjk coretext glyph records")
  }
}

///|
test "coretext text engine accepts named family stacks" {
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Helvetica").with_fallback(
      @core.FontFamily::SystemUi,
    ),
    size=17.0,
    weight=500,
  )
  let input = @core.TextLayoutInput::new(text="family", font~)
  match coretext_measure_layout(input) {
    Some(layout) => {
      inspect(layout.size.width > 0.0, content="true")
      inspect(layout.caret_positions.length(), content="7")
      inspect(
        caret_positions_are_monotonic(layout.caret_positions),
        content="true",
      )
    }
    None => inspect("missing", content="available")
  }
  let run = @core.TextRun::new(
    text="family",
    frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=32.0),
    font~,
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match coretext_layout_for_run(run, 1.0) {
    Some(layout) => inspect(layout.glyphs.length() > 0, content="true")
    None => inspect("missing", content="available")
  }
}

///|
test "coretext maps generic font families to macOS fonts" {
  inspect(
    macos_coretext_debug_generic_font_name_len(
      @utf8.encode(@core.FontFamily::UiMonospace.css_name()[:], bom=false),
    ) >
    0,
    content="true",
  )
  inspect(
    macos_coretext_debug_generic_font_name_len(
      @utf8.encode(@core.FontFamily::Serif.css_name()[:], bom=false),
    ) >
    0,
    content="true",
  )
  inspect(
    macos_coretext_debug_generic_font_name_len(
      @utf8.encode("not-a-generic-family", bom=false),
    ),
    content="-1",
  )
}

///|
test "coretext rejects malformed registered font payload" {
  inspect(
    macos_coretext_register_font_data(Bytes::from_array([b'\x01'])) == 0,
    content="true",
  )
}

///|
test "coretext parses registered font payload shape" {
  let payload = @text_protocol.native_font_registration_bytes(
    family_name=@utf8.encode("MoUIRegisteredCoreTextAlias", bom=false),
    data=Bytes::from_array([b'\x01', b'\x02', b'\x03']),
  )
  inspect(macos_coretext_debug_font_registration_data_len(payload), content="3")
  inspect(
    macos_coretext_debug_font_registration_data_len(
      Bytes::from_array([b'\x01']),
    ),
    content="-1",
  )
}

///|
test "coretext text engine exposes platform engine id" {
  let system = @wgpu_renderer.native_text_system_with_engine(
    coretext_text_engine(),
  )
  inspect(system.id(), content="native-wgpu-coretext-system")
}

///|
test "coretext text engine rasterizes system glyphs" {
  match
    test_raster_system_glyph(
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
    test_raster_system_glyph(
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
