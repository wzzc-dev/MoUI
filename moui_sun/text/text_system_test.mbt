///|
fn make_text_system_ab_font() -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 3),
    make_text_system_ab_hmtx_table(),
    make_maxp_table_with(3),
    make_cmap_format4_ab_mapping(),
    make_loca_table_from_offsets([0, 0, 0, 0]),
    [],
    None,
  )
}

///|
fn make_text_system_ab_hmtx_table() -> Array[Byte] {
  let out = []
  append_u16(out, 5) // .notdef fallback and space width
  append_i16(out, 0)
  append_u16(out, 5) // A
  append_i16(out, 0)
  append_u16(out, 7) // B
  append_i16(out, 0)
  out
}

///|
fn make_text_system_bearing_font() -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 3),
    make_text_system_bearing_hmtx_table(),
    make_maxp_table_with(3),
    make_cmap_format4_ab_mapping(),
    make_loca_table_from_offsets([0, 0, 0, 0]),
    [],
    None,
  )
}

///|
fn make_text_system_bearing_hmtx_table() -> Array[Byte] {
  let out = []
  append_u16(out, 5)
  append_i16(out, 0)
  append_u16(out, 5)
  append_i16(out, 2)
  append_u16(out, 7)
  append_i16(out, -1)
  out
}

///|
fn make_text_system_wide_font() -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 3),
    make_text_system_wide_hmtx_table(),
    make_maxp_table_with(3),
    make_cmap_format4_ab_mapping(),
    make_loca_table_from_offsets([0, 0, 0, 0]),
    [],
    None,
  )
}

///|
fn make_text_system_wide_hmtx_table() -> Array[Byte] {
  let out = []
  append_u16(out, 5)
  append_i16(out, 0)
  append_u16(out, 9)
  append_i16(out, 0)
  append_u16(out, 11)
  append_i16(out, 0)
  out
}

///|
fn make_text_system_tall_font() -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(20, 0, 0, 3),
    make_text_system_ab_hmtx_table(),
    make_maxp_table_with(3),
    make_cmap_format4_ab_mapping(),
    make_loca_table_from_offsets([0, 0, 0, 0]),
    [],
    None,
  )
}

///|
fn make_text_system_emoji_font() -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table_with(10, 1),
    make_hhea_table_with(10, 0, 0, 2),
    make_hmtx_table_two_metrics(),
    make_maxp_table_with(2),
    make_cmap_format12_mapping(),
    make_loca_long_table_from_offsets([0, 0, 0]),
    [],
    None,
  )
}

///|
fn make_text_system_cjk_font() -> Bytes {
  make_structural_font_with_core_tables(
    make_head_table(),
    make_hhea_table_with(10, 0, 0, 4),
    make_hmtx_table_with_advances([0, 10, 10, 10]),
    make_maxp_table_with(4),
    make_cmap_format12_cjk_mapping(),
    make_loca_table_from_offsets([0, 0, 0, 0, 0]),
    [],
    None,
  )
}

///|
fn make_cmap_format12_cjk_mapping() -> Array[Byte] {
  let out = []
  append_u16(out, 0) // version
  append_u16(out, 1) // numTables
  append_u16(out, 3) // platform
  append_u16(out, 10) // encoding
  append_u32(out, 12) // subtable offset
  append_u16(out, 12) // format
  append_u16(out, 0) // reserved
  append_u32(out, 52) // length
  append_u32(out, 0) // language
  append_u32(out, 3) // nGroups
  append_u32(out, 0x4E00) // startCharCode
  append_u32(out, 0x4E00) // endCharCode
  append_u32(out, 1) // startGlyphID
  append_u32(out, 0x4E09) // startCharCode
  append_u32(out, 0x4E09) // endCharCode
  append_u32(out, 2) // startGlyphID
  append_u32(out, 0x4E8C) // startCharCode
  append_u32(out, 0x4E8C) // endCharCode
  append_u32(out, 3) // startGlyphID
  out
}

///|
fn register_text_system_ab_font(system : TextSystem) -> Unit {
  match system.register_font_bytes("ui", make_text_system_ab_font()) {
    Ok(_) => ()
    Err(_) => abort("expected registered text-system font")
  }
}

///|
fn write_text_system_font_fixture(path : String, data : Bytes) -> Unit {
  write_file(path, data) catch {
    _ => abort("expected writable text-system font fixture")
  }
}

///|
test "TextSystem registers checked font data" {
  let system = TextSystem::new()
  assert_eq(system.font_count(), 0)
  assert_true(!system.contains_font("ui"))

  let font_data = FontData::new(make_text_system_ab_font())
  match system.register_font_data("ui", font_data) {
    Ok(face) => {
      assert_eq(face.get_units_per_em(), 10)
      assert_eq(system.font_count(), 1)
      assert_true(system.contains_font("ui"))
    }
    Err(_) => abort("expected registered font data")
  }

  match system.get_font_data("ui") {
    Ok(data) => assert_eq(data.get_font_index(), 0)
    Err(_) => abort("expected registered font data")
  }

  match system.register_font_data("bad", FontData::new(b"not-font")) {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid font data to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_true(!system.contains_font("bad"))

  match system.register_font_data("ui", FontData::new(b"not-font")) {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid replacement font data to be rejected")
  }
  assert_eq(system.font_count(), 1)
  match system.get_font_face("ui") {
    Ok(face) => assert_eq(face.get_units_per_em(), 10)
    Err(_) => abort("expected existing font to survive invalid replacement")
  }
}

///|
test "TextSystem rejects empty font data without mutating registry" {
  let system = TextSystem::new()

  match system.register_font_data("empty", FontData::new(b"")) {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 0)) => ()
    _ => abort("expected empty font data to be rejected")
  }
  assert_eq(system.font_count(), 0)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_font("empty"))
  assert_true(!system.contains_cached_font_face("empty"))
  assert_eq(system.get_font_keys().length(), 0)
  assert_true(system.get_font_key(0) is None)

  let original_font = make_text_system_ab_font()
  match system.register_font_bytes("ui", original_font) {
    Ok(face) => assert_eq(face.get_units_per_em(), 10)
    Err(_) => abort("expected initial font registration")
  }
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)

  match system.register_font_bytes("ui", b"") {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 0)) => ()
    _ => abort("expected empty font-byte replacement to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), original_font.length())
    }
    Err(_) => abort("expected original font data after empty replacement")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected original layout after empty replacement")
  }
}

///|
test "TextSystem registers checked font files" {
  let system = TextSystem::new()
  let path = "/private/tmp/sun-text-system-register-font-file.ttf"
  let font_bytes = make_text_system_wide_font()
  write_text_system_font_fixture(path, font_bytes)

  match system.register_font_file_result("ui", path) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), font_bytes.length())
      assert_true(system.contains_font("ui"))
      assert_true(system.contains_cached_font_face("ui"))
    }
    Err(_) => abort("expected file-backed font registration")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected file-backed caret geometry")
  }
}

///|
test "TextSystem register_font_file returns checked face" {
  let system = TextSystem::new()
  let path = "/private/tmp/sun-text-system-register-font-file-face.ttf"
  write_text_system_font_fixture(path, make_text_system_ab_font())

  match system.register_font_file("ui", path) {
    Ok(face) => {
      assert_eq(face.get_units_per_em(), 10)
      assert_eq(system.font_count(), 1)
      assert_true(system.contains_font("ui"))
      assert_true(system.contains_cached_font_face("ui"))
    }
    Err(_) => abort("expected file-backed font face")
  }
}

///|
test "TextSystem register_font_file errors preserve registry" {
  let system = TextSystem::new()
  let original_font = make_text_system_ab_font()
  match system.register_font_bytes_result("ui", original_font) {
    Ok(_) => ()
    Err(_) => abort("expected initial memory font")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_cached_font_face("ui"))

  let missing_path = "/private/tmp/sun-text-system-register-font-file-missing/nope.ttf"
  match system.register_font_file_result("ui", missing_path) {
    Err(FontLoadError::FontFileReadFailed("ui", path)) =>
      assert_eq(path, missing_path)
    _ => abort("expected missing file to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))

  let invalid_path = "/private/tmp/sun-text-system-register-font-file-invalid.ttf"
  write_text_system_font_fixture(invalid_path, b"not-font")
  match system.register_font_file_result("bad", invalid_path) {
    Err(
      FontLoadError::FontParseFailed(
        "bad",
        FontParseError::UnexpectedEndOfData(0, 12, 8)
      )
    ) => ()
    _ => abort("expected invalid file font to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_true(!system.contains_font("bad"))
  assert_true(!system.contains_cached_font_face("bad"))

  let indexed_path = "/private/tmp/sun-text-system-register-font-file-indexed.ttf"
  write_text_system_font_fixture(indexed_path, make_text_system_wide_font())
  match system.register_font_file_result("ui", indexed_path, font_index=1) {
    Err(
      FontLoadError::FontParseFailed(
        "ui",
        FontParseError::UnsupportedFontIndex(1)
      )
    ) => ()
    _ => abort("expected indexed file font replacement to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 12.0)
    Err(_) => abort("expected original caret after file registration errors")
  }
}

///|
test "TextSystem register_font_file replaces font data and cached face" {
  let system = TextSystem::new()
  match system.register_font_bytes_result("ui", make_text_system_ab_font()) {
    Ok(_) => ()
    Err(_) => abort("expected initial font registration")
  }
  assert_true(system.contains_cached_font_face("ui"))

  let replacement_path = "/private/tmp/sun-text-system-register-font-file-replace.ttf"
  let replacement_font = make_text_system_wide_font()
  write_text_system_font_fixture(replacement_path, replacement_font)
  match system.register_font_file_result("ui", replacement_path) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(
        result.get_font_data().get_data().length(),
        replacement_font.length(),
      )
    }
    Err(_) => abort("expected file-backed replacement")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 20.0)
    Err(_) => abort("expected replacement caret geometry")
  }
}

///|
test "TextSystem implements FontLoader for registered font data" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  let replacement_font = make_text_system_wide_font()
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match load_font_data(system, "ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected missing TextSystem font data")
  }

  match system.register_font_data("ui", FontData::new(first_font)) {
    Ok(_) => ()
    Err(_) => abort("expected registered TextSystem font data")
  }
  match load_font_data(system, "ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), first_font.length())
    }
    Err(_) => abort("expected TextSystem FontLoader data")
  }
  match load_font_face(system, "ui") {
    Ok(face) => {
      assert_eq(face.get_units_per_em(), 10)
      assert_eq(TextLayout::layout(face, "AB", config).get_width(), 12.0)
    }
    Err(_) => abort("expected TextSystem FontLoader face")
  }

  match system.register_font_data("ui", FontData::new(replacement_font)) {
    Ok(_) => ()
    Err(_) => abort("expected TextSystem replacement font data")
  }
  match load_font_data(system, "ui") {
    Ok(data) => assert_eq(data.get_data().length(), replacement_font.length())
    Err(_) => abort("expected replaced TextSystem FontLoader data")
  }
  match load_font_face(system, "ui") {
    Ok(face) =>
      assert_eq(TextLayout::layout(face, "AB", config).get_width(), 20.0)
    Err(_) => abort("expected replaced TextSystem FontLoader face")
  }
}

