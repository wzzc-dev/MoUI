///|
test "FontFace::from_bytes reports short input" {
  match parse_font_face_result(b"") {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 0)) => ()
    _ => abort("expected short input error")
  }
}

///|
test "FontFace::from_bytes reports invalid sfnt header" {
  let bytes = []
  append_u32(bytes, 0)
  append_zeroes(bytes, 8)
  match parse_font_face_result(Bytes::from_array(bytes)) {
    Err(FontParseError::InvalidFontHeader(0)) => ()
    _ => abort("expected invalid font header error")
  }
}

///|
test "FontFace::from_bytes reports missing required table" {
  match parse_font_face_result(make_font_with_tables([])) {
    Err(FontParseError::MissingTable("head")) => ()
    _ => abort("expected missing head table error")
  }

  let head = make_table_record("head", 28, 54)
  match parse_font_face_result(make_font_with_tables([head])) {
    Err(FontParseError::MissingTable("hhea")) => ()
    _ => abort("expected missing hhea table error")
  }
}

///|
test "FontFace::from_bytes validates table bounds and minimum lengths" {
  let out_of_bounds = make_table_record("head", 100, 54)
  match parse_font_face_result(make_font_directory_only([out_of_bounds])) {
    Err(FontParseError::TableOutOfBounds("head", 100, 54, 28)) => ()
    _ => abort("expected table bounds error")
  }

  let short_head = make_table_record("head", 28, 10)
  match parse_font_face_result(make_font_with_tables([short_head])) {
    Err(FontParseError::TableTooShort("head", 10, 54)) => ()
    _ => abort("expected table length error")
  }
}

///|
test "FontFace::from_bytes validates cmap format 12 group length" {
  let bytes = make_structural_font_with_cmap(make_bad_cmap_format12())
  match parse_font_face_result(bytes) {
    Err(FontParseError::TableTooShort("cmap", 16, 28)) => ()
    _ => abort("expected cmap group length error")
  }
}

///|
test "FontFace::from_bytes validates cmap format 12 group ranges" {
  let bytes = make_structural_font_with_cmap(make_bad_cmap_format12_range())
  match parse_font_face_result(bytes) {
    Err(FontParseError::InvalidCmapGroupRange(20, 10)) => ()
    _ => abort("expected cmap group range error")
  }
}

///|
test "FontFace::from_bytes validates structured core table errors" {
  let bad_loca_format = make_structural_font_with_core_tables(
    make_head_table_with(10, 2),
    make_hhea_table(),
    make_hmtx_table(),
    make_maxp_table(),
    make_empty_cmap_table(),
    make_loca_table(),
    [],
    None,
  )
  match parse_font_face_result(bad_loca_format) {
    Err(FontParseError::UnsupportedIndexToLocFormat(2)) => ()
    _ => abort("expected unsupported loca format error")
  }

  let missing_metrics = make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 0),
    make_hmtx_table(),
    make_maxp_table(),
    make_empty_cmap_table(),
    make_loca_table(),
    [],
    None,
  )
  match parse_font_face_result(missing_metrics) {
    Err(FontParseError::MissingHorizontalMetrics) => ()
    _ => abort("expected missing horizontal metrics error")
  }
}

///|
test "FontFace::from_bytes validates structured loca and cmap errors" {
  let unsorted_loca = make_structural_font_with_glyf([2, 0], [0, 0])
  match parse_font_face_result(unsorted_loca) {
    Err(FontParseError::UnsortedLocaOffsets) => ()
    _ => abort("expected unsorted loca offsets error")
  }

  let unsupported_cmap = make_structural_font_with_cmap(make_bad_cmap_version())
  match parse_font_face_result(unsupported_cmap) {
    Err(FontParseError::UnsupportedCmapVersion(1)) => ()
    _ => abort("expected unsupported cmap version error")
  }

  let odd_segment_count = make_structural_font_with_cmap(
    make_bad_cmap_format4_segment_count(),
  )
  match parse_font_face_result(odd_segment_count) {
    Err(FontParseError::InvalidCmapSegmentCount(3)) => ()
    _ => abort("expected invalid cmap segment count error")
  }

  let inverted_segment = make_structural_font_with_cmap(
    make_bad_cmap_format4_segment_range(),
  )
  match parse_font_face_result(inverted_segment) {
    Err(FontParseError::InvalidCmapSegmentRange(66, 65)) => ()
    _ => abort("expected invalid cmap segment range error")
  }
}

