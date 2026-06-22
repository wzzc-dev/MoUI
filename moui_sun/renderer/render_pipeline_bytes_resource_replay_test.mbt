///|
test "RenderPipeline bytes source-rect replay uses RendererResources image cache" {
  let atlas = make_renderer_test_tile_source()
  let src_left = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(5, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_bmp_bytes_rect_keyed(
      "bmp-atlas",
      atlas.to_bmp_bytes(),
      src_right,
      0,
      0,
      @graphics.Paint::new(),
    )
    .draw_png_bytes_rect_keyed(
      "png-atlas",
      must_renderer_test_png_bytes(atlas),
      src_left,
      1,
      0,
      @graphics.Paint::new(),
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 2)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-atlas"))
  assert_eq(images[0].get_source_width(), 1)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("png-atlas"))
  assert_eq(images[1].get_source_width(), 1)
  assert_eq(images[1].get_source_height(), 1)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 3)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-atlas"))
  assert_true(resources.contains_image("png-atlas"))
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_bmp_bytes_rect_keyed(
      "bmp-atlas",
      Bytes::from_array([0, 0]),
      src_right,
      2,
      0,
      @graphics.Paint::new(),
    )
    .draw_png_bytes_rect_keyed(
      "png-atlas",
      Bytes::from_array([137, 80]),
      src_left,
      3,
      0,
      @graphics.Paint::new(),
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::red(),
  )
}

///|
test "RenderPipeline bytes tiled source-rect replay uses RendererResources image cache" {
  let tile = make_renderer_test_tile_source()
  let src_rect = @graphics.PixelRect::new(x=0, y=0, width=2, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(8, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_tiled_bmp_bytes_rect_keyed(
      "bmp-pattern",
      tile.to_bmp_bytes(),
      src_rect,
      0,
      0,
      4,
      1,
      @graphics.Paint::new(),
    )
    .draw_tiled_png_bytes_rect_keyed(
      "png-pattern",
      must_renderer_test_png_bytes(tile),
      src_rect,
      4,
      0,
      4,
      1,
      @graphics.Paint::new(),
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 4)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-pattern"))
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("png-pattern"))
  assert_eq(images[1].get_source_width(), 2)
  assert_eq(images[1].get_source_height(), 1)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 3)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-pattern"))
  assert_true(resources.contains_image("png-pattern"))
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(4, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(5, 0),
    @graphics.Color::green(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_tiled_bmp_bytes_rect_keyed(
      "bmp-pattern",
      Bytes::from_array([0, 0]),
      src_rect,
      0,
      0,
      4,
      1,
      @graphics.Paint::new(),
    )
    .draw_tiled_png_bytes_rect_keyed(
      "png-pattern",
      Bytes::from_array([137, 80]),
      src_rect,
      4,
      0,
      4,
      1,
      @graphics.Paint::new(),
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(7, 0),
    @graphics.Color::green(),
  )
}

///|
test "RenderPipeline bytes nine-patch replay uses RendererResources image cache" {
  let panel = make_renderer_test_nine_patch_source()
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(10, 5))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_nine_patch_bmp_bytes_keyed(
      "bmp-panel",
      panel.to_bmp_bytes(),
      0,
      0,
      5,
      5,
      insets,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_nine_patch_png_bytes_keyed(
      "png-panel",
      must_renderer_test_png_bytes(panel),
      5,
      0,
      5,
      5,
      insets,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 18)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-panel"))
  assert_eq(images[0].get_source_width(), 3)
  assert_eq(images[0].get_source_height(), 3)
  assert_true(images[1].get_resource_key() == Some("png-panel"))
  assert_eq(images[1].get_source_width(), 3)
  assert_eq(images[1].get_source_height(), 3)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 3)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-panel"))
  assert_true(resources.contains_image("png-panel"))
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(9, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_nine_patch_bmp_bytes_keyed(
      "bmp-panel",
      Bytes::from_array([0, 0]),
      0,
      0,
      5,
      5,
      insets,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_nine_patch_png_bytes_keyed(
      "png-panel",
      Bytes::from_array([137, 80]),
      5,
      0,
      5,
      5,
      insets,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(9, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )
}

///|
test "RenderPipeline RGBA bytes nine-patch replay uses RendererResources image cache" {
  let panel = make_renderer_test_nine_patch_source()
  let insets = @graphics.NinePatchInsets::new(left=1, top=1, right=1, bottom=1)
  let resources = RendererResources::with_capacities(16, 16, 1, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(10, 5))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_nine_patch_rgba_bytes_keyed(
      "rgba-panel",
      panel.to_rgba_bytes(),
      3,
      3,
      0,
      0,
      5,
      5,
      insets,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_image_count(), 1)
  assert_eq(plan.get_keyed_image_count(), 1)
  assert_eq(plan.get_resource_count(), 1)
  assert_eq(plan.get_keyed_resource_count(), 1)
  assert_eq(plan.get_image_source_pixel_count(), 9)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("rgba-panel"))
  assert_eq(images[0].get_source_width(), 3)
  assert_eq(images[0].get_source_height(), 3)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 2)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 1)
  assert_eq(first.get_keyed_image_count(), 1)
  assert_eq(first.get_image_cache_insert_count(), 1)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 1)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("rgba-panel"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(4, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_nine_patch_rgba_bytes_keyed(
      "rgba-panel",
      Bytes::from_array([]),
      3,
      3,
      5,
      0,
      5,
      5,
      insets,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 2)
  assert_eq(second.get_image_count(), 1)
  assert_eq(second.get_keyed_image_count(), 1)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 1)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 1)
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(7, 2),
    @graphics.Color::new(r=50, g=0, b=0),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(9, 4),
    @graphics.Color::new(r=90, g=0, b=0),
  )
}