///|
test "TextSystem register_font_data rejects unsupported nonzero font index" {
  let system = TextSystem::new()
  let font_bytes = make_text_system_ab_font()

  match
    system.register_font_data("ui", FontData::new(font_bytes, font_index=1)) {
    Err(FontParseError::UnsupportedFontIndex(1)) => ()
    _ => abort("expected nonzero font index to be rejected")
  }
  assert_eq(system.font_count(), 0)
  assert_true(!system.contains_font("ui"))
  assert_true(!system.contains_cached_font_face("ui"))

  match
    system.register_font_bytes(
      "bytes-face",
      make_text_system_ab_font(),
      font_index=3,
    ) {
    Err(FontParseError::UnsupportedFontIndex(3)) => ()
    _ => abort("expected nonzero byte font index wrapper to be rejected")
  }
  assert_eq(system.font_count(), 0)
  assert_true(!system.contains_font("bytes-face"))
  assert_true(!system.contains_cached_font_face("bytes-face"))

  match
    system.register_font_bytes_result(
      "bytes",
      make_text_system_ab_font(),
      font_index=2,
    ) {
    Err(FontParseError::UnsupportedFontIndex(2)) => ()
    _ => abort("expected nonzero byte font index to be rejected")
  }
  assert_eq(system.font_count(), 0)
  assert_true(!system.contains_font("bytes"))
}

///|
test "TextSystem register_font_data_result rejects unsupported font index without mutation" {
  let system = TextSystem::new()
  let font_bytes = make_text_system_ab_font()

  match
    system.register_font_data_result(
      "ui",
      FontData::new(font_bytes, font_index=1),
    ) {
    Err(FontParseError::UnsupportedFontIndex(1)) => ()
    _ => abort("expected direct font-data result index to be rejected")
  }
  assert_eq(system.font_count(), 0)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_font("ui"))
  assert_true(!system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) is None)

  match
    system.register_font_data_result(
      "negative",
      FontData::new(make_text_system_ab_font(), font_index=-1),
    ) {
    Err(FontParseError::UnsupportedFontIndex(-1)) => ()
    _ => abort("expected negative direct font-data result index to be rejected")
  }
  assert_eq(system.font_count(), 0)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_font("negative"))
  assert_true(!system.contains_cached_font_face("negative"))

  match system.register_font_data_result("ui", FontData::new(font_bytes)) {
    Ok(result) => {
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_font_index(), 0)
    }
    Err(_) => abort("expected original direct font-data registration")
  }
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))

  match
    system.register_font_data_result(
      "ui",
      FontData::new(make_text_system_wide_font(), font_index=2),
    ) {
    Err(FontParseError::UnsupportedFontIndex(2)) => ()
    _ => abort("expected direct indexed replacement to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data(), font_bytes)
    }
    Err(_) => abort("expected original direct font data to survive")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) =>
      abort("expected original layout after rejected direct replacement")
  }
  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(result.did_hit_cache())
      assert_true(!result.did_parse())
      assert_eq(
        TextLayout::layout(result.get_face(), "AB", config).get_width(),
        12.0,
      )
    }
    Err(_) => abort("expected cached original face after rejected replacement")
  }
}

///|
test "TextSystem nonzero font-index replacement preserves registered font data" {
  let system = TextSystem::new()
  let font_bytes = make_text_system_ab_font()
  match system.register_font_data("ui", FontData::new(font_bytes)) {
    Ok(_) => ()
    Err(_) => abort("expected initial font data registration")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_cached_font_face("ui"))

  match
    system.register_font_data(
      "ui",
      FontData::new(make_text_system_wide_font(), font_index=1),
    ) {
    Err(FontParseError::UnsupportedFontIndex(1)) => ()
    _ => abort("expected indexed replacement font data to be rejected")
  }

  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), font_bytes.length())
    }
    Err(_) =>
      abort("expected original font data to survive indexed replacement")
  }

  system.clear_font_face_cache()
  assert_true(!system.contains_cached_font_face("ui"))
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected original font data to reparse after cache clear")
  }
}

///|
test "TextSystem register_font_data_result replaces after clearing face cache" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(first_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_data().length(), first_font.length())
    }
    Err(_) => abort("expected initial font data registration")
  }
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))

  system.clear_font_face_cache()
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(system.contains_font("ui"))
  assert_true(!system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)

  let replacement_font = make_text_system_wide_font()
  match
    system.register_font_data_result("ui", FontData::new(replacement_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(
        result.get_font_data().get_data().length(),
        replacement_font.length(),
      )
    }
    Err(_) => abort("expected replacement after cache clear")
  }
  assert_eq(system.font_count(), 1)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), replacement_font.length())
    }
    Err(_) => abort("expected replaced font data after cache clear")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected replacement layout after cache clear")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
      assert_eq(caret.get_height(), 12.0)
      assert_eq(caret.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected replacement caret after cache clear")
  }
}

///|
test "TextSystem registers checked font bytes with FontData telemetry" {
  let system = TextSystem::new()
  let font_bytes = make_text_system_ab_font()
  match system.register_font_bytes_result("ui", font_bytes) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), font_bytes.length())
    }
    Err(_) => abort("expected font-byte registration result")
  }
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), font_bytes.length())
    }
    Err(_) => abort("expected registered font bytes")
  }
}

///|
test "TextSystem duplicate font-data registration reports key replacement" {
  let system = TextSystem::new()
  let font_bytes = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(font_bytes)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), font_bytes.length())
    }
    Err(_) => abort("expected initial duplicate-test font registration")
  }
  assert_true(system.contains_cached_font_face("ui"))

  match system.register_font_data_result("ui", FontData::new(font_bytes)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), font_bytes.length())
    }
    Err(_) => abort("expected duplicate font-data replacement")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  let keys = system.get_font_keys()
  assert_eq(keys.length(), 1)
  assert_eq(keys[0], "ui")
  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(result.did_hit_cache())
      assert_true(!result.did_parse())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected duplicate registration cache hit")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected duplicate registration layout")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected duplicate registration caret")
  }
}

///|
test "TextSystem registration result reports replacement and final count" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(first_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), first_font.length())
    }
    Err(_) => abort("expected initial registration result")
  }
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), first_font.length())
    }
    Err(_) => abort("expected registered font data")
  }

  let replacement_font = make_text_system_wide_font()
  match
    system.register_font_data_result("ui", FontData::new(replacement_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(
        result.get_font_data().get_data().length(),
        replacement_font.length(),
      )
    }
    Err(_) => abort("expected replacement registration result")
  }
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), replacement_font.length())
    }
    Err(_) => abort("expected replaced font data")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected replacement font layout")
  }

  match system.register_font_data_result("ui", FontData::new(b"not-font")) {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid replacement result to be rejected")
  }
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), replacement_font.length())
    }
    Err(_) => abort("expected invalid replacement to preserve font data")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  let keys = system.get_font_keys()
  assert_eq(keys.length(), 1)
  assert_eq(keys[0], "ui")
  keys[0] = "caller-mutated"
  assert_true(system.get_font_key(0) == Some("ui"))
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected invalid replacement to preserve layout")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 20.0)
      assert_eq(caret.get_y(), 0.0)
      assert_eq(caret.get_height(), 12.0)
      assert_eq(caret.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected invalid replacement to preserve caret")
  }
}

///|
test "TextSystem direct caret geometry uses replacement font data" {
  let system = TextSystem::new()
  match
    system.register_font_data_result(
      "ui",
      FontData::new(make_text_system_ab_font()),
    ) {
    Ok(result) => {
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
    }
    Err(_) => abort("expected initial font registration")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 12.0)
    Err(_) => abort("expected original caret geometry")
  }

  match
    system.register_font_data_result(
      "ui",
      FontData::new(make_text_system_wide_font()),
    ) {
    Ok(result) => {
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
    }
    Err(_) => abort("expected replacement font registration")
  }

  match system.caret_for_text("ui", "AB", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_x(), 9.0)
    }
    Err(_) => abort("expected replacement middle caret geometry")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected replacement trailing caret geometry")
  }
  match system.caret_at_text_position("ui", "AB", 14.6, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected replacement hit-test geometry")
  }
}

///|
test "TextSystem registration distinguishes font-data and cached-face replacement" {
  let system = TextSystem::with_font_cache_capacity(1)
  match system.register_font_bytes_result("ui", make_text_system_ab_font()) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_true(system.contains_cached_font_face("ui"))
    }
    Err(_) => abort("expected initial ui registration")
  }

  match
    system.register_font_bytes_result("wide", make_text_system_wide_font()) {
    Ok(result) => {
      assert_eq(result.get_key(), "wide")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_true(system.contains_cached_font_face("wide"))
      assert_true(!system.contains_cached_font_face("ui"))
    }
    Err(_) => abort("expected wide registration to evict ui cache")
  }

  match
    system.register_font_data_result(
      "ui",
      FontData::new(make_text_system_wide_font()),
    ) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 2)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_true(system.contains_cached_font_face("ui"))
      assert_true(!system.contains_cached_font_face("wide"))
    }
    Err(_) => abort("expected evicted ui cache replacement")
  }

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected evicted replacement font caret geometry")
  }
}