///|
test "FontFace::from_bytes validates structured glyph outline errors" {
  let unsorted_glyph = make_bad_unsorted_contour_glyph()
  let unsorted_contours = make_structural_font_with_glyf(
    [0, unsorted_glyph.length()],
    unsorted_glyph,
  )
  match parse_font_face_result(unsorted_contours) {
    Err(FontParseError::UnsortedGlyphContourEndpoints) => ()
    _ => abort("expected unsorted glyph contour endpoints error")
  }

  let repeated_flags = make_structural_font_with_glyf(
    [0, 16],
    make_bad_flag_repeat_glyph(),
  )
  match parse_font_face_result(repeated_flags) {
    Err(FontParseError::GlyphFlagRepeatOverflow) => ()
    _ => abort("expected glyph flag repeat overflow error")
  }
}

///|
test "FontFace::from_bytes validates cmap format 4 glyph id array reads" {
  let bytes = make_structural_font_with_cmap(
    make_bad_cmap_format4_range_offset(),
  )
  match parse_font_face_result(bytes) {
    Err(FontParseError::TableTooShort("cmap", 24, 28)) => ()
    _ => abort("expected cmap format 4 glyph array length error")
  }
}

///|
test "FontFace::from_bytes reads checked core metric tables" {
  let bytes = make_structural_font_with_core_tables(
    make_head_table_with(20, 0),
    make_hhea_table_with(15, -5, 3, 2),
    make_hmtx_table_two_metrics(),
    make_maxp_table_with(2),
    make_cmap_format4_mapping(),
    make_loca_table_from_offsets([0, 0, 0]),
    [],
    None,
  )
  match parse_font_face_result(bytes) {
    Ok(face) => {
      let metrics = face.get_metrics()
      assert_eq(metrics.units_per_em, 20)
      assert_eq(metrics.ascent, 15)
      assert_eq(metrics.descent, -5)
      assert_eq(metrics.line_gap, 3)
      let layout = TextLayout::layout(
        face,
        "A",
        LayoutConfig::new(max_width=20.0, font_size=10.0, line_height=10.0),
      )
      assert_eq(layout.get_width(), 3.5)
    }
    Err(_) => abort("expected checked core table font")
  }
}

///|
test "FontFace::from_bytes uses maxp glyph count to validate loca" {
  let bytes = make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table(),
    make_hmtx_table(),
    make_maxp_table_with(2),
    make_empty_cmap_table(),
    make_loca_table_from_offsets([0, 0]),
    [],
    None,
  )
  match parse_font_face_result(bytes) {
    Err(FontParseError::TableTooShort("loca", 4, 6)) => ()
    _ => abort("expected maxp-driven loca length error")
  }
}

///|
test "FontFace::from_bytes parses a structurally valid empty glyph font" {
  match parse_font_face_result(make_structural_font()) {
    Ok(face) => {
      let metrics = face.get_metrics()
      assert_eq(metrics.units_per_em, 10)
      assert_eq(metrics.ascent, 10)
      assert_eq(metrics.descent, 0)
      assert_eq(metrics.line_gap, 0)
      assert_eq(face.char_to_glyph(65), 0)
    }
    Err(_) => abort("expected valid structural font")
  }
}

///|
test "FontFace::from_data rejects unsupported nonzero font index" {
  let data = FontData::new(make_structural_font(), font_index=2)
  assert_eq(data.get_font_index(), 2)
  match data.parse() {
    Err(FontParseError::UnsupportedFontIndex(2)) => ()
    _ => abort("expected unsupported font index error")
  }
  match FontFace::from_data(data) {
    Err(FontParseError::UnsupportedFontIndex(2)) => ()
    _ => abort("expected unsupported font index error")
  }
}

