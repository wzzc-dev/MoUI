///|
test "sun renderer text system measures mixed emoji through registered fallback faces" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  text_system.register_font_data(
    @core.FontFamily::Emoji,
    sun_test_ttf_for_codes([0x1F600]),
  )

  let text = sun_test_string_from_codepoints([65, 0x1F600])
  let result = text_system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::Name("SunLatinOnly"),
        ]),
        size=10.0,
      ),
      max_width=100.0,
    ),
  )

  inspect(result.size.width, content="20")
  inspect(result.caret_positions.length(), content="3")
  assert_true(result.caret_positions[0] == 0.0)
  assert_true(result.caret_positions[1] > result.caret_positions[0])
  assert_true(result.caret_positions[2] > result.caret_positions[1])
}

///|
test "sun renderer draws mixed emoji text without missing fallback diagnostic" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  text_system.register_font_data(
    @core.FontFamily::Emoji,
    sun_test_ttf_for_codes([0x1F600]),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=sun_test_string_from_codepoints([65, 0x1F600]),
        frame=@core.Rect::new(x=0.0, y=0.0, width=48.0, height=16.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("SunLatinOnly"),
          ]),
          size=10.0,
        ),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ])

  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer text system reports renderer paragraph metadata" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  inspect(text_system.id(), content="sun-raster-text-system")
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  let paragraph = text_system.layout_paragraph(
    @core.TextLayoutInput::new(
      text="A",
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::Name("SunLatinOnly"),
        ]),
        size=10.0,
      ),
      max_width=100.0,
    ),
  )
  inspect(paragraph.metadata.text_system_id, content="sun-raster-text-system")
  assert_true(paragraph.metadata.paragraph_layout_available)
}

///|
priv struct SunTestGlyph {
  codepoint : Int
  advance : Int
  bytes : Array[Byte]
}

///|
priv struct SunTestPoint {
  x : Int
  y : Int
  on_curve : Bool
}

///|
priv struct SunTestContour {
  points : Array[SunTestPoint]
}

///|
priv struct SunTestOutline {
  contours : Array[SunTestContour]
  xmin : Int
  ymin : Int
  xmax : Int
  ymax : Int
}

///|
fn sun_test_ttf_for_codes(codepoints : Array[Int]) -> Bytes {
  let glyphs = []
  for codepoint in codepoints {
    glyphs.push(sun_test_glyph_for_codepoint(codepoint))
  }
  sun_test_ttf_with_glyphs(glyphs)
}

///|
fn sun_test_ttf_with_glyphs(glyphs : Array[SunTestGlyph]) -> Bytes {
  let tags : Array[Bytes] = [
    b"cmap", b"glyf", b"head", b"hhea", b"hmtx", b"loca", b"maxp",
  ]
  let tables = [
    sun_test_cmap_table(glyphs),
    sun_test_glyf_table(glyphs),
    sun_test_head_table(),
    sun_test_hhea_table(glyphs),
    sun_test_hmtx_table(glyphs),
    sun_test_loca_table(glyphs),
    sun_test_maxp_table(glyphs),
  ]
  let offsets = []
  let mut current = 12 + tags.length() * 16
  for table in tables {
    offsets.push(current)
    current = sun_test_align4(current + table.length())
  }

  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_u16(out, tags.length())
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 0)

  for i in 0..<tags.length() {
    sun_test_append_bytes(out, tags[i])
    sun_test_append_u32(out, 0)
    sun_test_append_u32(out, offsets[i])
    sun_test_append_u32(out, tables[i].length())
  }

  for i in 0..<tables.length() {
    while out.length() < offsets[i] {
      sun_test_append_byte(out, 0)
    }
    sun_test_append_array(out, tables[i])
    sun_test_pad4(out)
  }

  Bytes::from_array(out)
}

///|
fn sun_test_glyph_for_codepoint(codepoint : Int) -> SunTestGlyph {
  let bytes = if codepoint is 0x20 { [] } else { sun_test_box_glyph() }
  { codepoint, advance: if codepoint is 0x20 { 5 } else { 10 }, bytes }
}

///|
fn sun_test_head_table() -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_u32(out, 0)
  sun_test_append_u32(out, 0)
  sun_test_append_u32(out, 0x5F0F3CF5)
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 10)
  sun_test_append_zeroes(out, 16)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 10)
  sun_test_append_i16(out, 10)
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 0)
  sun_test_append_i16(out, 2)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  out
}

///|
fn sun_test_hhea_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_i16(out, 10)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_u16(out, 10)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 10)
  sun_test_append_i16(out, 1)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_zeroes(out, 8)
  sun_test_append_i16(out, 0)
  sun_test_append_u16(out, glyphs.length() + 1)
  out
}

///|
fn sun_test_hmtx_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u16(out, 0)
  sun_test_append_i16(out, 0)
  for glyph in glyphs {
    sun_test_append_u16(out, glyph.advance)
    sun_test_append_i16(out, 0)
  }
  out
}

///|
fn sun_test_maxp_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_u16(out, glyphs.length() + 1)
  out
}

///|
fn sun_test_loca_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u16(out, 0)
  let mut offset = 0
  for glyph in glyphs {
    sun_test_append_u16(out, offset / 2)
    offset = sun_test_align2(offset + glyph.bytes.length())
  }
  sun_test_append_u16(out, offset / 2)
  out
}