///|
test "TextSystem invalid register_font_data replacement preserves evicted cached face state" {
  let system = TextSystem::with_font_cache_capacity(1)
  let original_font = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(original_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_true(system.contains_cached_font_face("ui"))
    }
    Err(_) => abort("expected initial ui registration")
  }

  match
    system.register_font_data_result(
      "wide",
      FontData::new(make_text_system_wide_font()),
    ) {
    Ok(result) => {
      assert_eq(result.get_key(), "wide")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 2)
      assert_true(system.contains_cached_font_face("wide"))
      assert_true(!system.contains_cached_font_face("ui"))
    }
    Err(_) => abort("expected wide registration to evict ui cache")
  }

  match system.register_font_data_result("ui", FontData::new(b"not-font")) {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid evicted replacement to be rejected")
  }
  assert_eq(system.font_count(), 2)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_font("wide"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) == Some("wide"))
  assert_true(system.get_font_key(2) is None)
  assert_true(!system.contains_cached_font_face("ui"))
  assert_true(system.contains_cached_font_face("wide"))
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), original_font.length())
    }
    Err(_) => abort("expected original evicted font data to survive rejection")
  }

  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(result.did_parse())
      assert_true(!result.did_hit_cache())
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_true(system.contains_cached_font_face("ui"))
      assert_true(!system.contains_cached_font_face("wide"))
    }
    Err(_) => abort("expected original evicted font data to reparse")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected original evicted font data layout")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 12.0)
    Err(_) => abort("expected original evicted font data caret")
  }
}

///|
test "TextSystem tracks registered font keys in stable registration order" {
  let system = TextSystem::new()
  assert_eq(system.get_font_keys().length(), 0)
  assert_true(system.get_font_key(0) is None)

  match system.register_font_bytes("ui", make_text_system_ab_font()) {
    Ok(_) => ()
    Err(_) => abort("expected ui font")
  }
  match system.register_font_bytes("wide", make_text_system_wide_font()) {
    Ok(_) => ()
    Err(_) => abort("expected wide font")
  }
  assert_eq(system.font_count(), 2)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) == Some("wide"))
  assert_true(system.get_font_key(-1) is None)
  assert_true(system.get_font_key(2) is None)

  let keys = system.get_font_keys()
  assert_eq(keys.length(), 2)
  assert_eq(keys[0], "ui")
  assert_eq(keys[1], "wide")
  keys[0] = "caller-mutated"
  assert_true(system.get_font_key(0) == Some("ui"))

  match system.register_font_bytes("ui", make_text_system_wide_font()) {
    Ok(_) => ()
    Err(_) => abort("expected replacement ui font")
  }
  assert_eq(system.font_count(), 2)
  assert_eq(system.get_font_keys().length(), 2)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) == Some("wide"))

  match system.register_font_bytes("bad", b"not-font") {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid new font to be rejected")
  }
  match system.register_font_bytes("wide", b"not-font") {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid replacement font to be rejected")
  }
  assert_eq(system.font_count(), 2)
  assert_eq(system.get_font_keys().length(), 2)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) == Some("wide"))

  assert_true(system.remove_font("ui"))
  assert_eq(system.font_count(), 1)
  assert_eq(system.get_font_keys().length(), 1)
  assert_true(system.get_font_key(0) == Some("wide"))
  assert_true(!system.remove_font("missing"))
  assert_eq(system.get_font_keys().length(), 1)

  system.clear_fonts()
  assert_eq(system.font_count(), 0)
  assert_eq(system.get_font_keys().length(), 0)
  assert_true(system.get_font_key(0) is None)
}

///|
test "TextSystem lays out text from registered font data" {
  let system = TextSystem::with_font_cache_capacity(1)
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.layout_text("ui", "AB", config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 1)
      assert_eq(layout.get_width(), 12.0)
      assert_eq(layout.get_height(), 10.0)
      assert_eq(layout.get_baseline(), 10.0)
      let glyphs = layout.get_runs()[0].get_glyphs()
      assert_eq(glyphs.length(), 2)
      assert_eq(glyphs[0].get_x(), 0.0)
      assert_eq(glyphs[1].get_x(), 5.0)
    }
    Err(_) => abort("expected text-system layout")
  }

  match system.layout_text("missing", "AB", config) {
    Err(FontLoadError::MissingFontData("missing")) => ()
    _ => abort("expected missing text-system font")
  }
}

///|
test "TextSystem direct geometry APIs report missing registered font" {
  let system = TextSystem::new()
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("missing", "AB", 1, config) {
    Err(FontLoadError::MissingFontData("missing")) => ()
    _ => abort("expected missing font for direct caret geometry")
  }
  match system.caret_at_text_position("missing", "AB", 4.0, 0.0, config) {
    Err(FontLoadError::MissingFontData("missing")) => ()
    _ => abort("expected missing font for direct caret hit-test")
  }
  match system.selection_rects_for_text("missing", "AB", 0, 2, config) {
    Err(FontLoadError::MissingFontData("missing")) => ()
    _ => abort("expected missing font for direct selection geometry")
  }
}

///|
test "TextSystem font face result reports cache hits and reparses" {
  let system = TextSystem::with_font_cache_capacity(1)
  register_text_system_ab_font(system)

  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(result.did_hit_cache())
      assert_true(!result.did_parse())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected registered font face cache hit")
  }

  match system.register_font_bytes("wide", make_text_system_wide_font()) {
    Ok(_) => ()
    Err(_) => abort("expected second registered font")
  }
  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(!result.did_hit_cache())
      assert_true(result.did_parse())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected registered font data to reparse after eviction")
  }

  match system.get_font_face_result("missing") {
    Err(FontLoadError::MissingFontData("missing")) => ()
    _ => abort("expected missing text-system font face result")
  }
}

///|
test "TextSystem exposes and clears parsed font face cache state" {
  let system = TextSystem::with_font_cache_capacity(1)
  assert_true(system.is_font_face_cache_capacity_bounded())
  assert_eq(system.font_face_cache_capacity(), 1)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_cached_font_face("ui"))

  register_text_system_ab_font(system)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_cached_font_face("ui"))

  match system.register_font_bytes("wide", make_text_system_wide_font()) {
    Ok(_) => ()
    Err(_) => abort("expected wide text-system font")
  }
  assert_eq(system.font_count(), 2)
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.contains_cached_font_face("wide"))
  assert_true(!system.contains_cached_font_face("ui"))

  system.clear_font_face_cache()
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_cached_font_face("wide"))
  assert_true(system.contains_font("wide"))

  match system.get_font_face_result("wide") {
    Ok(result) => {
      assert_true(!result.did_hit_cache())
      assert_true(result.did_parse())
      assert_eq(system.font_face_cache_len(), 1)
      assert_true(system.contains_cached_font_face("wide"))
    }
    Err(_) => abort("expected wide font to reparse after cache clear")
  }
}

///|
test "TextSystem caret uses glyph advance origins instead of drawing bearings" {
  let system = TextSystem::new()
  match system.register_font_bytes("ui", make_text_system_bearing_font()) {
    Ok(_) => ()
    Err(_) => abort("expected bearing font")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.layout_text("ui", "AB", config) {
    Ok(layout) => {
      let glyphs = layout.get_runs()[0].get_glyphs()
      assert_eq(glyphs[0].get_x(), 2.0)
      assert_eq(glyphs[1].get_x(), 4.0)
      assert_eq(layout.get_width(), 12.0)
    }
    Err(_) => abort("expected bearing layout")
  }

  match system.caret_for_text("ui", "AB", 0, config) {
    Ok(caret) => assert_eq(caret.get_x(), 0.0)
    Err(_) => abort("expected start caret")
  }
  match system.caret_for_text("ui", "AB", 1, config) {
    Ok(caret) => assert_eq(caret.get_x(), 5.0)
    Err(_) => abort("expected middle caret")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 12.0)
    Err(_) => abort("expected end caret")
  }
}

///|
test "TextSystem computes single-line caret geometry" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("ui", "AB", -4, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 0.0)
      assert_eq(caret.get_height(), 12.0)
      assert_eq(caret.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected start caret")
  }

  match system.caret_for_text("ui", "AB", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected middle caret")
  }

  match system.caret_for_text("ui", "AB", 20, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected end caret")
  }
}

///|
test "TextSystem editor geometry preserves trailing spaces with spacing" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
    letter_spacing=1.0,
    word_spacing=2.0,
  )

  match system.layout_text("ui", "AB ", config) {
    Ok(layout) => {
      assert_eq(layout.get_width(), 20.0)
      let glyphs = layout.get_runs()[0].get_glyphs()
      assert_eq(glyphs.length(), 3)
      assert_eq(glyphs[0].get_x(), 0.0)
      assert_eq(glyphs[1].get_x(), 6.0)
      assert_eq(glyphs[2].get_x(), 13.0)
      assert_eq(glyphs[2].get_advance_width(), 7.0)
    }
    Err(_) => abort("expected trailing-space layout")
  }

  match system.caret_for_text("ui", "AB ", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 13.0)
    }
    Err(_) => abort("expected caret before trailing space")
  }
  match system.caret_for_text("ui", "AB ", 3, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected caret after trailing space")
  }

  match system.caret_at_text_position("ui", "AB ", 16.6, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected hit-test after trailing space")
  }

  match system.selection_rects_for_text("ui", "AB ", 2, 3, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 2)
      assert_eq(rects[0].get_end_index(), 3)
      assert_eq(rects[0].get_x(), 13.0)
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected trailing-space selection")
  }

  let prepared = match system.prepare_layout("ui", "AB ", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared trailing-space layout")
  }
  assert_eq(prepared.caret_for_index(3).get_x(), 20.0)
  assert_eq(prepared.caret_at_position(16.6, 4.0).get_index(), 3)
  let prepared_rects = prepared.selection_rects(2, 3)
  assert_eq(prepared_rects.length(), 1)
  assert_eq(prepared_rects[0].get_width(), 7.0)
}

