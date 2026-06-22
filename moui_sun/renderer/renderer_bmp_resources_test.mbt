///|
test "Renderer cached BMP image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 2)
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())

  match
    renderer.draw_bmp_bytes_cached_with_renderer_resources(
      icon.to_bmp_bytes(),
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
    Err(_) => abort("expected cached BMP draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_bmp_bytes_cached_with_renderer_resources(
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
    Err(_) => abort("expected cached BMP hit")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  match
    renderer.draw_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
      2,
      0,
      resources,
      "broken",
      @graphics.Paint::new(),
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected cached BMP draw decode error")
  }
  assert_true(!resources.contains_image("broken"))
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::white())
}

///|
test "Renderer cached BMP source rect path uses RendererResources" {
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
    renderer.draw_bmp_bytes_rect_cached_with_renderer_resources(
      atlas.to_bmp_bytes(),
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
    Err(_) => abort("expected cached BMP source rect draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  match
    renderer.draw_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      blue_rect,
      1,
      0,
      resources,
      "atlas",
      @graphics.Paint::new(),
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached BMP source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::blue())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
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
    Err(_) => abort("expected cached quality BMP source rect hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())
}

///|
test "Renderer cached BMP tiled image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)

  match
    renderer.draw_tiled_bmp_bytes_rect_cached_with_renderer_resources(
      tile.to_bmp_bytes(),
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
    Err(_) => abort("expected cached BMP tiled draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_tiled_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
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
    Err(_) => abort("expected cached BMP tiled hit")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_tiled_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
      src_rect,
      0,
      0,
      4,
      1,
      resources,
      "broken",
      @graphics.Paint::new(),
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected cached BMP tiled decode error")
  }
  assert_true(!resources.contains_image("broken"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer cached BMP transformed image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)

  match
    renderer.draw_transformed_sampled_bmp_bytes_cached_with_renderer_resources(
      tile.to_bmp_bytes(),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-bmp",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed BMP draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_quality_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-bmp",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(full) => {
      assert_true(!full.did_decode_pixmap())
      assert_true(full.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed quality BMP hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_quality_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      src_rect,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-bmp",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed BMP hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_transformed_sampled_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-bmp",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected cached transformed BMP decode error")
  }
  assert_true(!resources.contains_image("broken-transform-bmp"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-quality-bmp",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected cached transformed quality BMP decode error")
  }
  assert_true(!resources.contains_image("broken-transform-quality-bmp"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
      src_rect,
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "broken-transform-quality-bmp-rect",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected cached transformed quality BMP rect decode error")
  }
  assert_true(!resources.contains_image("broken-transform-quality-bmp-rect"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::white())

  match
    renderer.draw_transformed_quality_bmp_bytes_cached_with_renderer_resources(
      tile.to_bmp_bytes(),
      0.0,
      0.0,
      2.0,
      1.0,
      resources,
      "tile-transform-quality-bmp",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(quality) => {
      assert_true(quality.did_decode_pixmap())
      assert_true(!quality.did_hit_cache())
    }
    Err(_) => abort("expected cached transformed quality BMP insert")
  }
  assert_true(resources.contains_image("tile-transform-quality-bmp"))
  assert_true(!resources.contains_image("tile-transform-bmp"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
}

///|
test "Renderer sampled cached BMP image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let image = make_renderer_test_bicubic_source()

  match
    renderer.draw_sampled_bmp_bytes_cached_with_renderer_resources(
      image.to_bmp_bytes(),
      0,
      0,
      3,
      1,
      resources,
      "sampled-bmp",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Bicubic,
    ) {
    Ok(first) => {
      assert_true(first.did_decode_pixmap())
      assert_true(!first.did_hit_cache())
    }
    Err(_) => abort("expected cached sampled BMP draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=34, g=0, b=0, a=255),
  )

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_sampled_bmp_bytes_rect_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      @graphics.PixelRect::new(x=0, y=0, width=4, height=1),
      0,
      0,
      3,
      1,
      resources,
      "sampled-bmp",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Bilinear,
    ) {
    Ok(second) => {
      assert_true(!second.did_decode_pixmap())
      assert_true(second.did_hit_cache())
    }
    Err(_) => abort("expected cached sampled BMP hit")
  }
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=128, g=0, b=0, a=255),
  )

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_sampled_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
      0,
      0,
      3,
      1,
      resources,
      "broken-sampled-bmp",
      @graphics.Paint::new(),
      @graphics.ImageSampling::Bicubic,
    ) {
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected sampled BMP decode error")
  }
  assert_true(!resources.contains_image("broken-sampled-bmp"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer quality cached BMP image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let panel = @graphics.Pixmap::new(1, 1)
  panel.set_pixel(0, 0, @graphics.Color::green())

  match
    renderer.draw_quality_bmp_bytes_cached_with_renderer_resources(
      panel.to_bmp_bytes(),
      0,
      0,
      2,
      1,
      resources,
      "panel",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(first) => assert_true(first.did_decode_pixmap())
    Err(_) => abort("expected cached quality BMP draw")
  }
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
      2,
      0,
      2,
      1,
      resources,
      "panel",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ) {
    Ok(second) => assert_true(second.did_hit_cache())
    Err(_) => abort("expected cached quality BMP hit")
  }
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())
}

///|
test "Renderer cached BMP nine-patch image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let panel = make_renderer_test_nine_patch_source()
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)

  match
    renderer.draw_nine_patch_bmp_bytes_cached_with_renderer_resources(
      panel.to_bmp_bytes(),
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
    Err(_) => abort("expected cached BMP nine-patch draw")
  }
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )

  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_quality_nine_patch_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([0, 0]),
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
    Err(_) => abort("expected cached BMP nine-patch hit")
  }
  assert_eq(
    canvas.get_pixmap().get_pixel(4, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )

  match
    renderer.draw_nine_patch_bmp_bytes_cached_with_renderer_resources(
      Bytes::from_array([66, 77]),
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
    Err(@graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)) => ()
    _ => abort("expected cached BMP nine-patch decode error")
  }
  assert_true(!resources.contains_image("broken"))
}
