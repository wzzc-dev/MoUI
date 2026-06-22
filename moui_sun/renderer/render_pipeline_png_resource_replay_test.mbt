///|
test "RenderPipeline PNG bytes replay uses RendererResources image cache" {
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 2)
  let renderer = Renderer::new(@graphics.Canvas::new(3, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_png_bytes_keyed(
      "icon",
      must_renderer_test_png_bytes(icon),
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
    .draw_png_bytes_keyed(
      "icon",
      Bytes::from_array([137, 80]),
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
test "RenderPipeline PNG bytes transformed sampled replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let canvas = @graphics.Canvas::new(7, 1)
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let renderer = Renderer::new(canvas)
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_sampled_png_bytes_keyed(
      "png-transform",
      must_renderer_test_png_bytes(sprite),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_png_bytes_rect_keyed(
      "png-transform-sprite",
      must_renderer_test_png_bytes(sprite),
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
  assert_true(images[0].get_resource_key() == Some("png-transform"))
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("png-transform-sprite"))
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
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("png-transform"))
  assert_true(resources.contains_image("png-transform-sprite"))
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
    .draw_transformed_sampled_png_bytes_keyed(
      "png-transform",
      Bytes::from_array([137, 80]),
      2.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageSampling::Nearest,
    )
    .draw_transformed_sampled_png_bytes_rect_keyed(
      "png-transform-sprite",
      Bytes::from_array([137, 80]),
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
test "RenderPipeline PNG bytes transformed quality replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let canvas = @graphics.Canvas::new(7, 1)
  canvas.set_transform(@graphics.Transform::translate(tx=1.0, ty=0.0))
  let renderer = Renderer::new(canvas)
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-quality",
      must_renderer_test_png_bytes(sprite),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-transform-quality-sprite",
      must_renderer_test_png_bytes(sprite),
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
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
  assert_true(images[0].get_resource_key() == Some("png-transform-quality"))
  assert_eq(images[0].get_command_index(), 1)
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(
    images[1].get_resource_key() == Some("png-transform-quality-sprite"),
  )
  assert_eq(images[1].get_command_index(), 2)
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
  assert_eq(first.get_image_cache_insert_count(), 2)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("png-transform-quality"))
  assert_true(resources.contains_image("png-transform-quality-sprite"))
  assert_eq(resources.get_image_cache().len(), 2)
  let first_snapshot = resources.snapshot()
  assert_eq(first_snapshot.get_image_count(), 2)
  assert_eq(first_snapshot.get_image_capacity(), 4)
  assert_true(first_snapshot.is_image_capacity_bounded())
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

  let second_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-quality",
      Bytes::from_array([137, 80]),
      2.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-transform-quality-sprite",
      Bytes::from_array([137, 80]),
      src_right,
      4.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
  let second = must_draw_pipeline_with_renderer_resources(
    renderer, second_pipeline, resources,
  )
  assert_eq(second.get_command_count(), 3)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_keyed_image_count(), 2)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(resources.get_image_cache().len(), 2)
  let second_snapshot = resources.snapshot()
  assert_eq(second_snapshot.get_image_count(), 2)
  assert_eq(second_snapshot.get_image_capacity(), 4)
  assert_true(second_snapshot.is_image_capacity_bounded())
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

  let retained = RenderPipeline::diff(
    RenderPipeline::new()
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-quality",
      must_renderer_test_png_bytes(sprite),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-transform-quality-sprite",
      must_renderer_test_png_bytes(sprite),
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ),
    RenderPipeline::new()
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-quality",
      Bytes::from_array([137, 80]),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-transform-quality-sprite",
      Bytes::from_array([137, 80]),
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    ),
    7,
    1,
  )
  assert_eq(retained.get_retained_command_count(), 2)
  assert_eq(retained.get_changed_command_count(), 0)
  assert_true(!retained.has_dirty())
}

///|
test "RenderPipeline PNG bytes quality replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 4)
  let renderer = Renderer::new(@graphics.Canvas::new(7, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_quality_png_bytes_keyed(
      "png-quality",
      must_renderer_test_png_bytes(sprite),
      0,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_png_bytes_rect_keyed(
      "png-quality-sprite",
      must_renderer_test_png_bytes(sprite),
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
  assert_true(images[0].get_resource_key() == Some("png-quality"))
  assert_eq(images[0].get_source_width(), 2)
  assert_eq(images[0].get_source_height(), 1)
  assert_true(images[1].get_resource_key() == Some("png-quality-sprite"))
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
  assert_true(resources.contains_image("png-quality"))
  assert_true(resources.contains_image("png-quality-sprite"))
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
    .draw_quality_png_bytes_keyed(
      "png-quality",
      Bytes::from_array([137, 80]),
      1,
      0,
      4,
      1,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_quality_png_bytes_rect_keyed(
      "png-quality-sprite",
      Bytes::from_array([137, 80]),
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
