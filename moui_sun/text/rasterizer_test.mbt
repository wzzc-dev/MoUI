///|
test "CoverageMask stores dimensions and pixels" {
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  pixels[1] = 128
  let mask = CoverageMask::new(2, 2, pixels)
  assert_eq(mask.get_width(), 2)
  assert_eq(mask.get_height(), 2)
  assert_eq(mask.get_pixels()[1], 128)
}

///|
test "CoverageMask::copy duplicates pixel storage" {
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  pixels[0] = 64
  let mask = CoverageMask::new(2, 2, pixels)
  let copy = mask.copy()
  let copy_pixels = copy.get_pixels()
  copy_pixels[0] = 192
  assert_eq(mask.get_pixels()[0], 64)
  assert_eq(copy.get_pixels()[0], 192)
}

///|
test "TextMaskCache stores copies and clears entries" {
  let cache = TextMaskCache::new()
  assert_true(cache.is_empty())
  assert_true(!cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 0)
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  pixels[0] = 96
  let mask = CoverageMask::new(2, 2, pixels)
  let inserted = cache.insert("label", mask)
  assert_eq(cache.len(), 1)
  assert_eq(inserted.get_pixels()[0], 96)

  pixels[0] = 12
  match cache.get("label") {
    Some(cached) => {
      assert_eq(cached.get_width(), 2)
      assert_eq(cached.get_height(), 2)
      assert_eq(cached.get_pixels()[0], 96)
      let cached_pixels = cached.get_pixels()
      cached_pixels[0] = 200
    }
    None => abort("expected cached text mask")
  }

  match cache.get("label") {
    Some(cached) => assert_eq(cached.get_pixels()[0], 96)
    None => abort("expected cached text mask")
  }

  cache.remove("label")
  assert_true(cache.is_empty())
  assert_true(cache.get("label") is None)

  ignore(cache.insert("label", mask))
  assert_eq(cache.len(), 1)
  cache.clear()
  assert_true(cache.is_empty())
}

///|
test "GlyphMaskCache stores copies and clears entries" {
  let cache = GlyphMaskCache::new()
  assert_true(cache.is_empty())
  assert_true(!cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 0)
  let pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  pixels[2] = 144
  let mask = CoverageMask::new(2, 2, pixels)
  let inserted = cache.insert("glyph:A:10", mask)
  assert_eq(cache.len(), 1)
  assert_eq(inserted.get_pixels()[2], 144)

  pixels[2] = 9
  match cache.get("glyph:A:10") {
    Some(cached) => {
      assert_eq(cached.get_width(), 2)
      assert_eq(cached.get_height(), 2)
      assert_eq(cached.get_pixels()[2], 144)
      let cached_pixels = cached.get_pixels()
      cached_pixels[2] = 1
    }
    None => abort("expected cached glyph mask")
  }

  match cache.get("glyph:A:10") {
    Some(cached) => assert_eq(cached.get_pixels()[2], 144)
    None => abort("expected cached glyph mask")
  }

  cache.remove("glyph:A:10")
  assert_true(cache.is_empty())
  assert_true(cache.get("glyph:A:10") is None)

  ignore(cache.insert("glyph:A:10", mask))
  assert_eq(cache.len(), 1)
  cache.clear()
  assert_true(cache.is_empty())
}

///|
test "TextMaskCache::with_capacity evicts least recently used masks" {
  let cache = TextMaskCache::with_capacity(2)
  assert_true(cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 2)
  let first_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  first_pixels[0] = 10
  let second_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  second_pixels[0] = 20
  let third_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  third_pixels[0] = 30
  ignore(cache.insert("first", CoverageMask::new(2, 2, first_pixels)))
  ignore(cache.insert("second", CoverageMask::new(2, 2, second_pixels)))
  match cache.get("first") {
    Some(mask) => assert_eq(mask.get_pixels()[0], 10)
    None => abort("expected first text mask")
  }
  ignore(cache.insert("third", CoverageMask::new(2, 2, third_pixels)))
  assert_eq(cache.len(), 2)
  assert_true(cache.get("second") is None)
  assert_true(cache.get("first") is Some(_))
  assert_true(cache.get("third") is Some(_))
}