///|
test "TextSystem tab caret geometry treats registered font data tabs as zero width" {
  let system = TextSystem::new()
  match
    system.register_font_data("ui", FontData::new(make_text_system_ab_font())) {
    Ok(_) => ()
    Err(_) => abort("expected registered font data")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.layout_text("ui", "A\tB", config) {
    Ok(layout) => {
      assert_eq(layout.get_width(), 12.0)
      assert_eq(layout.run_count(), 1)
      let glyphs = layout.get_runs()[0].get_glyphs()
      assert_eq(glyphs.length(), 2)
      assert_eq(glyphs[0].get_x(), 0.0)
      assert_eq(glyphs[1].get_x(), 5.0)
    }
    Err(_) => abort("expected tab layout")
  }

  match system.caret_for_text("ui", "A\tB", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected caret before tab")
  }
  match system.caret_for_text("ui", "A\tB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected caret after tab")
  }
  match system.caret_for_text("ui", "A\tB", 3, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected caret after B")
  }

  match system.caret_at_text_position("ui", "A\tB", 5.0, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected hit-test at zero-width tab")
  }
  match system.caret_at_text_position("ui", "A\tB", 8.6, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected hit-test after B")
  }

  match system.selection_rects_for_text("ui", "A\tB", 1, 2, config) {
    Ok(rects) => assert_eq(rects.length(), 0)
    Err(_) => abort("expected zero-width tab selection")
  }
  match system.selection_rects_for_text("ui", "A\tB", 1, 3, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 1)
      assert_eq(rects[0].get_end_index(), 3)
      assert_eq(rects[0].get_x(), 5.0)
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected tab-to-B selection")
  }
}

///|
test "TextSystem keeps zero-width tabs before soft-wrapped text on previous line" {
  let system = TextSystem::new()
  match
    system.register_font_data("ui", FontData::new(make_text_system_ab_font())) {
    Ok(_) => ()
    Err(_) => abort("expected registered font data")
  }
  let config = LayoutConfig::new(
    max_width=6.0,
    font_size=10.0,
    line_height=12.0,
  )
  let text = "A\tB"

  match system.layout_text("ui", text, config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 2)
      assert_eq(layout.get_width(), 7.0)
      assert_eq(layout.get_runs()[0].glyph_count(), 1)
      assert_eq(layout.get_runs()[0].get_width(), 5.0)
      assert_eq(layout.get_runs()[1].glyph_count(), 1)
      assert_eq(layout.get_runs()[1].get_width(), 7.0)
    }
    Err(_) => abort("expected soft-wrapped tab layout")
  }

  match system.caret_for_text("ui", text, 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected caret before soft-wrapped zero-width tab")
  }
  match system.caret_for_text("ui", text, 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
    }
    Err(_) => abort("expected caret after soft-wrapped zero-width tab")
  }
  match system.caret_at_text_position("ui", text, 80.0, 0.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected soft-wrap line-end hit before zero-width tab")
  }
  match system.caret_at_text_position("ui", text, -20.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected soft-wrap next-line hit after zero-width tab")
  }

  match system.selection_rects_for_text("ui", text, 1, 2, config) {
    Ok(rects) => assert_eq(rects.length(), 0)
    Err(_) => abort("expected zero-width soft-wrap tab selection")
  }
  match system.selection_rects_for_text("ui", text, 1, 3, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 2)
      assert_eq(rects[0].get_end_index(), 3)
      assert_eq(rects[0].get_line(), 1)
      assert_eq(rects[0].get_x(), 0.0)
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected soft-wrap tab-to-B selection")
  }

  let prepared = match system.prepare_layout("ui", text, config) {
    Ok(value) => value
    Err(_) => abort("expected prepared soft-wrapped tab layout")
  }
  assert_eq(prepared.caret_for_index(1).get_line(), 0)
  assert_eq(prepared.caret_for_index(1).get_x(), 5.0)
  assert_eq(prepared.caret_for_index(2).get_line(), 1)
  assert_eq(prepared.caret_for_index(2).get_x(), 0.0)
  assert_eq(prepared.caret_at_position(80.0, 0.0).get_index(), 1)
  assert_eq(prepared.caret_at_position(-20.0, 13.0).get_index(), 2)
  assert_eq(prepared.selection_rects(1, 2).length(), 0)
  let prepared_rects = prepared.selection_rects(1, 3)
  assert_eq(prepared_rects.length(), 1)
  assert_eq(prepared_rects[0].get_start_index(), 2)
}

///|
test "TextSystem keeps zero-width tabs before line breaks on the previous line" {
  let system = TextSystem::new()
  match
    system.register_font_data("ui", FontData::new(make_text_system_ab_font())) {
    Ok(_) => ()
    Err(_) => abort("expected registered font data")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let text = "A\t\nB"

  match system.layout_text("ui", text, config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 2)
      assert_eq(layout.get_runs()[0].glyph_count(), 1)
      assert_eq(layout.get_runs()[1].glyph_count(), 1)
    }
    Err(_) => abort("expected tab-before-newline layout")
  }

  match system.caret_for_text("ui", text, 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected caret before zero-width tab")
  }
  match system.caret_for_text("ui", text, 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected caret after zero-width tab")
  }

  match system.caret_for_text("ui", text, 4, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 4)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 7.0)
    }
    Err(_) => abort("expected second-line trailing caret")
  }

  match system.caret_at_text_position("ui", text, 4.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 4)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 7.0)
    }
    Err(_) => abort("expected second-line hit-test caret")
  }
  match system.caret_at_text_position("ui", text, 80.0, 0.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected line-end hit-test before zero-width tab")
  }

  match system.selection_rects_for_text("ui", text, 3, 4, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 3)
      assert_eq(rects[0].get_end_index(), 4)
      assert_eq(rects[0].get_line(), 1)
      assert_eq(rects[0].get_x(), 0.0)
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected second-line selection")
  }

  match system.selection_rects_for_text("ui", text, 1, 3, config) {
    Ok(rects) => assert_eq(rects.length(), 0)
    Err(_) => abort("expected zero-width tab and newline selection")
  }

  let prepared = match system.prepare_layout("ui", text, config) {
    Ok(value) => value
    Err(_) => abort("expected prepared tab-before-newline layout")
  }
  assert_eq(prepared.caret_for_index(1).get_line(), 0)
  assert_eq(prepared.caret_for_index(1).get_x(), 5.0)
  assert_eq(prepared.caret_for_index(2).get_line(), 0)
  assert_eq(prepared.caret_for_index(2).get_x(), 5.0)
  let prepared_hit = prepared.caret_at_position(80.0, 0.0)
  assert_eq(prepared_hit.get_index(), 1)
  assert_eq(prepared_hit.get_line(), 0)
  assert_eq(prepared.selection_rects(1, 3).length(), 0)
}

///|
test "TextSystem Unicode caret respects supplementary character boundaries" {
  let system = TextSystem::new()
  match system.register_font_bytes("emoji", make_text_system_emoji_font()) {
    Ok(_) => ()
    Err(_) => abort("expected emoji font")
  }
  let text = parser_test_string_from_codepoints([(0x1F600 : Int)])
  assert_eq(text.length(), 2)
  assert_eq(text.char_length(), 1)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.layout_text("emoji", text, config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 1)
      assert_eq(layout.get_width(), 7.0)
      assert_eq(layout.get_runs()[0].glyph_count(), 1)
    }
    Err(_) => abort("expected emoji layout")
  }

  match system.caret_for_text("emoji", text, 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), text.length())
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 7.0)
    }
    Err(_) => abort("expected normalized emoji caret")
  }

  match system.caret_at_text_position("emoji", text, 7.0, 0.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), text.length())
      assert_eq(caret.get_x(), 7.0)
    }
    Err(_) => abort("expected trailing emoji hit-test caret")
  }

  match system.selection_rects_for_text("emoji", text, 0, 1, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 0)
      assert_eq(rects[0].get_end_index(), text.length())
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected normalized emoji selection")
  }

  let prepared = match system.prepare_layout("emoji", text, config) {
    Ok(value) => value
    Err(_) => abort("expected prepared emoji layout")
  }
  assert_eq(prepared.caret_for_index(1).get_index(), text.length())
  assert_eq(prepared.caret_at_position(7.0, 0.0).get_index(), text.length())
  let prepared_rects = prepared.selection_rects(0, 1)
  assert_eq(prepared_rects.length(), 1)
  assert_eq(prepared_rects[0].get_start_index(), 0)
  assert_eq(prepared_rects[0].get_end_index(), text.length())
  assert_eq(prepared_rects[0].get_width(), 7.0)
}

///|
test "TextSystem computes empty text caret geometry" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("ui", "", 4, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 0.0)
      assert_eq(caret.get_height(), 12.0)
      assert_eq(caret.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected empty text caret")
  }
}

///|
test "TextSystem hit-tests single-line caret positions" {
  let system = TextSystem::new()
  match system.register_font_bytes("ui", make_text_system_bearing_font()) {
    Ok(_) => ()
    Err(_) => abort("expected bearing font")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_at_text_position("ui", "AB", -10.0, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected leading hit caret")
  }

  let nan = 0.0 / 0.0
  match system.caret_at_text_position("ui", "AB", nan, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected NaN x hit caret")
  }

  let positive_infinity = 1.0 / 0.0
  match
    system.caret_at_text_position("ui", "AB", positive_infinity, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected positive infinity x hit caret")
  }

  let negative_infinity = 0.0 - positive_infinity
  match
    system.caret_at_text_position("ui", "AB", negative_infinity, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected negative infinity x hit caret")
  }

  match system.caret_at_text_position("ui", "AB", 2.5, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected midpoint tie to prefer leading caret")
  }

  match system.caret_at_text_position("ui", "AB", 2.6, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_x(), 5.0)
    }
    Err(_) => abort("expected middle hit caret")
  }

  match system.caret_at_text_position("ui", "AB", 8.6, 80.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected trailing hit caret")
  }
}

