///|
test "RendererResources configures bounded font text and image caches" {
  let resources = RendererResources::with_font_capacity(16, 16, 1, 2, 3, 1)
  let font_cache = resources.get_font_face_cache()
  let text_resources = resources.get_text_resources()
  let text_cache = resources.get_text_mask_cache()
  let glyph_cache = resources.get_glyph_mask_cache()
  let atlas = resources.get_glyph_mask_atlas()
  let image_cache = resources.get_image_cache()
  assert_true(font_cache.is_capacity_bounded())
  assert_eq(font_cache.capacity(), 1)
  assert_true(text_cache.is_capacity_bounded())
  assert_eq(text_cache.capacity(), 2)
  assert_eq(text_resources.get_text_mask_cache().capacity(), 2)
  assert_true(glyph_cache.is_capacity_bounded())
  assert_eq(glyph_cache.capacity(), 3)
  assert_eq(atlas.get_width(), 16)
  assert_eq(atlas.get_height(), 16)
  assert_true(image_cache.is_capacity_bounded())
  assert_eq(image_cache.capacity(), 1)

  ignore(
    font_cache.insert(
      "first",
      unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf())),
    ),
  )
  ignore(
    font_cache.insert(
      "second",
      unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf())),
    ),
  )
  assert_eq(font_cache.len(), 1)
  assert_true(font_cache.get("first") is None)
  assert_true(font_cache.get("second") is Some(_))

  let red = @graphics.Pixmap::new(1, 1)
  red.set_pixel(0, 0, @graphics.Color::red())
  let blue = @graphics.Pixmap::new(1, 1)
  blue.set_pixel(0, 0, @graphics.Color::blue())
  ignore(image_cache.insert("red", red))
  ignore(image_cache.insert("blue", blue))
  assert_eq(image_cache.len(), 1)
  assert_true(image_cache.get("red") is None)
  match image_cache.get("blue") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), @graphics.Color::blue())
    None => abort("expected cached blue pixmap")
  }
}

///|
test "RendererResources reports unified cache residency" {
  let resources = RendererResources::new(16, 16)
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  ignore(resources.get_font_face_cache().insert("ui-font", face))
  let text_pixels : FixedArray[Byte] = FixedArray::make(1, 32)
  let glyph_pixels : FixedArray[Byte] = FixedArray::make(1, 64)
  ignore(
    resources
    .get_text_mask_cache()
    .insert("label", @text.CoverageMask::new(1, 1, text_pixels)),
  )
  ignore(
    resources
    .get_glyph_mask_cache()
    .insert("glyph:A", @text.CoverageMask::new(1, 1, glyph_pixels)),
  )
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())
  ignore(resources.get_image_cache().insert("icon", icon))

  assert_true(resources.contains_font_face("ui-font"))
  assert_true(!resources.contains_font_face("missing-font"))
  assert_true(resources.contains_text_mask("label"))
  assert_true(!resources.contains_text_mask("missing-label"))
  assert_true(resources.contains_glyph_mask("glyph:A"))
  assert_true(!resources.contains_glyph_mask("glyph:B"))
  assert_true(resources.contains_image("icon"))
  assert_true(!resources.contains_image("missing-icon"))

  resources.clear()
  assert_true(!resources.contains_font_face("ui-font"))
  assert_true(!resources.contains_text_mask("label"))
  assert_true(!resources.contains_glyph_mask("glyph:A"))
  assert_true(!resources.contains_image("icon"))
}

///|
test "RendererResources snapshots unified resource telemetry" {
  let resources = RendererResources::with_font_capacity(16, 8, 1, 2, 3, 4)
  let empty = resources.snapshot()
  assert_eq(empty.get_font_face_count(), 0)
  assert_eq(empty.get_font_face_capacity(), 1)
  assert_true(empty.is_font_face_capacity_bounded())
  assert_eq(empty.get_image_count(), 0)
  assert_eq(empty.get_image_capacity(), 4)
  assert_true(empty.is_image_capacity_bounded())
  let empty_text = empty.get_text_snapshot()
  assert_eq(empty_text.get_text_mask_capacity(), 2)
  assert_eq(empty_text.get_glyph_mask_capacity(), 3)
  assert_eq(empty_text.get_atlas_capacity(), 128)

  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  ignore(resources.get_font_face_cache().insert("ui-font", face))
  ignore(
    resources
    .get_text_mask_cache()
    .insert("label", @text.CoverageMask::new(1, 1, FixedArray::make(1, 8))),
  )
  let glyph_mask = @text.CoverageMask::new(2, 2, FixedArray::make(4, 16))
  ignore(resources.get_glyph_mask_cache().insert("glyph:A", glyph_mask))
  ignore(resources.get_glyph_mask_atlas().insert("glyph:A", glyph_mask))
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())
  ignore(resources.get_image_cache().insert("icon", icon))

  let filled = resources.snapshot()
  assert_eq(filled.get_font_face_count(), 1)
  assert_eq(filled.get_image_count(), 1)
  let filled_text = filled.get_text_snapshot()
  assert_eq(filled_text.get_text_mask_count(), 1)
  assert_eq(filled_text.get_glyph_mask_count(), 1)
  assert_eq(filled_text.get_atlas_entry_count(), 1)
  assert_eq(filled_text.get_atlas_used_pixel_count(), 4)

  resources.clear()
  let cleared = resources.snapshot()
  assert_eq(cleared.get_font_face_count(), 0)
  assert_eq(cleared.get_image_count(), 0)
  assert_eq(cleared.get_text_snapshot().get_text_mask_count(), 0)
  assert_eq(cleared.get_text_snapshot().get_glyph_mask_count(), 0)
  assert_eq(cleared.get_text_snapshot().get_atlas_entry_count(), 0)
}