///|
test "FontFaceCache::get_or_parse_result reports cache misses" {
  let cache = FontFaceCache::new()
  match cache.get_or_parse_result("ui", make_structural_font()) {
    Ok(result) => {
      assert_true(result.did_parse())
      assert_true(!result.did_hit_cache())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected parsed font face")
  }
  assert_eq(cache.len(), 1)

  match cache.get_or_parse_result("ui", b"not a font") {
    Ok(result) => {
      assert_true(!result.did_parse())
      assert_true(result.did_hit_cache())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected cache hit to avoid parsing invalid bytes")
  }
  assert_eq(cache.len(), 1)
}

///|
test "MemoryFontLoader loads registered font data and faces" {
  let loader = MemoryFontLoader::new()
  assert_true(loader.is_empty())
  let data = FontData::new(make_structural_font())
  assert_eq(data.get_font_index(), 0)
  ignore(loader.insert("ui", data))
  assert_eq(loader.len(), 1)
  assert_true(loader.contains("ui"))

  match load_font_data(loader, "ui") {
    Ok(loaded) => {
      assert_eq(loaded.get_font_index(), 0)
      assert_eq(loaded.get_data(), data.get_data())
    }
    Err(_) => abort("expected memory font data")
  }

  match load_font_face(loader, "ui") {
    Ok(face) => assert_eq(face.get_units_per_em(), 10)
    Err(_) => abort("expected memory font face")
  }

  let indexed = FontData::new(make_structural_font(), font_index=2)
  ignore(loader.insert("indexed", indexed))
  match load_font_data(loader, "indexed") {
    Ok(loaded) => assert_eq(loaded.get_font_index(), 2)
    Err(_) => abort("expected indexed memory font data")
  }
  match load_font_face(loader, "indexed") {
    Err(
      FontLoadError::FontParseFailed(
        "indexed",
        FontParseError::UnsupportedFontIndex(2)
      )
    ) => ()
    _ => abort("expected indexed memory font face to be rejected")
  }

  loader.remove("ui")
  assert_true(!loader.contains("ui"))
  match load_font_data(loader, "ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected missing font data")
  }
}

///|
test "FileFontLoader reports missing and unreadable font sources" {
  let loader = FileFontLoader::new()
  match load_font_data(loader, "ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected missing file font source")
  }

  let source = FontFileSource::new(
    "/private/tmp/sun-font-loader-missing.ttf",
    font_index=3,
  )
  assert_eq(source.get_path(), "/private/tmp/sun-font-loader-missing.ttf")
  assert_eq(source.get_font_index(), 3)
  ignore(loader.insert("ui", source))
  assert_eq(loader.len(), 1)
  assert_true(loader.contains("ui"))
  match load_font_data(loader, "ui") {
    Err(
      FontLoadError::FontFileReadFailed(
        "ui",
        "/private/tmp/sun-font-loader-missing.ttf"
      )
    ) => ()
    _ => abort("expected unreadable file font source")
  }
}

///|
test "FontFaceCache::get_or_load_result loads misses and reports hits" {
  let cache = FontFaceCache::new()
  let loader = MemoryFontLoader::new()
  ignore(loader.insert("ui", FontData::new(make_structural_font())))

  match cache.get_or_load_result("ui", loader) {
    Ok(first) => {
      assert_true(first.did_parse())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected loaded font face")
  }
  assert_eq(cache.len(), 1)

  loader.clear()
  match cache.get_or_load_result("ui", loader) {
    Ok(second) => {
      assert_true(!second.did_parse())
      assert_true(second.did_hit_cache())
      assert_eq(second.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected font load cache hit")
  }

  let bad_loader = MemoryFontLoader::new()
  ignore(bad_loader.insert("bad", FontData::new(b"bad")))
  match cache.get_or_load_result("bad", bad_loader) {
    Err(
      FontLoadError::FontParseFailed(
        "bad",
        FontParseError::UnexpectedEndOfData(0, 12, 3)
      )
    ) => ()
    _ => abort("expected loader-backed parse error")
  }
  assert_true(!cache.contains("bad"))
}

///|
test "FontFace::from_bytes parses cmap format 4 mappings" {
  let bytes = make_structural_font_with_cmap(make_cmap_format4_mapping())
  match parse_font_face_result(bytes) {
    Ok(face) => assert_eq(face.char_to_glyph(65), 1)
    Err(_) => abort("expected format 4 cmap font")
  }
}

///|
test "FontFace::from_bytes maps supplementary Unicode cmap format 12 groups" {
  let bytes = make_structural_font_with_core_tables(
    make_head_table_with(10, 1),
    make_hhea_table_with(10, 0, 0, 2),
    make_hmtx_table_two_metrics(),
    make_maxp_table_with(2),
    make_cmap_format12_mapping(),
    make_loca_long_table_from_offsets([0, 0, 0]),
    [],
    None,
  )
  match FontFace::from_bytes(bytes) {
    Ok(face) => {
      assert_eq(face.char_to_glyph(0x1F600), 1)
      assert_eq(face.char_to_glyph(0x1F601), 0)
      assert_true(face.has_glyph_for_char(0x1F600))
      assert_true(!face.has_glyph_for_char(0x1F601))
      let text = parser_test_string_from_codepoints([0x1F600])
      let layout = TextLayout::layout(
        face,
        text,
        LayoutConfig::new(max_width=20.0, font_size=10.0, line_height=10.0),
      )
      assert_eq(layout.run_count(), 1)
      assert_eq(layout.get_width(), 7.0)
      assert_eq(layout.get_runs()[0].glyph_count(), 1)
      assert_eq(layout.get_runs()[0].get_glyphs()[0].get_glyph_id(), 1)
    }
    Err(_) => abort("expected format 12 supplementary font face")
  }
}

///|
test "FontFace::from_bytes prefers full Unicode cmap over BMP cmap" {
  let bytes = make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 4),
    make_hmtx_table_with_advances([0, 5, 7, 9]),
    make_maxp_table_with(4),
    make_mixed_cmap_with_full_unicode(
      0,
      4,
      make_cmap_format12_a_and_emoji_subtable(),
      make_cmap_format4_a_subtable(),
    ),
    make_loca_table_from_offsets([0, 0, 0, 0, 0]),
    [],
    None,
  )
  match parse_font_face_result(bytes) {
    Ok(face) => {
      assert_eq(face.char_to_glyph(65), 2)
      assert_eq(face.char_to_glyph(0x1F600), 3)
    }
    Err(_) => abort("expected mixed cmap font to prefer format 12")
  }
}

///|
test "FontFace::from_bytes falls back to BMP cmap when full Unicode cmap is empty" {
  let bytes = make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 2),
    make_hmtx_table_with_advances([0, 5]),
    make_maxp_table_with(2),
    make_mixed_cmap_with_full_unicode(
      3,
      10,
      make_empty_cmap_format12_subtable(),
      make_cmap_format4_a_subtable(),
    ),
    make_loca_table_from_offsets([0, 0, 0]),
    [],
    None,
  )
  match parse_font_face_result(bytes) {
    Ok(face) => {
      assert_eq(face.char_to_glyph(65), 1)
      assert_eq(face.char_to_glyph(0x1F600), 0)
    }
    Err(_) => abort("expected mixed cmap font to fall back to format 4")
  }
}

