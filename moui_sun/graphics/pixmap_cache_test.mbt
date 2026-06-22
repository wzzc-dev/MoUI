///|
test "PixmapCache stores copies and manages entries" {
  let cache = PixmapCache::new()
  assert_true(cache.is_empty())
  assert_true(!cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 0)
  let pixmap = Pixmap::new(2, 1)
  pixmap.set_pixel(0, 0, Color::red())
  let inserted = cache.insert("icon", pixmap)
  assert_eq(cache.len(), 1)
  assert_eq(inserted.get_pixel(0, 0), Color::red())

  pixmap.set_pixel(0, 0, Color::blue())
  match cache.get("icon") {
    Some(cached) => {
      assert_eq(cached.get_width(), 2)
      assert_eq(cached.get_height(), 1)
      assert_eq(cached.get_pixel(0, 0), Color::red())
      cached.set_pixel(0, 0, Color::green())
    }
    None => abort("expected cached pixmap")
  }

  match cache.get("icon") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::red())
    None => abort("expected cached pixmap")
  }

  let replacement = Pixmap::new(1, 1)
  replacement.set_pixel(0, 0, Color::black())
  ignore(cache.insert("icon", replacement))
  assert_eq(cache.len(), 1)
  match cache.get("icon") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::black())
    None => abort("expected replacement pixmap")
  }

  cache.remove("icon")
  assert_true(cache.is_empty())
  assert_true(cache.get("icon") is None)

  ignore(cache.insert("icon", pixmap))
  assert_eq(cache.len(), 1)
  cache.clear()
  assert_true(cache.is_empty())
}

///|
test "PixmapCache::get_or_insert reuses cached pixmaps" {
  let cache = PixmapCache::new()
  let red = Pixmap::new(1, 1)
  red.set_pixel(0, 0, Color::red())
  let first = cache.get_or_insert("status", red)
  assert_eq(first.get_pixel(0, 0), Color::red())
  assert_eq(cache.len(), 1)

  first.set_pixel(0, 0, Color::green())
  match cache.get("status") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::red())
    None => abort("expected cached pixmap")
  }

  let blue = Pixmap::new(1, 1)
  blue.set_pixel(0, 0, Color::blue())
  let second = cache.get_or_insert("status", blue)
  assert_eq(second.get_pixel(0, 0), Color::red())
  assert_eq(cache.len(), 1)
}

///|
test "PixmapCache::get_or_insert_result reports cache hits" {
  let cache = PixmapCache::new()
  let red = Pixmap::new(1, 1)
  red.set_pixel(0, 0, Color::red())
  let first = cache.get_or_insert_result("icon", red)
  assert_true(first.did_insert())
  assert_true(!first.did_hit_cache())
  assert_eq(first.get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(cache.len(), 1)

  let first_pixmap = first.get_pixmap()
  first_pixmap.set_pixel(0, 0, Color::green())
  match cache.get("icon") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::red())
    None => abort("expected cached pixmap")
  }

  let blue = Pixmap::new(1, 1)
  blue.set_pixel(0, 0, Color::blue())
  let second = cache.get_or_insert_result("icon", blue)
  assert_true(!second.did_insert())
  assert_true(second.did_hit_cache())
  assert_eq(second.get_pixmap().get_pixel(0, 0), Color::red())
  assert_eq(cache.len(), 1)
}

///|
test "PixmapCache::get_or_decode_bmp_result decodes misses and reports hits" {
  let cache = PixmapCache::new()
  let source = Pixmap::new(1, 1)
  source.set_pixel(0, 0, Color::red())
  match cache.get_or_decode_bmp_result("icon", source.to_bmp_bytes()) {
    Ok(first) => {
      assert_true(first.did_decode())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_pixmap().get_pixel(0, 0), Color::red())
      let first_pixmap = first.get_pixmap()
      first_pixmap.set_pixel(0, 0, Color::green())
    }
    Err(_) => abort("expected BMP cache decode")
  }
  assert_eq(cache.len(), 1)
  match cache.get("icon") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::red())
    None => abort("expected cached decoded pixmap")
  }

  match cache.get_or_decode_bmp_result("icon", Bytes::from_array([0, 0])) {
    Ok(second) => {
      assert_true(!second.did_decode())
      assert_true(second.did_hit_cache())
      assert_eq(second.get_pixmap().get_pixel(0, 0), Color::red())
    }
    Err(_) => abort("expected cached BMP pixmap hit")
  }
  assert_eq(cache.len(), 1)
}

///|
test "PixmapCache::get_or_decode_rgba_result decodes misses and reports hits" {
  let cache = PixmapCache::new()
  let pixels = Bytes::from_array([0, 255, 0, 255])

  match cache.get_or_decode_rgba_result("icon", 1, 1, pixels) {
    Ok(first) => {
      assert_true(first.did_decode())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_pixmap().get_pixel(0, 0), Color::green())
      let first_pixmap = first.get_pixmap()
      first_pixmap.set_pixel(0, 0, Color::red())
    }
    Err(_) => abort("expected RGBA cache decode")
  }
  assert_eq(cache.len(), 1)
  match cache.get("icon") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::green())
    None => abort("expected cached decoded RGBA pixmap")
  }

  match cache.get_or_decode_rgba_result("icon", 1, 1, Bytes::from_array([])) {
    Ok(second) => {
      assert_true(!second.did_decode())
      assert_true(second.did_hit_cache())
      assert_eq(second.get_pixmap().get_pixel(0, 0), Color::green())
    }
    Err(_) => abort("expected cached RGBA pixmap hit")
  }
  assert_eq(cache.len(), 1)
}

