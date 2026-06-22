///|
test "Renderer cached RGBA image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 2)
  let pixels = Bytes::from_array([0, 255, 0, 255])

  match
    renderer.draw_rgba_bytes_cached_with_renderer_resources(
      pixels,
      1,
      1,
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
    Err(_) => abort("expected cached RGBA draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([]),
      1,
      1,
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
    Err(_) => abort("expected cached RGBA hit")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  match
    renderer.draw_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([1, 2, 3, 4]),
      2,
      1,
      2,
      0,
      resources,
      "broken",
      @graphics.Paint::new(),
    ) {
    Err(@graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected cached RGBA draw decode error")
  }
  assert_true(!resources.contains_image("broken"))
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::white())
}

///|
test "Renderer cached RGBA source rect path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
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
    renderer.draw_rgba_bytes_rect_cached_with_renderer_resources(
      atlas.to_rgba_bytes(),
      3,
      1,
      green_rect,
      0,
      0,
      resources,
      "atlas",
      @graphics.Paint::new(),
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached RGBA source rect draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  match
    renderer.draw_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([]),
      3,
      1,
      blue_rect,
      1,
      0,
      resources,
      "atlas",
      @graphics.Paint::new(),
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached RGBA source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::blue())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([]),
      3,
      1,
      green_rect,
      2,
      0,
      2,
      1,
      resources,
      "atlas",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(scaled) => assert_true(scaled.did_hit_cache())
    Err(_) => abort("expected cached quality RGBA source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())
}

///|
test "Renderer cached RGBA tiled image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)

  match
    renderer.draw_tiled_rgba_bytes_rect_cached_with_renderer_resources(
      tile.to_rgba_bytes(),
      2,
      1,
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "tile",
      @graphics.Paint::new(),
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached RGBA tiled draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_tiled_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([]),
      2,
      1,
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "tile",
      @graphics.Paint::new(),
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached RGBA tiled hit")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_tiled_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([1, 2, 3, 4]),
      2,
      1,
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "broken",
      @graphics.Paint::new(),
    ) {
    Err(@graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected cached RGBA tiled decode error")
  }
  assert_true(!resources.contains_image("broken"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer cached RGBA nine-patch image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let panel = make_renderer_test_nine_patch_source()
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)

  match
    renderer.draw_nine_patch_rgba_bytes_cached_with_renderer_resources(
      panel.to_rgba_bytes(),
      3,
      3,
      0,
      0,
      5,
      5,
      insets,
      resources,
      "panel",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached RGBA nine-patch draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=10, g=0, b=0),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(4, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )

  panel.set_pixel(1, 1, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_nine_patch_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([]),
      3,
      3,
      0,
      0,
      5,
      5,
      insets,
      resources,
      "panel",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached quality RGBA nine-patch hit")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(4, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )

  match
    renderer.draw_nine_patch_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([1, 2, 3, 4]),
      3,
      3,
      0,
      0,
      5,
      5,
      insets,
      resources,
      "broken",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Err(@graphics.PixmapDecodeError::RgbaByteLengthMismatch(36, 4)) => ()
    _ => abort("expected cached RGBA nine-patch decode error")
  }
  assert_true(!resources.contains_image("broken"))
  assert_eq(resources.get_image_cache().len(), 1)
}

///|
test "Renderer sampled cached RGBA image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let sprite = @graphics.Pixmap::new(2, 1)
  sprite.set_pixel(0, 0, @graphics.Color::red())
  sprite.set_pixel(1, 0, @graphics.Color::blue())

  match
    renderer.draw_sampled_rgba_bytes_cached_with_renderer_resources(
      sprite.to_rgba_bytes(),
      2,
      1,
      0,
      0,
      2,
      1,
      resources,
      "sprite",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached sampled RGBA draw")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::blue())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([]),
      2,
      1,
      2,
      0,
      2,
      1,
      resources,
      "sprite",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached quality RGBA hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::blue())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_sampled_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([]),
      2,
      1,
      @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      0,
      0,
      2,
      1,
      resources,
      "sprite",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(rect) => assert_true(rect.did_hit_cache())
    Err(_) => abort("expected cached sampled RGBA source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::blue())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::blue())
}

///|
test "Renderer cached RGBA transformed image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)

  match
    renderer.draw_transformed_sampled_rgba_bytes_cached_with_renderer_resources(
      tile.to_rgba_bytes(),
      2,
      1,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-rgba",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed RGBA draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_quality_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([]),
      2,
      1,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-rgba",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(full) => {
      assert_true(!full.did_decode_pixmap())
      assert_true(full.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed quality RGBA hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_quality_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([]),
      2,
      1,
      src_rect,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-rgba",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed RGBA hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_sampled_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([1, 2, 3, 4]),
      2,
      1,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-rgba",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Err(@graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected cached transformed RGBA decode error")
  }
  assert_true(!resources.contains_image("broken-transform-rgba"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_rgba_bytes_cached_with_renderer_resources(
      Bytes::from_array([1, 2, 3, 4]),
      2,
      1,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-quality-rgba",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Err(@graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected cached transformed quality RGBA decode error")
  }
  assert_true(!resources.contains_image("broken-transform-quality-rgba"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_rgba_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([1, 2, 3, 4]),
      2,
      1,
      src_rect,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-quality-rgba-rect",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Err(@graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)) => ()
    _ => abort("expected cached transformed quality RGBA rect decode error")
  }
  assert_true(!resources.contains_image("broken-transform-quality-rgba-rect"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_rgba_bytes_cached_with_renderer_resources(
      tile.to_rgba_bytes(),
      2,
      1,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-quality-rgba",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(quality) => {
      assert_true(quality.did_decode_pixmap())
      assert_true(!quality.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed quality RGBA insert")
  }
  assert_true(resources.contains_image("tile-transform-quality-rgba"))
  assert_true(!resources.contains_image("tile-transform-rgba"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
}