///|
fn sun_test_glyf_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  for glyph in glyphs {
    sun_test_append_array(out, glyph.bytes)
    while out.length() % 2 != 0 {
      sun_test_append_byte(out, 0)
    }
  }
  out
}

///|
fn sun_test_box_glyph() -> Array[Byte] {
  sun_test_simple_glyph({
    contours: [
      {
        points: [
          { x: 0, y: 10, on_curve: true },
          { x: 10, y: 10, on_curve: true },
          { x: 10, y: 0, on_curve: true },
          { x: 0, y: 0, on_curve: true },
        ],
      },
    ],
    xmin: 0,
    ymin: 0,
    xmax: 10,
    ymax: 10,
  })
}

///|
fn sun_test_simple_glyph(glyph : SunTestOutline) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_i16(out, glyph.contours.length())
  sun_test_append_i16(out, glyph.xmin)
  sun_test_append_i16(out, glyph.ymin)
  sun_test_append_i16(out, glyph.xmax)
  sun_test_append_i16(out, glyph.ymax)

  let points : Array[SunTestPoint] = []
  let mut end_point = -1
  for contour in glyph.contours {
    for point in contour.points {
      points.push(point)
      end_point = end_point + 1
    }
    sun_test_append_u16(out, end_point)
  }
  sun_test_append_u16(out, 0)

  let flags : Array[Int] = []
  let x_bytes : Array[Byte] = []
  let y_bytes : Array[Byte] = []
  let mut prev_x = 0
  let mut prev_y = 0
  for point in points {
    let dx = point.x - prev_x
    let dy = point.y - prev_y
    let mut flag = if point.on_curve { 0x01 } else { 0 }
    flag = flag.lor(sun_test_encode_x_delta(dx, x_bytes))
    flag = flag.lor(sun_test_encode_y_delta(dy, y_bytes))
    flags.push(flag)
    prev_x = point.x
    prev_y = point.y
  }

  for flag in flags {
    sun_test_append_byte(out, flag)
  }
  sun_test_append_array(out, x_bytes)
  sun_test_append_array(out, y_bytes)
  while out.length() % 2 != 0 {
    sun_test_append_byte(out, 0)
  }
  out
}

///|
fn sun_test_encode_x_delta(delta : Int, out : Array[Byte]) -> Int {
  if delta == 0 {
    0x10
  } else if delta.abs() <= 255 {
    sun_test_append_byte(out, delta.abs())
    if delta > 0 {
      0x12
    } else {
      0x02
    }
  } else {
    sun_test_append_i16(out, delta)
    0
  }
}

///|
fn sun_test_encode_y_delta(delta : Int, out : Array[Byte]) -> Int {
  if delta == 0 {
    0x20
  } else if delta.abs() <= 255 {
    sun_test_append_byte(out, delta.abs())
    if delta > 0 {
      0x24
    } else {
      0x04
    }
  } else {
    sun_test_append_i16(out, delta)
    0
  }
}

///|
fn sun_test_cmap_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 1)
  sun_test_append_u16(out, 3)
  sun_test_append_u16(out, 10)
  sun_test_append_u32(out, 12)
  sun_test_append_u16(out, 12)
  sun_test_append_u16(out, 0)
  sun_test_append_u32(out, 16 + glyphs.length() * 12)
  sun_test_append_u32(out, 0)
  sun_test_append_u32(out, glyphs.length())
  for i in 0..<glyphs.length() {
    sun_test_append_u32(out, glyphs[i].codepoint)
    sun_test_append_u32(out, glyphs[i].codepoint)
    sun_test_append_u32(out, i + 1)
  }
  out
}

///|
fn sun_test_append_u16(out : Array[Byte], value : Int) -> Unit {
  sun_test_append_byte(out, value >> 8)
  sun_test_append_byte(out, value)
}

///|
fn sun_test_append_i16(out : Array[Byte], value : Int) -> Unit {
  let unsigned = if value < 0 { value + 65536 } else { value }
  sun_test_append_u16(out, unsigned)
}

///|
fn sun_test_append_u32(out : Array[Byte], value : Int) -> Unit {
  sun_test_append_byte(out, value >> 24)
  sun_test_append_byte(out, value >> 16)
  sun_test_append_byte(out, value >> 8)
  sun_test_append_byte(out, value)
}

///|
fn sun_test_append_byte(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
}

///|
fn sun_test_append_bytes(out : Array[Byte], bytes : Bytes) -> Unit {
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
}

///|
fn sun_test_append_array(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn sun_test_append_zeroes(out : Array[Byte], count : Int) -> Unit {
  for _ in 0..<count {
    sun_test_append_byte(out, 0)
  }
}

///|
fn sun_test_pad4(out : Array[Byte]) -> Unit {
  while out.length() % 4 != 0 {
    sun_test_append_byte(out, 0)
  }
}

///|
fn sun_test_align4(value : Int) -> Int {
  if value % 4 == 0 {
    value
  } else {
    value + 4 - value % 4
  }
}

///|
fn sun_test_align2(value : Int) -> Int {
  if value % 2 == 0 {
    value
  } else {
    value + 1
  }
}

///|
fn sun_test_string_from_codepoints(codepoints : Array[Int]) -> String {
  let out = StringBuilder(size_hint=codepoints.length())
  for codepoint in codepoints {
    out.write_char(codepoint.unsafe_to_char())
  }
  out.to_string()
}
