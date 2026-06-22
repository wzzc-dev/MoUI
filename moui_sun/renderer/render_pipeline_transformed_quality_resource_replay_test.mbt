///|
test "RenderPipeline BMP and RGBA transformed quality replay uses RendererResources image cache" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let resources = RendererResources::with_capacities(16, 16, 2, 8, 8)
  let renderer = Renderer::new(@graphics.Canvas::new(10, 1))
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-transform-quality",
      sprite.to_bmp_bytes(),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-transform-quality-sprite",
      sprite.to_bmp_bytes(),
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba-transform-quality",
      sprite.to_rgba_bytes(),
      2,
      1,
      5.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-transform-quality-sprite",
      sprite.to_rgba_bytes(),
      2,
      1,
      src_right,
      8.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 5)
  assert_eq(plan.get_image_count(), 4)
  assert_eq(plan.get_keyed_image_count(), 4)
  assert_eq(plan.get_resource_count(), 4)
  assert_eq(plan.get_keyed_resource_count(), 4)
  assert_eq(plan.get_image_source_pixel_count(), 6)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-transform-quality"))
  assert_eq(images[0].get_command_index(), 1)
  assert_eq(images[0].get_source_pixel_count(), 2)
  assert_true(
    images[1].get_resource_key() == Some("bmp-transform-quality-sprite"),
  )
  assert_eq(images[1].get_command_index(), 2)
  assert_eq(images[1].get_source_pixel_count(), 1)
  assert_true(images[2].get_resource_key() == Some("rgba-transform-quality"))
  assert_eq(images[2].get_command_index(), 3)
  assert_eq(images[2].get_source_pixel_count(), 2)
  assert_true(
    images[3].get_resource_key() == Some("rgba-transform-quality-sprite"),
  )
  assert_eq(images[3].get_command_index(), 4)
  assert_eq(images[3].get_source_pixel_count(), 1)
  let batches = first_pipeline.batch_plan(10, 1).get_batches()
  assert_eq(batches.length(), 2)
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[1].get_dirty_rect_count(), 3)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=10, height=1)),
  )
  let image_rect_present = batches[1].get_present_plan(10, 1, 4)
  assert_true(!image_rect_present.uses_bounds_fallback())
  assert_eq(image_rect_present.get_rect_count(), 3)
  assert_eq(image_rect_present.get_present_pixel_count(), 8)
  let image_bounds_present = batches[1].get_present_plan(10, 1, 2)
  assert_true(image_bounds_present.uses_bounds_fallback())
  assert_eq(image_bounds_present.get_rect_count(), 1)
  assert_true(
    image_bounds_present.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=10, height=1)),
  )
  assert_eq(image_bounds_present.get_present_pixel_count(), 10)

  let first = must_draw_pipeline_with_renderer_resources(
    renderer, first_pipeline, resources,
  )
  assert_eq(first.get_command_count(), 5)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 4)
  assert_eq(first.get_keyed_image_count(), 4)
  assert_eq(first.get_keyed_resource_count(), 4)
  assert_eq(first.get_image_cache_insert_count(), 4)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 4)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-transform-quality"))
  assert_true(resources.contains_image("bmp-transform-quality-sprite"))
  assert_true(resources.contains_image("rgba-transform-quality"))
  assert_true(resources.contains_image("rgba-transform-quality-sprite"))
  assert_eq(resources.get_image_cache().len(), 4)
  let first_snapshot = resources.snapshot()
  assert_eq(first_snapshot.get_image_count(), 4)
  assert_eq(first_snapshot.get_image_capacity(), 8)
  assert_true(first_snapshot.is_image_capacity_bounded())
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
    @graphics.Color::white(),
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
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(7, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(8, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(9, 0),
    @graphics.Color::green(),
  )

  let second_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-transform-quality",
      b"not a bmp",
      1.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-transform-quality-sprite",
      b"not a bmp",
      src_right,
      4.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba-transform-quality",
      b"not rgba",
      2,
      1,
      6.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-transform-quality-sprite",
      b"not rgba",
      2,
      1,
      src_right,
      8.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
  let second = must_draw_pipeline_with_renderer_resources(
    renderer, second_pipeline, resources,
  )
  assert_eq(second.get_command_count(), 5)
  assert_eq(second.get_image_count(), 4)
  assert_eq(second.get_keyed_image_count(), 4)
  assert_eq(second.get_keyed_resource_count(), 4)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 4)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 4)
  assert_eq(resources.get_image_cache().len(), 4)
  let second_snapshot = resources.snapshot()
  assert_eq(second_snapshot.get_image_count(), 4)
  assert_eq(second_snapshot.get_image_capacity(), 8)
  assert_true(second_snapshot.is_image_capacity_bounded())
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
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
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
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(8, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(9, 0),
    @graphics.Color::green(),
  )
}