///|
test "TextSystem editor geometry honors center-aligned multiline text" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=12.0,
    alignment=TextAlign::Center,
  )

  match system.caret_for_text("ui", "A\nAB", 0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 7.5)
      assert_eq(caret.get_y(), 0.0)
      assert_eq(caret.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected centered first-line leading caret")
  }
  match system.caret_for_text("ui", "A\nAB", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 12.5)
    }
    Err(_) => abort("expected centered first-line trailing caret")
  }
  match system.caret_for_text("ui", "A\nAB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 4.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected centered second-line leading caret")
  }
  match system.caret_for_text("ui", "A\nAB", 4, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 4)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 16.0)
    }
    Err(_) => abort("expected centered second-line trailing caret")
  }

  match system.caret_at_text_position("ui", "A\nAB", 10.1, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 12.5)
    }
    Err(_) => abort("expected centered first-line hit caret")
  }
  match system.caret_at_text_position("ui", "A\nAB", 12.6, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 4)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 16.0)
    }
    Err(_) => abort("expected centered second-line hit caret")
  }

  match system.selection_rects_for_text("ui", "A\nAB", 0, 4, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 2)
      let first = rects[0]
      assert_eq(first.get_start_index(), 0)
      assert_eq(first.get_end_index(), 1)
      assert_eq(first.get_line(), 0)
      assert_eq(first.get_x(), 7.5)
      assert_eq(first.get_y(), 0.0)
      assert_eq(first.get_width(), 5.0)
      assert_eq(first.get_height(), 12.0)
      assert_eq(first.get_baseline_y(), 10.0)

      let second = rects[1]
      assert_eq(second.get_start_index(), 2)
      assert_eq(second.get_end_index(), 4)
      assert_eq(second.get_line(), 1)
      assert_eq(second.get_x(), 4.0)
      assert_eq(second.get_y(), 12.0)
      assert_eq(second.get_width(), 12.0)
      assert_eq(second.get_height(), 12.0)
      assert_eq(second.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected centered selection rects")
  }

  let prepared = match system.prepare_layout("ui", "A\nAB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared centered layout")
  }
  assert_eq(prepared.caret_for_index(0).get_x(), 7.5)
  assert_eq(prepared.caret_for_index(4).get_x(), 16.0)
  assert_eq(prepared.caret_at_position(12.6, 13.0).get_index(), 4)
  let prepared_rects = prepared.selection_rects(0, 4)
  assert_eq(prepared_rects.length(), 2)
  assert_eq(prepared_rects[0].get_x(), 7.5)
  assert_eq(prepared_rects[1].get_x(), 4.0)
}

///|
test "TextSystem editor geometry honors right-aligned text" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=12.0,
    alignment=TextAlign::Right,
  )

  match system.caret_for_text("ui", "AB", 0, config) {
    Ok(caret) => assert_eq(caret.get_x(), 8.0)
    Err(_) => abort("expected right-aligned leading caret")
  }
  match system.caret_for_text("ui", "AB", 1, config) {
    Ok(caret) => assert_eq(caret.get_x(), 13.0)
    Err(_) => abort("expected right-aligned middle caret")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 20.0)
    Err(_) => abort("expected right-aligned trailing caret")
  }

  match system.caret_at_text_position("ui", "AB", 11.0, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_x(), 13.0)
    }
    Err(_) => abort("expected right-aligned hit caret")
  }

  match system.selection_rects_for_text("ui", "AB", 0, 2, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_x(), 8.0)
      assert_eq(rects[0].get_y(), 0.0)
      assert_eq(rects[0].get_width(), 12.0)
      assert_eq(rects[0].get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected right-aligned selection rect")
  }
}

///|
test "TextSystem editor geometry honors justified wrapped text" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=24.0,
    font_size=10.0,
    line_height=12.0,
    alignment=TextAlign::Justify,
  )

  match system.layout_text("ui", "A B A", config) {
    Ok(layout) => {
      let runs = layout.get_runs()
      assert_eq(runs.length(), 2)
      assert_eq(runs[0].get_width(), 24.0)
      let glyphs = runs[0].get_glyphs()
      assert_eq(glyphs.length(), 4)
      assert_eq(glyphs[0].get_x(), 0.0)
      assert_eq(glyphs[1].get_x(), 5.0)
      assert_eq(glyphs[1].get_advance_width(), 7.0)
      assert_eq(glyphs[2].get_x(), 12.0)
      assert_eq(glyphs[3].get_x(), 19.0)
    }
    Err(_) => abort("expected justified layout")
  }

  match system.caret_for_text("ui", "A B A", 0, config) {
    Ok(caret) => assert_eq(caret.get_x(), 0.0)
    Err(_) => abort("expected justified first caret")
  }
  match system.caret_for_text("ui", "A B A", 1, config) {
    Ok(caret) => assert_eq(caret.get_x(), 5.0)
    Err(_) => abort("expected justified second caret")
  }
  match system.caret_for_text("ui", "A B A", 2, config) {
    Ok(caret) => assert_eq(caret.get_x(), 12.0)
    Err(_) => abort("expected justified third caret")
  }
  match system.caret_for_text("ui", "A B A", 3, config) {
    Ok(caret) => assert_eq(caret.get_x(), 19.0)
    Err(_) => abort("expected justified fourth caret")
  }

  match system.caret_at_text_position("ui", "A B A", 9.0, 4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected justified hit caret")
  }

  match system.selection_rects_for_text("ui", "A B A", 0, 4, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      let rect = rects[0]
      assert_eq(rect.get_start_index(), 0)
      assert_eq(rect.get_end_index(), 4)
      assert_eq(rect.get_line(), 0)
      assert_eq(rect.get_x(), 0.0)
      assert_eq(rect.get_y(), 0.0)
      assert_eq(rect.get_width(), 24.0)
      assert_eq(rect.get_height(), 12.0)
      assert_eq(rect.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected justified selection rect")
  }

  let prepared = match system.prepare_layout("ui", "A B A", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared justified layout")
  }
  assert_eq(prepared.caret_for_index(3).get_x(), 19.0)
  assert_eq(prepared.caret_at_position(9.0, 4.0).get_index(), 2)
  let prepared_rects = prepared.selection_rects(0, 4)
  assert_eq(prepared_rects.length(), 1)
  assert_eq(prepared_rects[0].get_width(), 24.0)
}

///|
test "TextSystem hit-tests empty and multiline caret positions" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_at_text_position("ui", "", 50.0, -10.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 0.0)
      assert_eq(caret.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected empty hit caret")
  }

  let nan = 0.0 / 0.0
  match system.caret_at_text_position("ui", "A\nB", -20.0, nan, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 0)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected NaN y hit caret")
  }

  match system.caret_at_text_position("ui", "A\nB", 100.0, -4.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected first-line hit caret")
  }

  match system.caret_at_text_position("ui", "A\nB", -20.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected second-line leading hit caret")
  }

  match system.caret_at_text_position("ui", "A\nB", -20.0, 12.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected boundary hit caret on next visual line")
  }

  match system.caret_at_text_position("ui", "A\nB", 4.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 7.0)
    }
    Err(_) => abort("expected second-line trailing hit caret")
  }

  let prepared = match system.prepare_layout("ui", "A\nB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared multiline layout")
  }
  let boundary_caret = prepared.caret_at_position(-20.0, 12.0)
  assert_eq(boundary_caret.get_index(), 2)
  assert_eq(boundary_caret.get_line(), 1)
  assert_eq(boundary_caret.get_y(), 12.0)
  let prepared_nan_x = prepared.caret_at_position(nan, 13.0)
  assert_eq(prepared_nan_x.get_index(), 2)
  assert_eq(prepared_nan_x.get_line(), 1)
  assert_eq(prepared_nan_x.get_x(), 0.0)
  let prepared_nan_y = prepared.caret_at_position(-20.0, nan)
  assert_eq(prepared_nan_y.get_index(), 0)
  assert_eq(prepared_nan_y.get_line(), 0)
  assert_eq(prepared_nan_y.get_y(), 0.0)
  let positive_infinity = 1.0 / 0.0
  let direct_positive_y = match
    system.caret_at_text_position(
      "ui", "A\nB", -20.0, positive_infinity, config,
    ) {
    Ok(caret) => caret
    Err(_) => abort("expected positive infinity y hit caret")
  }
  assert_eq(direct_positive_y.get_index(), 2)
  assert_eq(direct_positive_y.get_line(), 1)
  assert_eq(direct_positive_y.get_x(), 0.0)
  assert_eq(direct_positive_y.get_y(), 12.0)
  let negative_infinity = 0.0 - positive_infinity
  let direct_negative_y = match
    system.caret_at_text_position(
      "ui", "A\nB", -20.0, negative_infinity, config,
    ) {
    Ok(caret) => caret
    Err(_) => abort("expected negative infinity y hit caret")
  }
  assert_eq(direct_negative_y.get_index(), 0)
  assert_eq(direct_negative_y.get_line(), 0)
  assert_eq(direct_negative_y.get_y(), 0.0)
  let prepared_positive = prepared.caret_at_position(
    positive_infinity, positive_infinity,
  )
  assert_eq(prepared_positive.get_index(), 3)
  assert_eq(prepared_positive.get_line(), 1)
  assert_eq(prepared_positive.get_x(), 7.0)
  assert_eq(prepared_positive.get_y(), 12.0)
  let prepared_negative = prepared.caret_at_position(
    negative_infinity, negative_infinity,
  )
  assert_eq(prepared_negative.get_index(), 0)
  assert_eq(prepared_negative.get_line(), 0)
  assert_eq(prepared_negative.get_x(), 0.0)
  assert_eq(prepared_negative.get_y(), 0.0)
}

///|
test "TextSystem maps newline and wrapped carets to visual lines" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=6.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("ui", "A\nB", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected newline-before caret")
  }

  match system.caret_for_text("ui", "A\nB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected newline-after caret")
  }

  match system.caret_for_text("ui", "A B", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
    }
    Err(_) => abort("expected wrapped caret")
  }
}