///|
test "FontFace::from_bytes reads long loca glyph offsets" {
  let glyph = make_simple_triangle_glyph()
  let bytes = make_structural_font_with_core_tables(
    make_head_table_with(10, 1),
    make_hhea_table(),
    make_hmtx_table(),
    make_maxp_table(),
    make_empty_cmap_table(),
    make_loca_long_table_from_offsets([0, glyph.length()]),
    glyph,
    None,
  )
  match parse_font_face_result(bytes) {
    Ok(face) => {
      let cache = GlyphMaskCache::new()
      match
        cache.get_or_rasterize_face_glyph_result("long-loca", face, 0, 1.0) {
        Some(result) => {
          let placement = result.get_placement()
          assert_true(result.did_rasterize())
          assert_eq(placement.get_width(), 1)
          assert_eq(placement.get_height(), 1)
        }
        None => abort("expected long loca simple glyph mask")
      }
    }
    Err(_) => abort("expected long loca font")
  }
}

///|
test "FontFace::from_bytes validates glyf glyph byte requirements" {
  let bytes = make_structural_font_with_glyf([0, 4], [
    0x00, 0x01, // one contour
     0x00, 0x00, // xmin
     0x00, 0x00, // ymin
     0x00, 0x01, // xmax
     0x00, 0x01, // ymax
  ])
  match parse_font_face_result(bytes) {
    Err(FontParseError::TableTooShort("glyf", 4, 10)) => ()
    _ => abort("expected short glyph error")
  }
}

///|
test "FontFace::from_bytes parses simple glyph outline through checked path" {
  let glyph = make_simple_triangle_glyph()
  let bytes = make_structural_font_with_glyf([0, glyph.length()], glyph)
  match parse_font_face_result(bytes) {
    Ok(face) => {
      let cache = GlyphMaskCache::new()
      match cache.get_or_rasterize_face_glyph_result("triangle", face, 0, 1.0) {
        Some(first) => {
          assert_true(first.did_rasterize())
          assert_eq(first.get_mask().get_width(), 1)
          assert_eq(first.get_mask().get_height(), 1)
        }
        None => abort("expected simple glyph mask")
      }
      match cache.get_or_rasterize_face_glyph_result("triangle", face, 0, 1.0) {
        Some(second) => assert_true(!second.did_rasterize())
        None => abort("expected cached simple glyph mask")
      }
    }
    Err(_) => abort("expected simple glyph font")
  }
}