///|
test "TextMaskCache::contains reports membership without refreshing LRU" {
  let cache = TextMaskCache::with_capacity(2)
  let first_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  first_pixels[0] = 10
  let second_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  second_pixels[0] = 20
  let third_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  third_pixels[0] = 30
  ignore(cache.insert("first", CoverageMask::new(2, 2, first_pixels)))
  ignore(cache.insert("second", CoverageMask::new(2, 2, second_pixels)))
  assert_true(cache.contains("first"))
  assert_true(!cache.contains("third"))
  ignore(cache.insert("third", CoverageMask::new(2, 2, third_pixels)))
  assert_eq(cache.len(), 2)
  assert_true(!cache.contains("first"))
  assert_true(cache.contains("second"))
  assert_true(cache.contains("third"))
}

///|
test "GlyphMaskCache::with_capacity evicts least recently used masks" {
  let cache = GlyphMaskCache::with_capacity(2)
  assert_true(cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 2)
  let first_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  first_pixels[1] = 10
  let second_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  second_pixels[1] = 20
  let third_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  third_pixels[1] = 30
  ignore(cache.insert("first", CoverageMask::new(2, 2, first_pixels)))
  ignore(cache.insert("second", CoverageMask::new(2, 2, second_pixels)))
  match cache.get("first") {
    Some(mask) => assert_eq(mask.get_pixels()[1], 10)
    None => abort("expected first glyph mask")
  }
  ignore(cache.insert("third", CoverageMask::new(2, 2, third_pixels)))
  assert_eq(cache.len(), 2)
  assert_true(cache.get("second") is None)
  assert_true(cache.get("first") is Some(_))
  assert_true(cache.get("third") is Some(_))
}

///|
test "GlyphMaskCache::contains reports membership without refreshing LRU" {
  let cache = GlyphMaskCache::with_capacity(2)
  let first_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  first_pixels[1] = 10
  let second_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  second_pixels[1] = 20
  let third_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  third_pixels[1] = 30
  ignore(cache.insert("first", CoverageMask::new(2, 2, first_pixels)))
  ignore(cache.insert("second", CoverageMask::new(2, 2, second_pixels)))
  assert_true(cache.contains("first"))
  assert_true(!cache.contains("third"))
  ignore(cache.insert("third", CoverageMask::new(2, 2, third_pixels)))
  assert_eq(cache.len(), 2)
  assert_true(!cache.contains("first"))
  assert_true(cache.contains("second"))
  assert_true(cache.contains("third"))
}

///|
test "Mask caches clamp invalid capacity" {
  let text_cache = TextMaskCache::with_capacity(0)
  let glyph_cache = GlyphMaskCache::with_capacity(0)
  assert_eq(text_cache.capacity(), 1)
  assert_eq(glyph_cache.capacity(), 1)
  let first_pixels : FixedArray[Byte] = FixedArray::make(1, 1)
  let second_pixels : FixedArray[Byte] = FixedArray::make(1, 2)
  ignore(text_cache.insert("first", CoverageMask::new(1, 1, first_pixels)))
  ignore(glyph_cache.insert("first", CoverageMask::new(1, 1, first_pixels)))
  ignore(text_cache.insert("second", CoverageMask::new(1, 1, second_pixels)))
  ignore(glyph_cache.insert("second", CoverageMask::new(1, 1, second_pixels)))
  assert_eq(text_cache.len(), 1)
  assert_eq(glyph_cache.len(), 1)
  assert_true(text_cache.get("first") is None)
  assert_true(glyph_cache.get("first") is None)
  assert_true(text_cache.get("second") is Some(_))
  assert_true(glyph_cache.get("second") is Some(_))
}