///|
test "TextSystem maps CJK soft-wrap editor geometry to visual lines" {
  let system = TextSystem::new()
  match
    system.register_font_data("cjk", FontData::new(make_text_system_cjk_font())) {
    Ok(_) => ()
    Err(_) => abort("expected CJK font data")
  }
  let text = parser_test_string_from_codepoints([0x4E00, 0x4E8C, 0x4E09])
  assert_eq(text.length(), 3)
  let config = LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )

  match system.layout_text("cjk", text, config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 2)
      assert_eq(layout.get_width(), 20.0)
      assert_eq(layout.get_height(), 20.0)
      let runs = layout.get_runs()
      assert_eq(runs[0].glyph_count(), 2)
      assert_eq(runs[0].get_width(), 20.0)
      assert_eq(runs[1].glyph_count(), 1)
      assert_eq(runs[1].get_width(), 10.0)
      assert_eq(runs[1].get_baseline_y(), 20.0)
    }
    Err(_) => abort("expected CJK TextSystem layout")
  }

  match system.caret_for_text("cjk", text, 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 10.0)
      assert_eq(caret.get_baseline_y(), 20.0)
    }
    Err(_) => abort("expected CJK soft-wrap boundary caret")
  }
  match system.caret_for_text("cjk", text, 3, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 10.0)
    }
    Err(_) => abort("expected trailing CJK caret")
  }

  match system.caret_at_text_position("cjk", text, 6.0, 11.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 10.0)
    }
    Err(_) => abort("expected CJK second-line hit-test caret")
  }

  match system.selection_rects_for_text("cjk", text, 1, 3, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 2)
      assert_eq(rects[0].get_start_index(), 1)
      assert_eq(rects[0].get_end_index(), 2)
      assert_eq(rects[0].get_line(), 0)
      assert_eq(rects[0].get_x(), 10.0)
      assert_eq(rects[0].get_width(), 10.0)
      assert_eq(rects[1].get_start_index(), 2)
      assert_eq(rects[1].get_end_index(), 3)
      assert_eq(rects[1].get_line(), 1)
      assert_eq(rects[1].get_x(), 0.0)
      assert_eq(rects[1].get_y(), 10.0)
      assert_eq(rects[1].get_width(), 10.0)
    }
    Err(_) => abort("expected CJK soft-wrap selection rects")
  }

  let prepared = match system.prepare_layout("cjk", text, config) {
    Ok(value) => value
    Err(_) => abort("expected prepared CJK TextSystem layout")
  }
  assert_eq(prepared.caret_for_index(2).get_line(), 1)
  assert_eq(prepared.caret_for_index(2).get_x(), 0.0)
  assert_eq(prepared.caret_at_position(6.0, 11.0).get_index(), 3)
  let prepared_rects = prepared.selection_rects(1, 3)
  assert_eq(prepared_rects.length(), 2)
  assert_eq(prepared_rects[0].get_width(), 10.0)
  assert_eq(prepared_rects[1].get_line(), 1)
}

///|
test "TextSystem maps carets through empty visual lines" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("ui", "A\n", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected trailing empty-line caret")
  }

  match system.caret_for_text("ui", "\nA", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected leading empty-line caret")
  }

  match system.caret_for_text("ui", "A\n\nB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected middle empty-line caret")
  }

  match system.selection_rects_for_text("ui", "A\n\nB", 0, 4, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 2)
      assert_eq(rects[0].get_start_index(), 0)
      assert_eq(rects[0].get_end_index(), 1)
      assert_eq(rects[0].get_line(), 0)
      assert_eq(rects[0].get_width(), 5.0)
      assert_eq(rects[1].get_start_index(), 3)
      assert_eq(rects[1].get_end_index(), 4)
      assert_eq(rects[1].get_line(), 2)
      assert_eq(rects[1].get_width(), 7.0)
    }
    Err(_) => abort("expected selection to skip empty visual line")
  }

  let prepared = match system.prepare_layout("ui", "A\n\nB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared empty-line layout")
  }
  assert_eq(prepared.get_config().line_height, 12.0)
  assert_eq(prepared.caret_for_index(2).get_line(), 1)
  assert_eq(prepared.caret_at_position(50.0, 13.0).get_index(), 2)
  let prepared_rects = prepared.selection_rects(0, 4)
  assert_eq(prepared_rects.length(), 2)
  assert_eq(prepared_rects[1].get_line(), 2)
}

///|
test "TextSystem normalizes caret indices inside CRLF line breaks" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.caret_for_text("ui", "A\r\nB", 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected CRLF leading caret")
  }

  match system.caret_for_text("ui", "A\r\nB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected normalized CRLF middle caret")
  }

  match system.caret_at_text_position("ui", "A\r\nB", -20.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected CRLF hit-test caret")
  }

  let prepared = match system.prepare_layout("ui", "A\r\nB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared CRLF layout")
  }
  let prepared_caret = prepared.caret_for_index(2)
  assert_eq(prepared_caret.get_index(), 3)
  assert_eq(prepared_caret.get_line(), 1)
  assert_eq(prepared_caret.get_x(), 0.0)

  match system.selection_rects_for_text("ui", "A\r\nB", 2, 4, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 3)
      assert_eq(rects[0].get_end_index(), 4)
      assert_eq(rects[0].get_line(), 1)
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected normalized CRLF selection")
  }
}

///|
test "TextSystem maps standalone CR line breaks to visual lines" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let text = "A\rB"
  assert_eq(text.length(), 3)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.layout_text("ui", text, config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 2)
      assert_eq(layout.get_width(), 7.0)
      let runs = layout.get_runs()
      assert_eq(runs[0].glyph_count(), 1)
      assert_eq(runs[0].get_baseline_y(), 10.0)
      assert_eq(runs[1].glyph_count(), 1)
      assert_eq(runs[1].get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected standalone CR layout")
  }

  match system.caret_for_text("ui", text, 1, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 1)
      assert_eq(caret.get_line(), 0)
      assert_eq(caret.get_x(), 5.0)
      assert_eq(caret.get_y(), 0.0)
    }
    Err(_) => abort("expected standalone CR leading caret")
  }

  match system.caret_for_text("ui", text, 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected standalone CR next-line caret")
  }

  match system.caret_at_text_position("ui", text, -20.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected standalone CR hit-test caret")
  }

  match system.selection_rects_for_text("ui", text, 1, 2, config) {
    Ok(rects) => assert_eq(rects.length(), 0)
    Err(_) => abort("expected standalone CR line-break selection")
  }
  match system.selection_rects_for_text("ui", text, 1, 3, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      assert_eq(rects[0].get_start_index(), 2)
      assert_eq(rects[0].get_end_index(), 3)
      assert_eq(rects[0].get_line(), 1)
      assert_eq(rects[0].get_x(), 0.0)
      assert_eq(rects[0].get_width(), 7.0)
    }
    Err(_) => abort("expected standalone CR trailing selection")
  }

  let prepared = match system.prepare_layout("ui", text, config) {
    Ok(value) => value
    Err(_) => abort("expected prepared standalone CR layout")
  }
  assert_eq(prepared.caret_for_index(2).get_index(), 2)
  assert_eq(prepared.caret_for_index(2).get_line(), 1)
  assert_eq(prepared.caret_at_position(-20.0, 13.0).get_index(), 2)
  assert_eq(prepared.selection_rects(1, 2).length(), 0)
  let prepared_rects = prepared.selection_rects(1, 3)
  assert_eq(prepared_rects.length(), 1)
  assert_eq(prepared_rects[0].get_start_index(), 2)
}

///|
test "TextSystem maps trailing CRLF to final empty visual line" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let text = "A\r\n"
  assert_eq(text.length(), 3)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.layout_text("ui", text, config) {
    Ok(layout) => {
      assert_eq(layout.run_count(), 2)
      assert_eq(layout.get_width(), 5.0)
      let runs = layout.get_runs()
      assert_eq(runs[0].glyph_count(), 1)
      assert_eq(runs[0].get_baseline_y(), 10.0)
      assert_eq(runs[1].glyph_count(), 0)
      assert_eq(runs[1].get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected trailing CRLF layout")
  }

  match system.caret_for_text("ui", text, 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
      assert_eq(caret.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected normalized trailing CRLF caret")
  }

  match system.caret_for_text("ui", text, 3, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
      assert_eq(caret.get_y(), 12.0)
    }
    Err(_) => abort("expected final trailing CRLF caret")
  }

  match system.caret_at_text_position("ui", text, 80.0, 13.0, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 3)
      assert_eq(caret.get_line(), 1)
      assert_eq(caret.get_x(), 0.0)
    }
    Err(_) => abort("expected trailing CRLF hit-test caret")
  }

  match system.selection_rects_for_text("ui", text, 1, 3, config) {
    Ok(rects) => assert_eq(rects.length(), 0)
    Err(_) => abort("expected trailing CRLF line-break selection")
  }

  let prepared = match system.prepare_layout("ui", text, config) {
    Ok(value) => value
    Err(_) => abort("expected prepared trailing CRLF layout")
  }
  assert_eq(prepared.caret_for_index(2).get_index(), 3)
  assert_eq(prepared.caret_for_index(2).get_line(), 1)
  assert_eq(prepared.caret_at_position(80.0, 13.0).get_index(), 3)
  assert_eq(prepared.selection_rects(1, 3).length(), 0)
}

///|
test "TextSystem prepared layout carries reusable caret and selection helpers" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "A\nB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_key(), "ui")
  assert_eq(prepared.get_text(), "A\nB")
  assert_eq(prepared.get_face().get_metrics().ascent, 10)
  assert_eq(prepared.get_layout().run_count(), 2)
  assert_eq(prepared.get_layout().get_width(), 7.0)

  let caret = prepared.caret_for_index(2)
  assert_eq(caret.get_index(), 2)
  assert_eq(caret.get_line(), 1)
  assert_eq(caret.get_x(), 0.0)
  assert_eq(caret.get_y(), 12.0)
  assert_eq(caret.get_baseline_y(), 22.0)

  let hit = prepared.caret_at_position(4.0, 13.0)
  assert_eq(hit.get_index(), 3)
  assert_eq(hit.get_line(), 1)
  assert_eq(hit.get_x(), 7.0)

  let rects = prepared.selection_rects(0, 3)
  assert_eq(rects.length(), 2)
  assert_eq(rects[0].get_start_index(), 0)
  assert_eq(rects[0].get_end_index(), 1)
  assert_eq(rects[0].get_width(), 5.0)
  assert_eq(rects[1].get_start_index(), 2)
  assert_eq(rects[1].get_end_index(), 3)
  assert_eq(rects[1].get_width(), 7.0)

  let empty = match system.prepare_layout("ui", "", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared empty layout")
  }
  let empty_caret = empty.caret_for_index(9)
  assert_eq(empty_caret.get_index(), 0)
  assert_eq(empty_caret.get_baseline_y(), 10.0)

  match system.prepare_layout("missing", "AB", config) {
    Err(FontLoadError::MissingFontData("missing")) => ()
    _ => abort("expected missing prepared-layout font")
  }
}