///|
test "FontFace::from_bytes validates composite glyph scale bytes" {
  let glyph = make_bad_scaled_composite_glyph()
  let bytes = make_structural_font_with_glyf([0, glyph.length()], glyph)
  match parse_font_face_result(bytes) {
    Err(FontParseError::TableTooShort("glyf", 18, 20)) => ()
    _ => abort("expected composite scale length error")
  }
}

///|
test "FontFace::from_bytes validates kern format 0 pair length" {
  let bytes = make_structural_font_with_kern(make_bad_kern_table())
  match parse_font_face_result(bytes) {
    Err(FontParseError::TableTooShort("kern", 14, 20)) => ()
    _ => abort("expected kern pair length error")
  }
}

///|
test "FontFace::from_bytes parses kern format 0 pairs" {
  let bytes = make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 2),
    make_hmtx_table_two_metrics(),
    make_maxp_table_with(3),
    make_cmap_format4_ab_mapping(),
    make_loca_table_from_offsets([0, 0, 0, 0]),
    [],
    Some(make_kern_table()),
  )
  match parse_font_face_result(bytes) {
    Ok(face) => {
      let layout = TextLayout::layout(
        face,
        "AB",
        LayoutConfig::new(max_width=20.0, font_size=10.0, line_height=10.0),
      )
      assert_eq(layout.get_width(), 11.0)
    }
    Err(_) => abort("expected kern pair font")
  }
}

///|
fn parse_font_face_result(data : Bytes) -> Result[FontFace, FontParseError] {
  FontFace::from_bytes(data)
}

///|
struct TestTableRecord {
  tag : String
  offset : Int
  length : Int
}

///|
fn make_table_record(
  tag : String,
  offset : Int,
  length : Int,
) -> TestTableRecord {
  { tag, offset, length }
}

///|
fn make_font_with_tables(tables : Array[TestTableRecord]) -> Bytes {
  let out = make_font_directory(tables)
  let mut data_len = out.length()
  for table in tables {
    data_len = data_len.max(table.offset + table.length)
  }
  while out.length() < data_len {
    append_byte(out, 0)
  }
  Bytes::from_array(out)
}

///|
fn make_font_directory_only(tables : Array[TestTableRecord]) -> Bytes {
  Bytes::from_array(make_font_directory(tables))
}

///|
fn make_font_directory(tables : Array[TestTableRecord]) -> Array[Byte] {
  let out = []
  append_u32(out, 0x00010000)
  append_u16(out, tables.length())
  append_u16(out, 0)
  append_u16(out, 0)
  append_u16(out, 0)
  for table in tables {
    append_tag(out, table.tag)
    append_u32(out, 0)
    append_u32(out, table.offset)
    append_u32(out, table.length)
  }
  out
}

///|
fn make_structural_font_with_cmap(cmap : Array[Byte]) -> Bytes {
  make_structural_font_with_tables(cmap, make_loca_table(), [], None)
}

///|
fn make_structural_font() -> Bytes {
  make_structural_font_with_tables(
    make_empty_cmap_table(),
    make_loca_table(),
    [],
    None,
  )
}

///|
fn make_structural_font_with_glyf(
  loca_offsets : Array[Int],
  glyf : Array[Byte],
) -> Bytes {
  make_structural_font_with_tables(
    make_empty_cmap_table(),
    make_loca_table_from_offsets(loca_offsets),
    glyf,
    None,
  )
}

///|
fn make_structural_font_with_kern(kern : Array[Byte]) -> Bytes {
  make_structural_font_with_tables(
    make_empty_cmap_table(),
    make_loca_table(),
    [],
    Some(kern),
  )
}

///|
fn make_structural_font_with_tables(
  cmap : Array[Byte],
  loca : Array[Byte],
  glyf : Array[Byte],
  kern : Array[Byte]?,
) -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table(),
    make_hmtx_table(),
    make_maxp_table(),
    cmap,
    loca,
    glyf,
    kern,
  )
}

