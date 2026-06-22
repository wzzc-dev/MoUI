///|
test "parse_glyph reads signed byte xy args for composite glyphs" {
  let bytes = Bytes::from_array(make_signed_byte_composite())
  match parse_glyph_checked(bytes, 0, bytes.length()) {
    Ok(GlyphData::Composite(components)) => {
      assert_eq(components.length(), 1)
      let component = components[0]
      assert_eq(component.glyph_index, 7)
      assert_eq(component.x_offset, -2)
      assert_eq(component.y_offset, 3)
      assert_eq(component.scale_x, 1.0)
      assert_eq(component.scale_y, 1.0)
    }
    Err(_) => abort("expected composite glyph parse success")
    _ => abort("expected composite glyph")
  }
}

///|
test "parse_glyph reads composite scale modes" {
  let bytes = Bytes::from_array(make_scaled_composite())
  match parse_glyph_checked(bytes, 0, bytes.length()) {
    Ok(GlyphData::Composite(components)) => {
      assert_eq(components.length(), 3)
      assert_eq(components[0].scale_x, 0.5)
      assert_eq(components[0].scale_y, 0.5)
      assert_eq(components[1].scale_x, 0.5)
      assert_eq(components[1].scale_y, 1.5)
      assert_eq(components[2].scale_x, 1.0)
      assert_eq(components[2].scale_xy, 0.5)
      assert_eq(components[2].scale_yx, -0.5)
      assert_eq(components[2].scale_y, 1.0)
    }
    Err(_) => abort("expected composite glyph parse success")
    _ => abort("expected composite glyph")
  }
}

///|
test "Font::get_glyph resolves composite transforms" {
  let font = make_composite_transform_font()
  match font.get_glyph(2) {
    GlyphData::Simple(simple) => {
      assert_eq(simple.contours.length(), 3)
      assert_point(simple.contours[0].points[0], 11, 0)
      assert_point(simple.contours[1].points[0], 21, 6)
      assert_point(simple.contours[2].points[0], 34, 3)
      assert_eq(simple.xmin, 11)
      assert_eq(simple.ymin, 0)
      assert_eq(simple.xmax, 37)
      assert_eq(simple.ymax, 9)
    }
    _ => abort("expected resolved simple glyph")
  }
}

///|
fn assert_point(point : GlyphPoint, x : Int, y : Int) -> Unit raise {
  assert_eq(point.x, x)
  assert_eq(point.y, y)
}

///|
fn make_composite_transform_font() -> Font {
  {
    head: { units_per_em: 10, index_to_loc_format: 0 },
    hhea: { ascent: 10, descent: 0, line_gap: 0, num_h_metrics: 3 },
    hmtx: [
      { advance_width: 0, lsb: 0 },
      { advance_width: 10, lsb: 0 },
      { advance_width: 10, lsb: 0 },
    ],
    cmap: {},
    glyphs: [
      GlyphData::Empty,
      GlyphData::Simple(make_transform_base_glyph()),
      GlyphData::Composite([
        {
          glyph_index: 1,
          x_offset: 10,
          y_offset: -2,
          scale_x: 0.5,
          scale_y: 0.5,
          scale_xy: 0.0,
          scale_yx: 0.0,
        },
        {
          glyph_index: 1,
          x_offset: 20,
          y_offset: 0,
          scale_x: 0.5,
          scale_y: 1.5,
          scale_xy: 0.0,
          scale_yx: 0.0,
        },
        {
          glyph_index: 1,
          x_offset: 30,
          y_offset: 0,
          scale_x: 1.0,
          scale_y: 1.0,
          scale_xy: 0.5,
          scale_yx: -0.5,
        },
      ]),
    ],
    glyph_count: 3,
    kern: [],
  }
}

///|
fn make_transform_base_glyph() -> SimpleGlyph {
  {
    contours: [
      {
        points: [
          { x: 2, y: 4, on_curve: true },
          { x: 4, y: 4, on_curve: true },
          { x: 4, y: 6, on_curve: true },
        ],
      },
    ],
    xmin: 2,
    ymin: 4,
    xmax: 4,
    ymax: 6,
  }
}

///|
fn make_signed_byte_composite() -> Array[Byte] {
  let out = make_composite_header()
  composite_append_u16(out, 0x0002) // byte args, xy values
  composite_append_u16(out, 7)
  composite_append_byte(out, -2)
  composite_append_byte(out, 3)
  out
}

///|
fn make_scaled_composite() -> Array[Byte] {
  let out = make_composite_header()

  composite_append_u16(out, 0x002B) // words, xy values, scale, more
  composite_append_u16(out, 1)
  composite_append_i16(out, 0)
  composite_append_i16(out, 0)
  composite_append_i16(out, 8192) // 0.5

  composite_append_u16(out, 0x0063) // words, xy values, x/y scale, more
  composite_append_u16(out, 1)
  composite_append_i16(out, 0)
  composite_append_i16(out, 0)
  composite_append_i16(out, 8192) // 0.5
  composite_append_i16(out, 24576) // 1.5

  composite_append_u16(out, 0x0083) // words, xy values, two-by-two matrix
  composite_append_u16(out, 1)
  composite_append_i16(out, 0)
  composite_append_i16(out, 0)
  composite_append_i16(out, 16384) // 1.0
  composite_append_i16(out, 8192) // 0.5
  composite_append_i16(out, -8192) // -0.5
  composite_append_i16(out, 16384) // 1.0
  out
}

///|
fn make_composite_header() -> Array[Byte] {
  let out : Array[Byte] = []
  composite_append_i16(out, -1) // numberOfContours: composite glyph
  composite_append_i16(out, 0)
  composite_append_i16(out, 0)
  composite_append_i16(out, 10)
  composite_append_i16(out, 10)
  out
}

///|
fn composite_append_u16(out : Array[Byte], value : Int) -> Unit {
  composite_append_byte(out, value >> 8)
  composite_append_byte(out, value)
}

///|
fn composite_append_i16(out : Array[Byte], value : Int) -> Unit {
  let unsigned = if value < 0 { value + 65536 } else { value }
  composite_append_u16(out, unsigned)
}

///|
fn composite_append_byte(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
}
