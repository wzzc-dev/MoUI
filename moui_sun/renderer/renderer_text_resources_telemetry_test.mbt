///|
test "RendererTextResources configures bounded text caches" {
  let resources = RendererTextResources::with_capacities(16, 16, 1, 2)
  let text_cache = resources.get_text_mask_cache()
  let glyph_cache = resources.get_glyph_mask_cache()
  let atlas = resources.get_glyph_mask_atlas()
  assert_true(text_cache.is_capacity_bounded())
  assert_eq(text_cache.capacity(), 1)
  assert_true(glyph_cache.is_capacity_bounded())
  assert_eq(glyph_cache.capacity(), 2)
  assert_eq(atlas.get_width(), 16)
  assert_eq(atlas.get_height(), 16)
}

///|
test "RendererTextResources reports cached text and glyph residency" {
  let resources = RendererTextResources::new(16, 16)
  let text_pixels : FixedArray[Byte] = FixedArray::make(1, 24)
  let glyph_pixels : FixedArray[Byte] = FixedArray::make(1, 48)
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
  assert_true(resources.contains_text_mask("label"))
  assert_true(!resources.contains_text_mask("missing"))
  assert_true(resources.contains_glyph_mask("glyph:A"))
  assert_true(!resources.contains_glyph_mask("glyph:B"))

  resources.clear()
  assert_true(!resources.contains_text_mask("label"))
  assert_true(!resources.contains_glyph_mask("glyph:A"))
}

///|
test "RendererTextResources snapshots cache and atlas telemetry" {
  let resources = RendererTextResources::with_capacities(16, 8, 2, 3)
  let empty = resources.snapshot()
  assert_eq(empty.get_text_mask_count(), 0)
  assert_eq(empty.get_text_mask_capacity(), 2)
  assert_true(empty.is_text_mask_capacity_bounded())
  assert_eq(empty.get_glyph_mask_count(), 0)
  assert_eq(empty.get_glyph_mask_capacity(), 3)
  assert_true(empty.is_glyph_mask_capacity_bounded())
  assert_eq(empty.get_atlas_entry_count(), 0)
  assert_eq(empty.get_atlas_width(), 16)
  assert_eq(empty.get_atlas_height(), 8)
  assert_eq(empty.get_atlas_capacity(), 128)
  assert_eq(empty.get_atlas_used_pixel_count(), 0)
  assert_eq(empty.get_atlas_free_pixel_count(), 128)
  assert_eq(empty.get_atlas_occupancy_ratio(), 0.0)

  ignore(
    resources
    .get_text_mask_cache()
    .insert("label", @text.CoverageMask::new(1, 1, FixedArray::make(1, 8))),
  )
  let glyph_mask = @text.CoverageMask::new(2, 2, FixedArray::make(4, 16))
  ignore(resources.get_glyph_mask_cache().insert("glyph:A", glyph_mask))
  ignore(resources.get_glyph_mask_atlas().insert("glyph:A", glyph_mask))

  let filled = resources.snapshot()
  assert_eq(filled.get_text_mask_count(), 1)
  assert_eq(filled.get_glyph_mask_count(), 1)
  assert_eq(filled.get_atlas_entry_count(), 1)
  assert_eq(filled.get_atlas_used_pixel_count(), 4)
  assert_eq(filled.get_atlas_free_pixel_count(), 124)
  assert_eq(filled.get_atlas_occupancy_ratio(), 0.03125)

  resources.clear()
  let cleared = resources.snapshot()
  assert_eq(cleared.get_text_mask_count(), 0)
  assert_eq(cleared.get_glyph_mask_count(), 0)
  assert_eq(cleared.get_atlas_entry_count(), 0)
  assert_eq(cleared.get_atlas_used_pixel_count(), 0)
  assert_eq(cleared.get_atlas_free_pixel_count(), 128)
}