///|
fn make_structural_font_with_core_tables(
  head : Array[Byte],
  hhea : Array[Byte],
  hmtx : Array[Byte],
  maxp : Array[Byte],
  cmap : Array[Byte],
  loca : Array[Byte],
  glyf : Array[Byte],
  kern : Array[Byte]?,
) -> Bytes {
  let table_data = [
    ("head", head),
    ("hhea", hhea),
    ("hmtx", hmtx),
    ("cmap", cmap),
    ("loca", loca),
    ("glyf", glyf),
    ("maxp", maxp),
  ]
  match kern {
    Some(kern_table) => table_data.push(("kern", kern_table))
    None => ()
  }
  let table_count = table_data.length()
  let mut offset = 12 + table_count * 16
  let records = []
  for item in table_data {
    let (tag, bytes) = item
    records.push(make_table_record(tag, offset, bytes.length()))
    offset = offset + bytes.length()
  }
  let out = make_font_directory(records)
  for item in table_data {
    let (_, bytes) = item
    append_array(out, bytes)
  }
  Bytes::from_array(out)
}

///|
fn make_head_table() -> Array[Byte] {
  make_head_table_with(10, 0)
}

///|
fn make_head_table_with(
  units_per_em : Int,
  index_to_loc_format : Int,
) -> Array[Byte] {
  let out = []
  append_u32(out, 0x00010000)
  append_u32(out, 0)
  append_u32(out, 0)
  append_u32(out, 0x5F0F3CF5)
  append_u16(out, 0)
  append_u16(out, units_per_em)
  append_zeroes(out, 16)
  append_u16(out, 0)
  append_u16(out, 0)
  append_u16(out, 10)
  append_u16(out, 10)
  append_u16(out, 0)
  append_u16(out, 0)
  append_u16(out, 2)
  append_i16(out, index_to_loc_format)
  append_u16(out, 0)
  out
}

///|
fn make_hhea_table() -> Array[Byte] {
  make_hhea_table_with(10, 0, 0, 1)
}

///|
fn make_hhea_table_with(
  ascent : Int,
  descent : Int,
  line_gap : Int,
  num_h_metrics : Int,
) -> Array[Byte] {
  let out = []
  append_u32(out, 0x00010000)
  append_i16(out, ascent)
  append_i16(out, descent)
  append_i16(out, line_gap)
  append_u16(out, 10)
  append_u16(out, 0)
  append_u16(out, 0)
  append_u16(out, 10)
  append_u16(out, 1)
  append_u16(out, 0)
  append_u16(out, 0)
  append_zeroes(out, 8)
  append_u16(out, 0)
  append_u16(out, num_h_metrics)
  out
}

///|
fn make_hmtx_table() -> Array[Byte] {
  let out = []
  append_u16(out, 0)
  append_u16(out, 0)
  out
}

///|
fn make_hmtx_table_two_metrics() -> Array[Byte] {
  let out = []
  append_u16(out, 5)
  append_i16(out, -1)
  append_u16(out, 7)
  append_i16(out, -2)
  out
}

///|
fn make_hmtx_table_with_advances(advances : Array[Int]) -> Array[Byte] {
  let out = []
  for advance in advances {
    append_u16(out, advance)
    append_i16(out, 0)
  }
  out
}

///|
fn make_loca_table() -> Array[Byte] {
  make_loca_table_from_offsets([0, 0])
}

///|
fn make_loca_table_from_offsets(offsets : Array[Int]) -> Array[Byte] {
  let out = []
  for offset in offsets {
    append_u16(out, offset / 2)
  }
  out
}

///|
fn make_loca_long_table_from_offsets(offsets : Array[Int]) -> Array[Byte] {
  let out = []
  for offset in offsets {
    append_u32(out, offset)
  }
  out
}

///|
fn make_maxp_table() -> Array[Byte] {
  make_maxp_table_with(1)
}

///|
fn make_maxp_table_with(num_glyphs : Int) -> Array[Byte] {
  let out = []
  append_u32(out, 0x00010000)
  append_u16(out, num_glyphs)
  out
}

///|
fn make_bad_cmap_format12() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 10) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 16) // length only covers the header
  append_u32(out, 0) // language
  append_u32(out, 1) // nGroups requires 12 more bytes
  out
}

///|
fn make_bad_cmap_format12_range() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 10) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 28) // length
  append_u32(out, 0) // language
  append_u32(out, 1) // nGroups
  append_u32(out, 20) // startCharCode
  append_u32(out, 10) // endCharCode before startCharCode
  append_u32(out, 1) // startGlyphID
  out
}

///|
fn make_bad_cmap_version() -> Array[Byte] {
  let out = []
  append_u16(out, 1) // unsupported version
  append_u16(out, 0) // numTables
  out
}

///|
fn make_bad_cmap_format4_segment_count() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 1) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 4) // format
  append_u16(out, 16) // length
  append_u16(out, 0) // language
  append_u16(out, 3) // odd segCountX2
  append_u16(out, 0) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 0) // padding to declared length
  out
}

