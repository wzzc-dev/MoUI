///|
test "RenderPipeline BMP bytes replay uses RendererResources image cache" {
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 2)
  let renderer = Renderer::new(@graphics.Canvas::new(3, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_bmp_bytes_keyed(
      "icon",
      icon.to_bmp_bytes(),
      0,
      0,
      @graphics.Paint::new(),
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_image_count(), 1)
  assert_eq(plan.get_keyed_image_count(), 1)
  assert_eq(plan.get_resource_count(), 1)
  assert_eq(plan.get_keyed_resource_count(), 1)
  assert_eq(plan.get_image_source_pixel_count(), 1)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("icon"))
  assert_eq(images[0].get_source_width(), 1)
  assert_eq(images[0].get_source_height(), 1)

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
  assert_true(resources.contains_image("icon"))
  assert_eq(resources.get_image_cache().len(), 1)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::green(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_bmp_bytes_keyed(
      "icon",
      Bytes::from_array([0, 0]),
      1,
      0,
      @graphics.Paint::new(),
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
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::green(),
  )
}

///|
test "RenderPipeline BMP bytes transformed sampled replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let canvas = @graphics.Canvas::new(7, 1)
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let renderer = Renderer::new(canvas)
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_sampled_bmp_bytes_keyed(
      "bmp-transform",
      sprite.to_bmp_bytes(),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_bmp_bytes_rect_keyed(
      "bmp-transform-sprite",
      sprite.to_bmp_bytes(),
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 3)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-transform"))
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("bmp-transform-sprite"))
  assert_eq(images[1].get_source_width(), 1)
  assert_eq(images[1].get_source_height(), 1)
  let batches = first_pipeline.batch_plan(7, 1).get_batches()
  assert_eq(batches.length(), 2)
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Image)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=1)),
  )

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 3)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_keyed_resource_count(), 2)
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-transform"))
  assert_true(resources.contains_image("bmp-transform-sprite"))
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
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
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(5, 0),
    @graphics.Color::green(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_sampled_bmp_bytes_keyed(
      "bmp-transform",
      Bytes::from_array([66, 77]),
      2.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_bmp_bytes_rect_keyed(
      "bmp-transform-sprite",
      Bytes::from_array([66, 77]),
      src_right,
      4.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    ),
    resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_keyed_resource_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::red(),
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
    @graphics.Color::green(),
  )
}

///|
test "RenderPipeline BMP bytes quality replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(7, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_quality_bmp_bytes_keyed(
      "bmp-quality",
      sprite.to_bmp_bytes(),
      0,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_bmp_bytes_rect_keyed(
      "bmp-quality-sprite",
      sprite.to_bmp_bytes(),
      src_right,
      5,
      0,
      2,
      1,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_image_source_pixel_count(), 3)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-quality"))
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("bmp-quality-sprite"))
  assert_eq(images[1].get_source_width(), 1)
  assert_eq(images[1].get_source_height(), 1)
  let batches = first_pipeline.batch_plan(7, 1).get_batches()
  assert_eq(batches.length(), 2)
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Image)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=7, height=1)),
  )

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
  assert_true(resources.contains_image("bmp-quality"))
  assert_true(resources.contains_image("bmp-quality-sprite"))
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
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(5, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::green(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_quality_bmp_bytes_keyed(
      "bmp-quality",
      Bytes::from_array([66, 77]),
      1,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_bmp_bytes_rect_keyed(
      "bmp-quality-sprite",
      Bytes::from_array([66, 77]),
      src_right,
      5,
      0,
      2,
      1,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
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
    @graphics.Color::red(),
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
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(5, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::green(),
  )
}