///|
test "TextSystem prepared layout is stable across font replacement" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)

  match system.register_font_bytes("ui", make_text_system_wide_font()) {
    Ok(_) => ()
    Err(_) => abort("expected wide replacement font")
  }
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected replacement font layout")
  }

  assert_eq(
    TextLayout::layout(prepared.get_face(), "AB", config).get_width(),
    12.0,
  )
  assert_eq(prepared.get_layout().get_width(), 12.0)
  let caret = prepared.caret_for_index(2)
  assert_eq(caret.get_index(), 2)
  assert_eq(caret.get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem prepared layout snapshot survives font-data result replacement" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(first_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), first_font.length())
    }
    Err(_) => abort("expected initial font data registration")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  let prepared_hit = prepared.caret_at_position(9.0, 0.0)
  assert_eq(prepared_hit.get_index(), 2)
  assert_eq(prepared_hit.get_x(), 12.0)

  let wide_font = make_text_system_wide_font()
  match system.register_font_data_result("ui", FontData::new(wide_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), wide_font.length())
    }
    Err(_) => abort("expected replacement font data registration")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), wide_font.length())
    }
    Err(_) => abort("expected replacement font data")
  }
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected replacement layout")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected replacement caret")
  }
  match system.caret_at_text_position("ui", "AB", 9.0, 0.0, config) {
    Ok(hit) => {
      assert_eq(hit.get_index(), 1)
      assert_eq(hit.get_x(), 9.0)
    }
    Err(_) => abort("expected replacement hit-test caret")
  }
  let fresh = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected fresh replacement layout")
  }
  assert_eq(fresh.get_layout().get_width(), 20.0)
  assert_eq(fresh.caret_for_index(2).get_x(), 20.0)
  let fresh_hit = fresh.caret_at_position(9.0, 0.0)
  assert_eq(fresh_hit.get_index(), 1)
  assert_eq(fresh_hit.get_x(), 9.0)

  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  let old_hit = prepared.caret_at_position(9.0, 0.0)
  assert_eq(old_hit.get_index(), 2)
  assert_eq(old_hit.get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem prepared layout snapshot survives register_font_file replacement" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  match system.register_font_bytes_result("ui", first_font) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), first_font.length())
    }
    Err(_) => abort("expected initial font-byte registration")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  let prepared_hit = prepared.caret_at_position(9.0, 0.0)
  assert_eq(prepared_hit.get_index(), 2)
  assert_eq(prepared_hit.get_x(), 12.0)

  let replacement_path = "/private/tmp/sun-text-system-prepared-file-replace.ttf"
  let replacement_font = make_text_system_wide_font()
  write_text_system_font_fixture(replacement_path, replacement_font)
  match system.register_font_file_result("ui", replacement_path) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(
        result.get_font_data().get_data().length(),
        replacement_font.length(),
      )
    }
    Err(_) => abort("expected file-backed replacement registration")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  assert_true(system.contains_cached_font_face("ui"))
  match load_font_data(system, "ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), replacement_font.length())
    }
    Err(_) => abort("expected file-backed data through TextSystem loader")
  }
  match load_font_face(system, "ui") {
    Ok(face) =>
      assert_eq(TextLayout::layout(face, "AB", config).get_width(), 20.0)
    Err(_) => abort("expected file-backed face through TextSystem loader")
  }
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected file-backed replacement layout")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected file-backed replacement caret")
  }
  match system.caret_at_text_position("ui", "AB", 9.0, 0.0, config) {
    Ok(hit) => {
      assert_eq(hit.get_index(), 1)
      assert_eq(hit.get_x(), 9.0)
    }
    Err(_) => abort("expected file-backed replacement hit-test caret")
  }
  let fresh = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected fresh file-backed replacement layout")
  }
  assert_eq(fresh.get_layout().get_width(), 20.0)
  assert_eq(fresh.caret_for_index(2).get_x(), 20.0)

  assert_eq(
    TextLayout::layout(prepared.get_face(), "AB", config).get_width(),
    12.0,
  )
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  let old_hit = prepared.caret_at_position(9.0, 0.0)
  assert_eq(old_hit.get_index(), 2)
  assert_eq(old_hit.get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem invalid font-file result replacement preserves prepared layout and cache" {
  let system = TextSystem::new()
  let original_font = make_text_system_ab_font()
  match system.register_font_bytes_result("ui", original_font) {
    Ok(result) => {
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(
        result.get_font_data().get_data().length(),
        original_font.length(),
      )
    }
    Err(_) => abort("expected initial font-byte registration")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  assert_true(system.contains_cached_font_face("ui"))

  let invalid_path = "/private/tmp/sun-text-system-prepared-file-invalid.ttf"
  write_text_system_font_fixture(invalid_path, b"not-font")
  match system.register_font_file_result("ui", invalid_path) {
    Err(
      FontLoadError::FontParseFailed(
        "ui",
        FontParseError::UnexpectedEndOfData(0, 12, 8)
      )
    ) => ()
    _ => abort("expected invalid file-backed replacement to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_eq(system.font_face_cache_len(), 1)
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), original_font.length())
    }
    Err(_) =>
      abort("expected original font bytes after rejected file replacement")
  }
  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(result.did_hit_cache())
      assert_true(!result.did_parse())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected cached original face after rejected file")
  }
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected original layout after rejected file replacement")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 12.0)
    }
    Err(_) => abort("expected original caret after rejected file replacement")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  let old_hit = prepared.caret_at_position(9.0, 0.0)
  assert_eq(old_hit.get_index(), 2)
  assert_eq(old_hit.get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem invalid font-byte result replacement preserves prepared layout and cache" {
  let system = TextSystem::new()
  let original_font = make_text_system_ab_font()
  match system.register_font_bytes_result("ui", original_font) {
    Ok(result) => {
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
    }
    Err(_) => abort("expected initial font-byte registration")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_true(system.contains_cached_font_face("ui"))

  match system.register_font_bytes_result("ui", b"not-font") {
    Err(FontParseError::UnexpectedEndOfData(0, 12, 8)) => ()
    _ => abort("expected invalid font-byte result replacement to be rejected")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_eq(system.font_face_cache_len(), 1)
  match system.get_font_data("ui") {
    Ok(data) => {
      assert_eq(data.get_font_index(), 0)
      assert_eq(data.get_data().length(), original_font.length())
    }
    Err(_) => abort("expected original font bytes after rejected replacement")
  }
  match system.get_font_face_result("ui") {
    Ok(result) => {
      assert_true(result.did_hit_cache())
      assert_true(!result.did_parse())
      assert_eq(result.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected cached original face after rejected replacement")
  }
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected original layout after rejected byte replacement")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem prepared empty layout keeps captured face metrics across replacement" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared empty text-system layout")
  }
  assert_eq(prepared.get_face().get_metrics().ascent, 10)
  assert_eq(prepared.caret_for_index(0).get_index(), 0)
  assert_eq(prepared.caret_for_index(0).get_baseline_y(), 10.0)
  let prepared_hit = prepared.caret_at_position(50.0, -10.0)
  assert_eq(prepared_hit.get_index(), 0)
  assert_eq(prepared_hit.get_line(), 0)
  assert_eq(prepared_hit.get_x(), 0.0)
  assert_eq(prepared_hit.get_y(), 0.0)
  assert_eq(prepared_hit.get_height(), 12.0)
  assert_eq(prepared_hit.get_baseline_y(), 10.0)

  match
    system.register_font_data_result(
      "ui",
      FontData::new(make_text_system_tall_font()),
    ) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(result.did_replace())
      assert_true(result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
    }
    Err(_) => abort("expected tall replacement registration")
  }

  let fresh = match system.prepare_layout("ui", "", config) {
    Ok(value) => value
    Err(_) => abort("expected fresh empty text-system layout")
  }
  assert_eq(fresh.get_face().get_metrics().ascent, 20)
  assert_eq(fresh.caret_for_index(0).get_index(), 0)
  assert_eq(fresh.caret_for_index(0).get_baseline_y(), 20.0)
  let fresh_hit = fresh.caret_at_position(50.0, -10.0)
  assert_eq(fresh_hit.get_index(), 0)
  assert_eq(fresh_hit.get_line(), 0)
  assert_eq(fresh_hit.get_x(), 0.0)
  assert_eq(fresh_hit.get_y(), 0.0)
  assert_eq(fresh_hit.get_height(), 12.0)
  assert_eq(fresh_hit.get_baseline_y(), 20.0)

  assert_eq(prepared.get_face().get_metrics().ascent, 10)
  assert_eq(prepared.get_layout().get_width(), 0.0)
  let old_caret = prepared.caret_for_index(20)
  assert_eq(old_caret.get_index(), 0)
  assert_eq(old_caret.get_baseline_y(), 10.0)
  let old_hit = prepared.caret_at_position(50.0, -10.0)
  assert_eq(old_hit.get_index(), 0)
  assert_eq(old_hit.get_baseline_y(), 10.0)

  assert_true(system.remove_font("ui"))
  let removed_caret = prepared.caret_for_index(0)
  assert_eq(removed_caret.get_index(), 0)
  assert_eq(removed_caret.get_baseline_y(), 10.0)
  let removed_hit = prepared.caret_at_position(50.0, -10.0)
  assert_eq(removed_hit.get_index(), 0)
  assert_eq(removed_hit.get_baseline_y(), 10.0)
}

///|
test "TextSystem prepared layout is stable across font removal and re-registration" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  match system.register_font_bytes("wide", make_text_system_wide_font()) {
    Ok(_) => ()
    Err(_) => abort("expected wide font")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)

  assert_true(system.remove_font("ui"))
  assert_true(!system.contains_font("ui"))
  assert_true(!system.contains_cached_font_face("ui"))
  assert_eq(system.font_count(), 1)
  assert_true(system.get_font_key(0) == Some("wide"))
  assert_true(system.get_font_key(1) is None)
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)

  match system.register_font_bytes_result("ui", make_text_system_wide_font()) {
    Ok(result) => {
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 2)
    }
    Err(_) => abort("expected re-registered ui font")
  }
  assert_true(system.get_font_key(0) == Some("wide"))
  assert_true(system.get_font_key(1) == Some("ui"))
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected re-registered ui layout")
  }

  assert_eq(prepared.get_layout().get_width(), 12.0)
  let caret = prepared.caret_for_index(2)
  assert_eq(caret.get_index(), 2)
  assert_eq(caret.get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem prepared layout is stable across clear_fonts and font-data re-registration" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(first_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_data().length(), first_font.length())
    }
    Err(_) => abort("expected initial font data registration")
  }
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let prepared = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared text-system layout")
  }
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)

  system.clear_fonts()
  assert_eq(system.font_count(), 0)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_font("ui"))
  assert_true(!system.contains_cached_font_face("ui"))
  assert_eq(prepared.get_layout().get_width(), 12.0)
  assert_eq(prepared.caret_for_index(2).get_x(), 12.0)

  let wide_font = make_text_system_wide_font()
  match system.register_font_data_result("ui", FontData::new(wide_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_data().length(), wide_font.length())
    }
    Err(_) => abort("expected fresh font data registration after clear_fonts")
  }
  let fresh = match system.prepare_layout("ui", "AB", config) {
    Ok(value) => value
    Err(_) => abort("expected fresh text-system layout")
  }
  assert_eq(fresh.get_layout().get_width(), 20.0)
  assert_eq(fresh.caret_for_index(2).get_x(), 20.0)

  assert_eq(prepared.get_layout().get_width(), 12.0)
  let caret = prepared.caret_for_index(2)
  assert_eq(caret.get_index(), 2)
  assert_eq(caret.get_x(), 12.0)
  let rects = prepared.selection_rects(0, 2)
  assert_eq(rects.length(), 1)
  assert_eq(rects[0].get_width(), 12.0)
}

