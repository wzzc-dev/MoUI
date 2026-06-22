///|
test "Renderer cached image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(2, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())

  let first = renderer.draw_pixmap_cached_with_renderer_resources(
    icon,
    0,
    0,
    resources,
    "icon",
    @graphics.Paint::new(),
  )
  assert_true(first.did_insert_pixmap())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  icon.set_pixel(0, 0, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_pixmap_cached_with_renderer_resources(
    icon,
    1,
    0,
    resources,
    "icon",
    @graphics.Paint::new(),
  )
  assert_true(second.did_hit_cache())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
}

///|
test "Renderer cached image source rect path uses RendererResources" {
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

  let first = renderer.draw_pixmap_rect_cached_with_renderer_resources(
    atlas,
    green_rect,
    0,
    0,
    resources,
    "atlas",
    @graphics.Paint::new(),
  )
  assert_true(first.did_insert_pixmap())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())

  atlas.set_pixel(1, 0, @graphics.Color::red())
  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_pixmap_rect_cached_with_renderer_resources(
    atlas,
    green_rect,
    1,
    0,
    resources,
    "atlas",
    @graphics.Paint::new(),
  )
  assert_true(second.did_hit_cache())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  let scaled = renderer.draw_quality_pixmap_rect_cached_with_renderer_resources(
    atlas,
    blue_rect,
    2,
    0,
    2,
    1,
    resources,
    "atlas",
    @graphics.Paint::new(),
    @graphics.ImageQuality::Fast,
  )
  assert_true(scaled.did_hit_cache())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::blue())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::blue())
}

///|
test "Renderer cached tiled image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)

  let first = renderer.draw_tiled_pixmap_rect_cached_with_renderer_resources(
    tile,
    src_rect,
    0,
    0,
    4,
    1,
    resources,
    "tile",
    @graphics.Paint::new(),
  )
  assert_true(first.did_insert_pixmap())
  assert_true(!first.did_hit_cache())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  tile.set_pixel(0, 0, @graphics.Color::blue())
  tile.set_pixel(1, 0, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_tiled_pixmap_rect_cached_with_renderer_resources(
    tile,
    src_rect,
    0,
    0,
    4,
    1,
    resources,
    "tile",
    @graphics.Paint::new(),
  )
  assert_true(!second.did_insert_pixmap())
  assert_true(second.did_hit_cache())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())
}

///|
test "Renderer cached transformed image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(5, 3)
  canvas.clear(@graphics.Color::white())
  canvas.set_transform(
    @graphics.Transform::translate(tx=1.0, ty=1.0).multiply(
      @graphics.Transform::scale(sx=2.0, sy=1.0),
    ),
  )
  canvas.set_clip_rect(@graphics.Rect::new(x=2.0, y=1.0, width=2.0, height=1.0))
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let tile = make_renderer_test_tile_source()

  let first = renderer.draw_transformed_sampled_pixmap_cached_with_renderer_resources(
    tile,
    0.0,
    0.0,
    2.0,
    1.0,
    resources,
    "tile-transform",
    @graphics.Paint::new(),
    @graphics.ImageSampling::Nearest,
  )
  assert_true(first.did_insert_pixmap())
  assert_true(!first.did_hit_cache())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::white())
  assert_eq(canvas.get_pixmap().get_pixel(2, 1), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 1), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(4, 1), @graphics.Color::white())

  tile.set_pixel(0, 0, @graphics.Color::blue())
  tile.set_pixel(1, 0, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)
  let second = renderer.draw_transformed_quality_pixmap_rect_cached_with_renderer_resources(
    tile,
    src_rect,
    0.0,
    0.0,
    2.0,
    1.0,
    resources,
    "tile-transform",
    @graphics.Paint::new(),
    @graphics.ImageQuality::Fast,
  )
  assert_true(!second.did_insert_pixmap())
  assert_true(second.did_hit_cache())
  assert_eq(canvas.get_pixmap().get_pixel(2, 1), @graphics.Color::red())
  assert_eq(canvas.get_pixmap().get_pixel(3, 1), @graphics.Color::green())
}

