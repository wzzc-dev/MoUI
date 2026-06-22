///|
test "RenderPipeline replays transformed quality BMP and RGBA byte commands" {
  let source = @graphics.Pixmap::new(2, 1)
  source.set_pixel(0, 0, @graphics.Color::red())
  source.set_pixel(1, 0, @graphics.Color::green())
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-transform-quality",
      source.to_bmp_bytes(),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-transform-quality",
      source.to_rgba_bytes(),
      2,
      1,
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-transform-quality-sprite",
      source.to_bmp_bytes(),
      src_right,
      6.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba-transform-quality-full",
      source.to_rgba_bytes(),
      2,
      1,
      9.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )

  let batches = pipeline.batch_plan(11, 1).get_batches()
  assert_eq(batches.length(), 2)
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[1].get_command_count(), 4)
  assert_eq(batches[1].get_dirty_rect_count(), 4)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=11, height=1)),
  )
  let image_present_plan = batches[1].get_present_plan(11, 1, 4)
  assert_eq(image_present_plan.get_rect_count(), 4)
  assert_eq(image_present_plan.get_present_pixel_count(), 8)

  let renderer = Renderer::new(@graphics.Canvas::new(11, 1))
  let result = must_draw_pipeline(renderer, pipeline)
  assert_eq(result.get_command_count(), 5)
  assert_eq(result.get_clear_count(), 1)
  assert_eq(result.get_image_count(), 4)
  assert_eq(result.get_text_count(), 0)
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(4, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(5, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(6, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(7, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(8, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(9, 0), @graphics.Color::red())
  assert_eq(pixmap.get_pixel(10, 0), @graphics.Color::green())
}

///|
test "RenderPipeline replays transformed quality PNG byte commands" {
  let source = @graphics.Pixmap::new(2, 1)
  source.set_pixel(0, 0, @graphics.Color::red())
  source.set_pixel(1, 0, @graphics.Color::green())
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-quality",
      must_renderer_test_png_bytes(source),
      0.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-transform-quality-sprite",
      must_renderer_test_png_bytes(source),
      src_right,
      3.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )

  let batches = pipeline.batch_plan(6, 1).get_batches()
  assert_eq(batches.length(), 2)
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[1].get_command_count(), 2)
  assert_eq(batches[1].get_dirty_rect_count(), 2)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=1)),
  )
  let image_present_plan = batches[1].get_present_plan(6, 1, 4)
  assert_eq(image_present_plan.get_rect_count(), 2)
  assert_eq(image_present_plan.get_present_pixel_count(), 4)

  let renderer = Renderer::new(@graphics.Canvas::new(6, 1))
  let result = must_draw_pipeline(renderer, pipeline)
  assert_eq(result.get_command_count(), 3)
  assert_eq(result.get_clear_count(), 1)
  assert_eq(result.get_image_count(), 2)
  assert_eq(result.get_text_count(), 0)
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(2, 0), @graphics.Color::white())
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(4, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(5, 0), @graphics.Color::white())
}