///|
test "RenderPipeline bytes sampled replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(8, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_sampled_bmp_bytes_keyed(
      "bmp-sampled",
      sprite.to_bmp_bytes(),
      0,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_png_bytes_keyed(
      "png-sampled",
      must_renderer_test_png_bytes(sprite),
      4,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 4)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-sampled"))
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("png-sampled"))
  assert_eq(images[1].get_source_width(), 2)
  assert_eq(images[1].get_source_height(), 1)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 3)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-sampled"))
  assert_true(resources.contains_image("png-sampled"))
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(4, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(5, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::green(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_sampled_bmp_bytes_keyed(
      "bmp-sampled",
      Bytes::from_array([0, 0]),
      0,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_png_bytes_keyed(
      "png-sampled",
      Bytes::from_array([137, 80]),
      4,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(4, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(7, 0),
    @graphics.Color::green(),
  )
}

///|
test "RenderPipeline bytes sampled source-rect replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_left = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(8, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_sampled_bmp_bytes_rect_keyed(
      "bmp-sampled-sprite",
      sprite.to_bmp_bytes(),
      src_right,
      0,
      0,
      2,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_png_bytes_rect_keyed(
      "png-sampled-sprite",
      must_renderer_test_png_bytes(sprite),
      src_left,
      2,
      0,
      2,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 2)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-sampled-sprite"))
  assert_eq(images[0].get_source_width(), 1)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("png-sampled-sprite"))
  assert_eq(images[1].get_source_width(), 1)
  assert_eq(images[1].get_source_height(), 1)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 3)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-sampled-sprite"))
  assert_true(resources.contains_image("png-sampled-sprite"))
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::red(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_sampled_bmp_bytes_rect_keyed(
      "bmp-sampled-sprite",
      Bytes::from_array([0, 0]),
      src_right,
      4,
      0,
      2,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_png_bytes_rect_keyed(
      "png-sampled-sprite",
      Bytes::from_array([137, 80]),
      src_left,
      6,
      0,
      2,
      1,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(4, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(5, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(7, 0),
    @graphics.Color::red(),
  )
}