///|
test "Renderer cached nine-patch image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(5, 5)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let panel = make_renderer_test_nine_patch_source()
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)

  let first = renderer.draw_nine_patch_pixmap_cached_with_renderer_resources(
    panel,
    0,
    0,
    5,
    5,
    insets,
    resources,
    "panel",
    @graphics.Paint::new(),
    @graphics.ImageSampling::Nearest,
  )
  assert_true(first.did_insert_pixmap())
  assert_true(!first.did_hit_cache())
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
  let second = renderer.draw_quality_nine_patch_pixmap_cached_with_renderer_resources(
    panel,
    0,
    0,
    5,
    5,
    insets,
    resources,
    "panel",
    @graphics.Paint::new(),
    @graphics.ImageQuality::Fast,
  )
  assert_true(!second.did_insert_pixmap())
  assert_true(second.did_hit_cache())
  assert_eq(
    canvas.get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
}

///|
test "Renderer sampled cached image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(3, 1)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let image = make_renderer_test_bicubic_source()

  let first = renderer.draw_sampled_pixmap_cached_with_renderer_resources(
    image,
    0,
    0,
    3,
    1,
    resources,
    "sampled",
    @graphics.Paint::new(),
    @graphics.ImageSampling::Bicubic,
  )
  assert_true(first.did_insert_pixmap())
  assert_true(!first.did_hit_cache())
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=34, g=0, b=0, a=255),
  )

  image.set_pixel(1, 0, @graphics.Color::blue())
  image.set_pixel(3, 0, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=4, height=1)
  let second = renderer.draw_sampled_pixmap_rect_cached_with_renderer_resources(
    image,
    src_rect,
    0,
    0,
    3,
    1,
    resources,
    "sampled",
    @graphics.Paint::new(),
    @graphics.ImageSampling::Bilinear,
  )
  assert_true(!second.did_insert_pixmap())
  assert_true(second.did_hit_cache())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=128, g=0, b=0, a=255),
  )
}

///|
test "Renderer quality cached image path uses RendererResources" {
  let canvas = @graphics.Canvas::new(4, 2)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 1, 1)
  let panel = @graphics.Pixmap::new(1, 1)
  panel.set_pixel(0, 0, @graphics.Color::green())

  let first = renderer.draw_quality_pixmap_cached_with_renderer_resources(
    panel,
    0,
    0,
    2,
    1,
    resources,
    "panel",
    @graphics.Paint::new(),
    @graphics.ImageQuality::Fast,
  )
  assert_true(first.did_insert_pixmap())
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(1, 0), @graphics.Color::green())

  panel.set_pixel(0, 0, @graphics.Color::blue())
  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_quality_pixmap_cached_with_renderer_resources(
    panel,
    2,
    0,
    2,
    1,
    resources,
    "panel",
    @graphics.Paint::new(),
    @graphics.ImageQuality::Fast,
  )
  assert_true(second.did_hit_cache())
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::green())
  assert_eq(canvas.get_pixmap().get_pixel(3, 0), @graphics.Color::green())

  let accent = @graphics.Pixmap::new(1, 1)
  accent.set_pixel(0, 0, @graphics.Color::red())
  ignore(
    renderer.draw_quality_pixmap_cached_with_renderer_resources(
      accent,
      0,
      1,
      1,
      1,
      resources,
      "accent",
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ),
  )
  assert_eq(resources.get_image_cache().len(), 1)
  assert_true(resources.get_image_cache().get("panel") is None)
  match resources.get_image_cache().get("accent") {
    Some(cached) => assert_eq(cached.get_pixel(0, 0), @graphics.Color::red())
    None => abort("expected cached accent pixmap")
  }
}