///|
test "TextSystem computes selection rectangles for normalized ranges" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.selection_rects_for_text("ui", "AB", 1, 1, config) {
    Ok(rects) => assert_eq(rects.length(), 0)
    Err(_) => abort("expected collapsed selection rects")
  }

  match system.selection_rects_for_text("ui", "AB", 20, -4, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 1)
      let rect = rects[0]
      assert_eq(rect.get_start_index(), 0)
      assert_eq(rect.get_end_index(), 2)
      assert_eq(rect.get_line(), 0)
      assert_eq(rect.get_x(), 0.0)
      assert_eq(rect.get_y(), 0.0)
      assert_eq(rect.get_width(), 12.0)
      assert_eq(rect.get_height(), 12.0)
      assert_eq(rect.get_baseline_y(), 10.0)
    }
    Err(_) => abort("expected normalized selection rect")
  }
}

///|
test "TextSystem computes selection rectangles across visual lines" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.selection_rects_for_text("ui", "A\nB", 0, 3, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 2)
      let first = rects[0]
      assert_eq(first.get_start_index(), 0)
      assert_eq(first.get_end_index(), 1)
      assert_eq(first.get_line(), 0)
      assert_eq(first.get_x(), 0.0)
      assert_eq(first.get_y(), 0.0)
      assert_eq(first.get_width(), 5.0)
      assert_eq(first.get_height(), 12.0)
      assert_eq(first.get_baseline_y(), 10.0)

      let second = rects[1]
      assert_eq(second.get_start_index(), 2)
      assert_eq(second.get_end_index(), 3)
      assert_eq(second.get_line(), 1)
      assert_eq(second.get_x(), 0.0)
      assert_eq(second.get_y(), 12.0)
      assert_eq(second.get_width(), 7.0)
      assert_eq(second.get_height(), 12.0)
      assert_eq(second.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected multi-line selection rects")
  }
}

///|
test "TextSystem normalizes reversed selection ranges across visual lines" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.selection_rects_for_text("ui", "A\nB", 3, 0, config) {
    Ok(rects) => {
      assert_eq(rects.length(), 2)
      let first = rects[0]
      assert_eq(first.get_start_index(), 0)
      assert_eq(first.get_end_index(), 1)
      assert_eq(first.get_line(), 0)
      assert_eq(first.get_x(), 0.0)
      assert_eq(first.get_y(), 0.0)
      assert_eq(first.get_width(), 5.0)
      assert_eq(first.get_height(), 12.0)
      assert_eq(first.get_baseline_y(), 10.0)

      let second = rects[1]
      assert_eq(second.get_start_index(), 2)
      assert_eq(second.get_end_index(), 3)
      assert_eq(second.get_line(), 1)
      assert_eq(second.get_x(), 0.0)
      assert_eq(second.get_y(), 12.0)
      assert_eq(second.get_width(), 7.0)
      assert_eq(second.get_height(), 12.0)
      assert_eq(second.get_baseline_y(), 22.0)
    }
    Err(_) => abort("expected reversed multi-line selection rects")
  }

  let prepared = match system.prepare_layout("ui", "A\nB", config) {
    Ok(value) => value
    Err(_) => abort("expected prepared reversed multi-line layout")
  }
  let prepared_rects = prepared.selection_rects(3, 0)
  assert_eq(prepared_rects.length(), 2)
  assert_eq(prepared_rects[0].get_start_index(), 0)
  assert_eq(prepared_rects[0].get_end_index(), 1)
  assert_eq(prepared_rects[0].get_line(), 0)
  assert_eq(prepared_rects[0].get_x(), 0.0)
  assert_eq(prepared_rects[0].get_y(), 0.0)
  assert_eq(prepared_rects[0].get_width(), 5.0)
  assert_eq(prepared_rects[0].get_height(), 12.0)
  assert_eq(prepared_rects[0].get_baseline_y(), 10.0)
  assert_eq(prepared_rects[1].get_start_index(), 2)
  assert_eq(prepared_rects[1].get_end_index(), 3)
  assert_eq(prepared_rects[1].get_line(), 1)
  assert_eq(prepared_rects[1].get_x(), 0.0)
  assert_eq(prepared_rects[1].get_y(), 12.0)
  assert_eq(prepared_rects[1].get_width(), 7.0)
  assert_eq(prepared_rects[1].get_height(), 12.0)
  assert_eq(prepared_rects[1].get_baseline_y(), 22.0)
}

///|
test "TextSystem clears registered font state" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  assert_eq(system.font_count(), 1)
  system.clear_fonts()
  assert_eq(system.font_count(), 0)
  assert_true(!system.contains_font("ui"))
  match system.get_font_data("ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected cleared text-system font data")
  }
  match system.get_font_face("ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected cleared text-system font")
  }
}

///|
test "TextSystem clear_fonts makes same-key font-data registration fresh" {
  let system = TextSystem::new()
  let first_font = make_text_system_ab_font()
  match system.register_font_data_result("ui", FontData::new(first_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_font_data().get_data().length(), first_font.length())
    }
    Err(_) => abort("expected initial font data registration")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)

  system.clear_fonts()
  assert_eq(system.font_count(), 0)
  assert_eq(system.font_face_cache_len(), 0)
  assert_true(!system.contains_font("ui"))
  assert_true(!system.contains_cached_font_face("ui"))
  assert_eq(system.get_font_keys().length(), 0)
  assert_true(system.get_font_key(0) is None)

  let wide_font = make_text_system_wide_font()
  match system.register_font_data_result("ui", FontData::new(wide_font)) {
    Ok(result) => {
      assert_eq(result.get_key(), "ui")
      assert_true(!result.did_replace())
      assert_true(!result.did_replace_cached_face())
      assert_eq(result.get_font_count(), 1)
      assert_eq(result.get_face().get_units_per_em(), 10)
      assert_eq(result.get_font_data().get_font_index(), 0)
      assert_eq(result.get_font_data().get_data().length(), wide_font.length())
    }
    Err(_) => abort("expected fresh font data registration after clear_fonts")
  }
  assert_eq(system.font_count(), 1)
  assert_true(system.contains_font("ui"))
  assert_true(system.contains_cached_font_face("ui"))
  assert_true(system.get_font_key(0) == Some("ui"))
  assert_true(system.get_font_key(1) is None)

  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 20.0)
    Err(_) => abort("expected fresh registration layout")
  }
  match system.caret_for_text("ui", "AB", 2, config) {
    Ok(caret) => {
      assert_eq(caret.get_index(), 2)
      assert_eq(caret.get_x(), 20.0)
    }
    Err(_) => abort("expected fresh registration caret")
  }
}

///|
test "TextSystem removes one registered font and cached face" {
  let system = TextSystem::new()
  register_text_system_ab_font(system)
  let config = LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )

  match system.get_font_face("ui") {
    Ok(face) => assert_eq(face.get_units_per_em(), 10)
    Err(_) => abort("expected cached text-system font")
  }
  assert_true(system.remove_font("ui"))
  assert_eq(system.font_count(), 0)
  assert_true(!system.contains_font("ui"))
  match system.get_font_data("ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected removed text-system font data")
  }
  match system.get_font_face("ui") {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected removed text-system font")
  }
  match system.layout_text("ui", "AB", config) {
    Err(FontLoadError::MissingFontData("ui")) => ()
    _ => abort("expected removed font layout error")
  }
  assert_true(!system.remove_font("ui"))

  register_text_system_ab_font(system)
  assert_true(system.contains_font("ui"))
  match system.layout_text("ui", "AB", config) {
    Ok(layout) => assert_eq(layout.get_width(), 12.0)
    Err(_) => abort("expected re-registered text-system layout")
  }
}