///|
test "GlyphMaskAtlas packs masks into rows" {
  let atlas = GlyphMaskAtlas::new(4, 3)
  assert_eq(atlas.get_width(), 4)
  assert_eq(atlas.get_height(), 3)
  assert_eq(atlas.get_capacity(), 12)
  assert_eq(atlas.get_used_pixel_count(), 0)
  assert_eq(atlas.get_free_pixel_count(), 12)
  assert_eq(atlas.get_occupancy_ratio(), 0.0)
  assert_true(atlas.is_empty())

  let a_pixels : FixedArray[Byte] = FixedArray::make(4, 0)
  a_pixels[0] = 10
  a_pixels[3] = 40
  let a = CoverageMask::new(2, 2, a_pixels)
  match atlas.insert("a", a) {
    Some(entry) => {
      assert_eq(entry.get_key(), "a")
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
      assert_eq(entry.get_width(), 2)
      assert_eq(entry.get_height(), 2)
    }
    None => abort("expected first atlas entry")
  }
  assert_eq(atlas.len(), 1)
  assert_eq(atlas.get_used_pixel_count(), 4)
  assert_eq(atlas.get_free_pixel_count(), 8)

  let b_pixels : FixedArray[Byte] = FixedArray::make(2, 0)
  b_pixels[0] = 50
  b_pixels[1] = 60
  let b = CoverageMask::new(2, 1, b_pixels)
  match atlas.insert("b", b) {
    Some(entry) => {
      assert_eq(entry.get_x(), 2)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected second atlas entry")
  }

  let c_pixels : FixedArray[Byte] = FixedArray::make(2, 0)
  c_pixels[0] = 70
  c_pixels[1] = 80
  let c = CoverageMask::new(2, 1, c_pixels)
  match atlas.insert("c", c) {
    Some(entry) => {
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 2)
    }
    None => abort("expected wrapped atlas entry")
  }
  assert_eq(atlas.get_used_pixel_count(), 8)
  assert_eq(atlas.get_free_pixel_count(), 4)

  a_pixels[0] = 99
  let packed = atlas.to_mask()
  assert_eq(packed.get_width(), 4)
  assert_eq(packed.get_height(), 3)
  assert_eq(packed.get_pixels()[0], 10)
  assert_eq(packed.get_pixels()[1 * 4 + 1], 40)
  assert_eq(packed.get_pixels()[2], 50)
  assert_eq(packed.get_pixels()[3], 60)
  assert_eq(packed.get_pixels()[2 * 4], 70)
  assert_eq(packed.get_pixels()[2 * 4 + 1], 80)
}