///|
test "PixmapCache::get_or_decode_png_result decodes misses and reports hits" {
  let cache = PixmapCache::new()
  let source = Pixmap::new(1, 1)
  source.set_pixel(0, 0, Color::green())

  match source.to_png_bytes() {
    Ok(png) =>
      match cache.get_or_decode_png_result("icon", png) {
        Ok(first) => {
          assert_true(first.did_decode())
          assert_true(!first.did_hit_cache())
          assert_eq(first.get_pixmap().get_pixel(0, 0), Color::green())
          let first_pixmap = first.get_pixmap()
          first_pixmap.set_pixel(0, 0, Color::red())
        }
        Err(_) => abort("expected PNG cache decode")
      }
    Err(_) => abort("expected PNG encode")
  }
  assert_eq(cache.len(), 1)
  match cache.get("icon") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::green())
    None => abort("expected cached decoded PNG pixmap")
  }

  match cache.get_or_decode_png_result("icon", Bytes::from_array([0, 0])) {
    Ok(second) => {
      assert_true(!second.did_decode())
      assert_true(second.did_hit_cache())
      assert_eq(second.get_pixmap().get_pixel(0, 0), Color::green())
    }
    Err(_) => abort("expected cached PNG pixmap hit")
  }
  assert_eq(cache.len(), 1)
}

///|
test "PixmapCache::get_or_decode_rgba leaves cache unchanged on decode errors" {
  let cache = PixmapCache::new()
  match cache.get_or_decode_rgba("bad", 2, 1, Bytes::from_array([1, 2, 3, 4])) {
    Err(PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected RGBA cache decode error")
  }
  assert_true(cache.is_empty())
  assert_true(!cache.contains("bad"))
}

///|
test "PixmapCache::get_or_decode_png leaves cache unchanged on decode errors" {
  let cache = PixmapCache::new()
  match cache.get_or_decode_png("bad", Bytes::from_array([137, 80])) {
    Err(PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected PNG cache decode error")
  }
  assert_true(cache.is_empty())
  assert_true(!cache.contains("bad"))
}

///|
test "PixmapCache::get_or_decode_bmp leaves cache unchanged on decode errors" {
  let cache = PixmapCache::new()
  match cache.get_or_decode_bmp("bad", Bytes::from_array([66, 77])) {
    Err(PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected BMP cache decode error")
  }
  assert_true(cache.is_empty())
  assert_true(!cache.contains("bad"))
}

///|
test "PixmapCache::contains reports membership without refreshing LRU" {
  let cache = PixmapCache::with_capacity(2)
  let red = Pixmap::new(1, 1)
  red.set_pixel(0, 0, Color::red())
  let green = Pixmap::new(1, 1)
  green.set_pixel(0, 0, Color::green())
  let blue = Pixmap::new(1, 1)
  blue.set_pixel(0, 0, Color::blue())
  ignore(cache.insert("red", red))
  ignore(cache.insert("green", green))
  assert_true(cache.contains("red"))
  assert_true(!cache.contains("blue"))

  ignore(cache.insert("blue", blue))
  assert_eq(cache.len(), 2)
  assert_true(!cache.contains("red"))
  assert_true(cache.contains("green"))
  assert_true(cache.contains("blue"))
}

///|
test "PixmapCache::with_capacity evicts least recently used pixmaps" {
  let cache = PixmapCache::with_capacity(2)
  assert_true(cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 2)
  let red = Pixmap::new(1, 1)
  red.set_pixel(0, 0, Color::red())
  let green = Pixmap::new(1, 1)
  green.set_pixel(0, 0, Color::green())
  let blue = Pixmap::new(1, 1)
  blue.set_pixel(0, 0, Color::blue())
  ignore(cache.insert("red", red))
  ignore(cache.insert("green", green))
  match cache.get("red") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::red())
    None => abort("expected red pixmap")
  }
  ignore(cache.insert("blue", blue))
  assert_eq(cache.len(), 2)
  assert_true(cache.get("green") is None)
  assert_true(cache.get("red") is Some(_))
  assert_true(cache.get("blue") is Some(_))
}

///|
test "PixmapCache::with_capacity clamps invalid capacity" {
  let cache = PixmapCache::with_capacity(0)
  assert_true(cache.is_capacity_bounded())
  assert_eq(cache.capacity(), 1)
  let red = Pixmap::new(1, 1)
  red.set_pixel(0, 0, Color::red())
  let blue = Pixmap::new(1, 1)
  blue.set_pixel(0, 0, Color::blue())
  let inserted = cache.get_or_insert_result("red", red)
  assert_true(inserted.did_insert())
  assert_eq(cache.len(), 1)
  ignore(cache.insert("blue", blue))
  assert_eq(cache.len(), 1)
  assert_true(cache.get("red") is None)
  match cache.get("blue") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), Color::blue())
    None => abort("expected blue pixmap")
  }
}
