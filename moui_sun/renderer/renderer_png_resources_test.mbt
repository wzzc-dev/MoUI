///|
test "RendererResources exposes image cache for PNG decode" {
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 2)
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())
  let png = must_renderer_test_png_bytes(icon)

  match resources.get_image_cache().get_or_decode_png_result("icon", png) {
    Ok(first) => {
      assert_true(first.did_decode())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
    }
    Err(_) => abort("expected PNG resource decode")
  }
  assert_true(resources.contains_image("icon"))

  match
    resources
    .get_image_cache()
    .get_or_decode_png("icon", Bytes::from_array([0, 0])) {
    Ok(cached) => assert_eq(cached.get_pixel(0, 0), @graphics.Color::green())
    Err(_) => abort("expected PNG resource cache hit")
  }
}

///|
test "Renderer cached PNG image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 2)
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())

  match
    renderer.draw_png_bytes_cached_with_renderer_resources(
      must_renderer_test_png_bytes(icon),
      0,
      0,
      resources,
      "icon",
      @graphics.Paint::new(),
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached PNG draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      1,
      0,
      resources,
      "icon",
      @graphics.Paint::new(),
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached PNG hit")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  match
    renderer.draw_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([137, 80]),
      2,
      0,
      resources,
      "broken",
      @graphics.Paint::new(),
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected cached PNG draw decode error")
  }
  assert_true(!resources.contains_image("broken"))
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::white())
}

///|
test "Renderer cached PNG source rect path uses RendererResources" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let atlas = @graphics.Pixmap::new(3, 1)
  atlas.set_pixel(0, 0, @graphics.Color::red())
  atlas.set_pixel(1, 0, @graphics.Color::green())
  atlas.set_pixel(2, 0, @graphics.Color::blue())
  let green_rect = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let blue_rect = @graphics.PixelRect::new(x=2, y=0, width=1, height=1)

  match
    renderer.draw_png_bytes_rect_cached_with_renderer_resources(
      must_renderer_test_png_bytes(atlas),
      green_rect,
      0,
      0,
      resources,
      "atlas-png",
      @graphics.Paint::new(),
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached PNG source rect draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  match
    renderer.draw_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      blue_rect,
      1,
      0,
      resources,
      "atlas-png",
      @graphics.Paint::new(),
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached PNG source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::blue())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      green_rect,
      0,
      0,
      2,
      1,
      resources,
      "atlas-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(scaled) => assert_true(scaled.did_hit_cache())
    Err(_) => abort("expected cached quality PNG source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
}

///|
test "Renderer cached PNG tiled image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)

  match
    renderer.draw_tiled_png_bytes_rect_cached_with_renderer_resources(
      must_renderer_test_png_bytes(tile),
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "tile-png",
      @graphics.Paint::new(),
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached PNG tiled draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_tiled_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "tile-png",
      @graphics.Paint::new(),
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached PNG tiled hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_tiled_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([137, 80]),
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "broken-tile-png",
      @graphics.Paint::new(),
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected cached PNG tiled decode error")
  }
  assert_true(!resources.contains_image("broken-tile-png"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer cached PNG nine-patch image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let panel = make_renderer_test_nine_patch_source()
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)

  match
    renderer.draw_nine_patch_png_bytes_cached_with_renderer_resources(
      must_renderer_test_png_bytes(panel),
      0,
      0,
      5,
      5,
      insets,
      resources,
      "panel-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached PNG nine-patch draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_nine_patch_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      0,
      0,
      5,
      5,
      insets,
      resources,
      "panel-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached quality PNG nine-patch hit")
  }
  assert_eq(
    canvas.get_pixmap().get_pixel(4, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )

  match
    renderer.draw_nine_patch_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([137, 80]),
      0,
      0,
      5,
      5,
      insets,
      resources,
      "broken-panel-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected cached PNG nine-patch decode error")
  }
  assert_true(!resources.contains_image("broken-panel-png"))
}

///|
test "Renderer sampled cached PNG image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let sprite = make_renderer_test_tile_source()

  match
    renderer.draw_sampled_png_bytes_cached_with_renderer_resources(
      must_renderer_test_png_bytes(sprite),
      0,
      0,
      2,
      1,
      resources,
      "sprite-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached sampled PNG draw")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  match
    renderer.draw_quality_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      2,
      0,
      2,
      1,
      resources,
      "sprite-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached quality PNG hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_sampled_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      0,
      0,
      2,
      1,
      resources,
      "sprite-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(rect) => assert_true(rect.did_hit_cache())
    Err(_) => abort("expected cached sampled PNG source rect hit")
  }
  match
    renderer.draw_quality_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      2,
      0,
      2,
      1,
      resources,
      "sprite-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(rect) => assert_true(rect.did_hit_cache())
    Err(_) => abort("expected cached quality PNG source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::red())
}

///|
test "Renderer cached PNG transformed image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let full_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)
  let green_rect = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)

  match
    renderer.draw_transformed_sampled_png_bytes_cached_with_renderer_resources(
      must_renderer_test_png_bytes(tile),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed PNG draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_quality_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached transformed quality PNG hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_sampled_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      green_rect,
      0.0,
      0.0,
      1.0,
      1.0,
      resources,
      "tile-transform-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(rect) => assert_true(rect.did_hit_cache())
    Err(_) => abort("expected cached transformed sampled PNG source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_quality_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      full_rect,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(rect) => assert_true(rect.did_hit_cache())
    Err(_) => abort("expected cached transformed quality PNG source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_sampled_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([137, 80]),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-png",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected cached transformed PNG decode error")
  }
  assert_true(!resources.contains_image("broken-transform-png"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_png_bytes_cached_with_renderer_resources(
      Bytes::from_array([137, 80]),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-quality-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected cached transformed quality PNG decode error")
  }
  assert_true(!resources.contains_image("broken-transform-quality-png"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_png_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([137, 80]),
      full_rect,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-quality-png-rect",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)) => ()
    _ => abort("expected cached transformed quality PNG rect decode error")
  }
  assert_true(!resources.contains_image("broken-transform-quality-png-rect"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_png_bytes_cached_with_renderer_resources(
      must_renderer_test_png_bytes(tile),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-quality-png",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(quality) => {
      assert_true(quality.did_decode_pixmap())
      assert_true(!quality.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed quality PNG insert")
  }
  assert_true(resources.contains_image("tile-transform-quality-png"))
  assert_true(!resources.contains_image("tile-transform-png"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
}