///|
fn make_bad_cmap_format4_segment_range() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 1) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 4) // format
  append_u16(out, 24) // length
  append_u16(out, 0) // language
  append_u16(out, 2) // segCountX2
  append_u16(out, 2) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 65) // endCode[0]
  append_u16(out, 0) // reservedPad
  append_u16(out, 66) // startCode[0] after endCode
  append_i16(out, 0) // idDelta[0]
  append_u16(out, 0) // idRangeOffset[0]
  out
}

///|
fn make_bad_cmap_format4_range_offset() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 1) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 4) // format
  append_u16(out, 24) // length: no glyphIdArray room for range offset
  append_u16(out, 0) // language
  append_u16(out, 2) // segCountX2
  append_u16(out, 2) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 65) // endCode[0]
  append_u16(out, 0) // reservedPad
  append_u16(out, 65) // startCode[0]
  append_i16(out, 0) // idDelta[0]
  append_u16(out, 4) // idRangeOffset[0] points past subtable length
  out
}

///|
fn make_cmap_format4_mapping() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 1) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 4) // format
  append_u16(out, 24) // length
  append_u16(out, 0) // language
  append_u16(out, 2) // segCountX2
  append_u16(out, 2) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 65) // endCode[0]
  append_u16(out, 0) // reservedPad
  append_u16(out, 65) // startCode[0]
  append_i16(out, -64) // 65 + delta -> glyph 1
  append_u16(out, 0) // idRangeOffset[0]
  out
}

///|
fn make_cmap_format4_ab_mapping() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 1) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 4) // format
  append_u16(out, 24) // length
  append_u16(out, 0) // language
  append_u16(out, 2) // segCountX2
  append_u16(out, 2) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 66) // endCode[0]
  append_u16(out, 0) // reservedPad
  append_u16(out, 65) // startCode[0]
  append_i16(out, -64) // 65 + delta -> glyph 1, 66 + delta -> glyph 2
  append_u16(out, 0) // idRangeOffset[0]
  out
}

///|
fn make_cmap_format12_mapping() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 10) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 28) // length
  append_u32(out, 0) // language
  append_u32(out, 1) // nGroups
  append_u32(out, 0x1F600) // startCharCode
  append_u32(out, 0x1F600) // endCharCode
  append_u32(out, 1) // startGlyphID
  out
}

///|
fn make_mixed_cmap_with_full_unicode(
  full_platform_id : Int,
  full_encoding_id : Int,
  full_unicode_subtable : Array[Byte],
  bmp_subtable : Array[Byte],
) -> Array[Byte] {
  let out = []
  let full_unicode_offset = 4 + 2 * 8
  let bmp_offset = full_unicode_offset + full_unicode_subtable.length()
  append_u16(out, 0) // version
  append_u16(out, 2) // numTables
  append_u16(out, full_platform_id)
  append_u16(out, full_encoding_id)
  append_u32(out, full_unicode_offset)
  append_u16(out, 3) // platform
  append_u16(out, 1) // BMP encoding
  append_u32(out, bmp_offset)
  append_array(out, full_unicode_subtable)
  append_array(out, bmp_subtable)
  out
}

///|
fn make_cmap_format4_a_subtable() -> Array[Byte] {
  let out = []
  append_u16(out, 4) // format
  append_u16(out, 24) // length
  append_u16(out, 0) // language
  append_u16(out, 2) // segCountX2
  append_u16(out, 2) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 65) // endCode[0]
  append_u16(out, 0) // reservedPad
  append_u16(out, 65) // startCode[0]
  append_i16(out, -64) // 65 + delta -> glyph 1
  append_u16(out, 0) // idRangeOffset[0]
  out
}

///|
fn make_cmap_format12_a_and_emoji_subtable() -> Array[Byte] {
  let out = []
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 40) // length
  append_u32(out, 0) // language
  append_u32(out, 2) // nGroups
  append_u32(out, 65) // startCharCode
  append_u32(out, 65) // endCharCode
  append_u32(out, 2) // startGlyphID
  append_u32(out, 0x1F600) // startCharCode
  append_u32(out, 0x1F600) // endCharCode
  append_u32(out, 3) // startGlyphID
  out
}

///|
fn make_empty_cmap_format12_subtable() -> Array[Byte] {
  let out = []
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 16) // length
  append_u32(out, 0) // language
  append_u32(out, 0) // nGroups
  out
}

