///|
test "RendererResources exposes image cache for BMP decode" {
  let resources = RendererResources::new(16, 16)
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())

  match
    resources
    .get_image_cache()
    .get_or_decode_bmp_result("icon", icon.to_bmp_bytes()) {
    Ok(first) => {
      assert_true(first.did_decode())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
    }
    Err(_) => abort("expected renderer resources BMP decode")
  }
  assert_true(resources.contains_image("icon"))
  assert_eq(resources.snapshot().get_image_count(), 1)

  match
    resources
    .get_image_cache()
    .get_or_decode_bmp("icon", Bytes::from_array([0, 0])) {
    Ok(second) => assert_eq(second.get_pixel(0, 0), @graphics.Color::green())
    Err(_) => abort("expected renderer resources BMP cache hit")
  }
  assert_eq(resources.snapshot().get_image_count(), 1)
}

///|
test "RendererResources exposes image cache for RGBA decode" {
  let resources = RendererResources::new(16, 16)
  let pixels = Bytes::from_array([0, 255, 0, 255])

  match
    resources.get_image_cache().get_or_decode_rgba_result("icon", 1, 1, pixels) {
    Ok(first) => {
      assert_true(first.did_decode())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
    }
    Err(_) => abort("expected renderer resources RGBA decode")
  }
  assert_true(resources.contains_image("icon"))
  assert_eq(resources.snapshot().get_image_count(), 1)

  match
    resources
    .get_image_cache()
    .get_or_decode_rgba("icon", 1, 1, Bytes::from_array([])) {
    Ok(second) => assert_eq(second.get_pixel(0, 0), @graphics.Color::green())
    Err(_) => abort("expected renderer resources RGBA cache hit")
  }
  assert_eq(resources.snapshot().get_image_count(), 1)
}

///|
test "Renderer::draw_pixmap_cached reuses cached pixmap copies" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let image_cache = @graphics.PixmapCache::new()
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::red())

  let first = renderer.draw_pixmap_cached(
    icon,
    0,
    0,
    image_cache,
    "icon",
    @graphics.Paint::new(),
  )
  assert_true(first.did_insert_pixmap())
  assert_true(!first.did_hit_cache())
  assert_eq(image_cache.len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())

  icon.set_pixel(0, 0, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_pixmap_cached(
    icon,
    1,
    0,
    image_cache,
    "icon",
    @graphics.Paint::new(),
  )
  assert_true(!second.did_insert_pixmap())
  assert_true(second.did_hit_cache())
  assert_eq(image_cache.len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
}