///|
test "GlyphMaskAtlas reports lifecycle metrics and fit" {
  let atlas = GlyphMaskAtlas::new(4, 2)
  assert_eq(atlas.get_capacity(), 8)
  assert_eq(atlas.get_used_pixel_count(), 0)
  assert_eq(atlas.get_free_pixel_count(), 8)
  assert_eq(atlas.get_occupancy_ratio(), 0.0)

  let small = CoverageMask::new(2, 1, FixedArray::make(2, 1))
  assert_true(atlas.can_fit(small))
  match atlas.insert("small", small) {
    Some(entry) => {
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected small atlas entry")
  }
  assert_eq(atlas.get_used_pixel_count(), 2)
  assert_eq(atlas.get_free_pixel_count(), 6)
  assert_eq(atlas.get_occupancy_ratio(), 0.25)

  let tall_pixels : FixedArray[Byte] = FixedArray::make(4, 1)
  let tall = CoverageMask::new(2, 2, tall_pixels)
  assert_true(atlas.can_fit(tall))
  ignore(atlas.insert("tall", tall))
  assert_eq(atlas.get_used_pixel_count(), 6)
  assert_eq(atlas.get_free_pixel_count(), 2)
  assert_eq(atlas.get_occupancy_ratio(), 0.75)

  let duplicate_pixels : FixedArray[Byte] = FixedArray::make(2, 1)
  let duplicate = CoverageMask::new(2, 1, duplicate_pixels)
  ignore(atlas.insert("small", duplicate))
  assert_eq(atlas.get_used_pixel_count(), 6)
  assert_eq(atlas.get_free_pixel_count(), 2)

  let wrapped_tall_pixels : FixedArray[Byte] = FixedArray::make(2, 1)
  let wrapped_tall = CoverageMask::new(1, 2, wrapped_tall_pixels)
  assert_true(!atlas.can_fit(wrapped_tall))
  assert_true(atlas.insert("wrapped-tall", wrapped_tall) is None)
  assert_eq(atlas.get_used_pixel_count(), 6)
  assert_eq(atlas.get_free_pixel_count(), 2)

  atlas.clear()
  assert_eq(atlas.get_used_pixel_count(), 0)
  assert_eq(atlas.get_free_pixel_count(), 8)
  assert_eq(atlas.get_occupancy_ratio(), 0.0)
  assert_true(atlas.can_fit(wrapped_tall))
}

///|
test "GlyphMaskAtlas insert_or_clear reports atlas rotation" {
  let atlas = GlyphMaskAtlas::new(2, 2)
  let first_pixels : FixedArray[Byte] = FixedArray::make(2, 0)
  first_pixels[0] = 90
  let first = CoverageMask::new(2, 1, first_pixels)
  match atlas.insert_or_clear("first", first) {
    Some(result) => {
      assert_true(!result.did_clear())
      assert_true(!result.did_reuse())
      let entry = result.get_entry()
      assert_eq(entry.get_key(), "first")
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected first insert_or_clear result")
  }

  let existing_pixels : FixedArray[Byte] = FixedArray::make(2, 0)
  existing_pixels[0] = 220
  let existing = CoverageMask::new(2, 1, existing_pixels)
  match atlas.insert_or_clear("first", existing) {
    Some(result) => {
      assert_true(!result.did_clear())
      assert_true(result.did_reuse())
      let entry = result.get_entry()
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected existing atlas result")
  }
  assert_eq(atlas.to_mask().get_pixels()[0], 90)

  let second = CoverageMask::new(2, 1, FixedArray::make(2, 7))
  ignore(atlas.insert_or_clear("second", second))
  assert_eq(atlas.len(), 2)
  assert_eq(atlas.get_used_pixel_count(), 4)
  assert_true(!atlas.can_fit(first))

  let rotated_pixels : FixedArray[Byte] = FixedArray::make(2, 0)
  rotated_pixels[0] = 33
  rotated_pixels[1] = 44
  let rotated = CoverageMask::new(2, 1, rotated_pixels)
  match atlas.insert_or_clear("rotated", rotated) {
    Some(result) => {
      assert_true(result.did_clear())
      assert_true(!result.did_reuse())
      let entry = result.get_entry()
      assert_eq(entry.get_key(), "rotated")
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected rotated atlas result")
  }
  assert_eq(atlas.len(), 1)
  assert_true(atlas.get("first") is None)
  assert_true(atlas.get("second") is None)
  assert_eq(atlas.get_used_pixel_count(), 2)
  assert_eq(atlas.get_free_pixel_count(), 2)
  let packed = atlas.to_mask().get_pixels()
  assert_eq(packed[0], 33)
  assert_eq(packed[1], 44)
  assert_eq(packed[2], 0)

  let too_wide = CoverageMask::new(3, 1, FixedArray::make(3, 1))
  assert_true(atlas.insert_or_clear("too-wide", too_wide) is None)
  assert_eq(atlas.len(), 1)
  assert_true(atlas.get("rotated") is Some(_))
}

///|
test "GlyphMaskAtlas reuses keys rejects overflow and clears" {
  let atlas = GlyphMaskAtlas::new(2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(1, 0)
  pixels[0] = 120
  let mask = CoverageMask::new(1, 1, pixels)
  match atlas.insert("same", mask) {
    Some(entry) => {
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected atlas entry")
  }

  let replacement_pixels : FixedArray[Byte] = FixedArray::make(1, 0)
  replacement_pixels[0] = 240
  let replacement = CoverageMask::new(1, 1, replacement_pixels)
  match atlas.insert("same", replacement) {
    Some(entry) => {
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected existing atlas entry")
  }
  assert_eq(atlas.len(), 1)
  assert_eq(atlas.to_mask().get_pixels()[0], 120)

  let too_wide = CoverageMask::new(3, 1, FixedArray::make(3, 1))
  assert_true(atlas.insert("wide", too_wide) is None)
  let short_pixels = CoverageMask::new(2, 2, FixedArray::make(3, 1))
  assert_true(atlas.insert("short", short_pixels) is None)
  let too_tall_after_wrap = CoverageMask::new(2, 2, FixedArray::make(4, 1))
  assert_true(atlas.insert("too-tall-after-wrap", too_tall_after_wrap) is None)
  ignore(atlas.insert("one", mask))
  match atlas.insert("two", mask) {
    Some(entry) => {
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 1)
    }
    None => abort("expected wrap after failed overflow entry")
  }
  ignore(atlas.insert("three", mask))
  assert_true(atlas.insert("overflow", mask) is None)

  atlas.clear()
  assert_true(atlas.is_empty())
  assert_true(atlas.get("same") is None)
  assert_eq(atlas.to_mask().get_pixels()[0], 0)
  match atlas.insert("after-clear", mask) {
    Some(entry) => {
      assert_eq(entry.get_x(), 0)
      assert_eq(entry.get_y(), 0)
    }
    None => abort("expected atlas entry after clear")
  }
}

///|
test "Rasterizer::to_mask snapshots grayscale pixels" {
  let rasterizer = Rasterizer::new(4, 4)
  rasterizer.draw_line(1.0, 1.0, 1.0, 1.0)
  let mask = rasterizer.to_mask()
  assert_eq(rasterizer.get_width(), 4)
  assert_eq(rasterizer.get_height(), 4)
  assert_eq(mask.get_width(), 4)
  assert_eq(mask.get_height(), 4)
  assert_eq(mask.get_pixels()[1 * 4 + 1], 255)
  rasterizer.clear()
  assert_eq(mask.get_pixels()[1 * 4 + 1], 255)
}