///|
fn make_empty_cmap_table() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 10) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 16) // length
  append_u32(out, 0) // language
  append_u32(out, 0) // nGroups
  out
}

///|
fn make_bad_kern_table() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // nTables
  append_u16(out, 0) // subtable version
  append_u16(out, 14) // subtable length: header only
  append_u16(out, 0) // coverage format 0
  append_u16(out, 1) // nPairs requires one 6-byte pair
  append_u16(out, 0) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  out
}

///|
fn make_kern_table() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // nTables
  append_u16(out, 0) // subtable version
  append_u16(out, 20) // subtable length
  append_u16(out, 0) // coverage format 0
  append_u16(out, 1) // nPairs
  append_u16(out, 0) // searchRange
  append_u16(out, 0) // entrySelector
  append_u16(out, 0) // rangeShift
  append_u16(out, 1) // left
  append_u16(out, 2) // right
  append_i16(out, -3) // value
  out
}

///|
fn make_simple_triangle_glyph() -> Array[Byte] {
  let out = []
  append_i16(out, 1) // numberOfContours
  append_i16(out, 0) // xmin
  append_i16(out, 0) // ymin
  append_i16(out, 1) // xmax
  append_i16(out, 1) // ymax
  append_u16(out, 2) // endPtsOfContours[0]
  append_u16(out, 0) // instructionLength
  append_byte(out, 0x31) // on-curve, x same, y same
  append_byte(out, 0x33) // on-curve, x short positive, y same
  append_byte(out, 0x35) // on-curve, x same, y short positive
  append_byte(out, 1) // x delta for point 1
  append_byte(out, 1) // y delta for point 2
  append_byte(out, 0) // even length for short loca entries
  out
}

///|
fn make_bad_scaled_composite_glyph() -> Array[Byte] {
  let out = []
  append_i16(out, -1) // composite glyph
  append_i16(out, 0) // xmin
  append_i16(out, 0) // ymin
  append_i16(out, 1) // xmax
  append_i16(out, 1) // ymax
  append_u16(out, 0x000B) // words, xy values, scale
  append_u16(out, 0) // glyphIndex
  append_i16(out, 0) // x
  append_i16(out, 0) // y
  out
}

///|
fn make_bad_unsorted_contour_glyph() -> Array[Byte] {
  let out = []
  append_i16(out, 2) // numberOfContours
  append_i16(out, 0) // xmin
  append_i16(out, 0) // ymin
  append_i16(out, 1) // xmax
  append_i16(out, 1) // ymax
  append_u16(out, 2) // first contour endpoint
  append_u16(out, 2) // second contour endpoint is not greater
  append_u16(out, 0) // instructionLength
  out
}

///|
fn make_bad_flag_repeat_glyph() -> Array[Byte] {
  let out = []
  append_i16(out, 1) // numberOfContours
  append_i16(out, 0) // xmin
  append_i16(out, 0) // ymin
  append_i16(out, 1) // xmax
  append_i16(out, 1) // ymax
  append_u16(out, 1) // two points
  append_u16(out, 0) // instructionLength
  append_byte(out, 0x39) // repeat flag, on-curve, x/y same
  append_byte(out, 2) // repeats to three flags total for two points
  out
}

///|
fn append_i16(out : Array[Byte], value : Int) -> Unit {
  let unsigned = if value < 0 { value + 65536 } else { value }
  append_u16(out, unsigned)
}

///|
fn append_tag(out : Array[Byte], tag : String) -> Unit {
  for i in 0..<4 {
    let byte = if i < tag.length() { tag.code_unit_at(i).to_int() } else { 0 }
    append_byte(out, byte)
  }
}

///|
fn append_u16(out : Array[Byte], value : Int) -> Unit {
  append_byte(out, value >> 8)
  append_byte(out, value)
}

///|
fn append_u32(out : Array[Byte], value : Int) -> Unit {
  append_byte(out, value >> 24)
  append_byte(out, value >> 16)
  append_byte(out, value >> 8)
  append_byte(out, value)
}

///|
fn append_array(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn append_byte(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
}

///|
fn append_zeroes(out : Array[Byte], count : Int) -> Unit {
  for _ in 0..<count {
    append_byte(out, 0)
  }
}

///|
fn parser_test_string_from_codepoints(codepoints : Array[Int]) -> String {
  let out = StringBuilder(size_hint=codepoints.length())
  for codepoint in codepoints {
    out.write_char(codepoint.unsafe_to_char())
  }
  out.to_string()
}
