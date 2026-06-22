///|
test "RenderPipeline replays byte image commands and analyzes dirty bounds" {
  let source = @graphics.Pixmap::new(2, 2)
  source.set_pixel(0, 0, @graphics.Color::red())
  source.set_pixel(1, 0, @graphics.Color::green())
  source.set_pixel(0, 1, @graphics.Color::blue())
  source.set_pixel(1, 1, @graphics.Color::black())
  let paint = @graphics.Paint::new()
  let pipeline = RenderPipeline::new()
    .draw_bmp_bytes_keyed("bmp", source.to_bmp_bytes(), 0, 0, paint)
    .draw_png_bytes_rect_keyed(
      "png-sprite",
      must_renderer_test_png_bytes(source),
      @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      3,
      0,
      paint,
    )
    .draw_rgba_bytes_rect_keyed(
      "rgba-sprite",
      source.to_rgba_bytes(),
      2,
      2,
      @graphics.PixelRect::new(x=0, y=1, width=1, height=1),
      4,
      1,
      paint,
    )

  let analysis = pipeline.analyze(5, 3)
  assert_eq(analysis.get_command_count(), 3)
  assert_eq(analysis.get_image_count(), 3)
  assert_eq(analysis.get_dirty_rect_count(), 3)
  assert_true(
    analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=2)),
  )

  let renderer = Renderer::new(@graphics.Canvas::new(5, 3))
  let result = must_draw_pipeline(renderer, pipeline)
  assert_eq(result.get_image_count(), 3)
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::red())
  assert_eq(pixmap.get_pixel(1, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(0, 1), @graphics.Color::blue())
  assert_eq(pixmap.get_pixel(3, 0), @graphics.Color::green())
  assert_eq(pixmap.get_pixel(4, 1), @graphics.Color::blue())
}

///|
test "RenderPipeline conservatively estimates dirty bounds for placeholder image bytes" {
  let paint = @graphics.Paint::new()
  let src = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let empty_src = @graphics.PixelRect::new(x=0, y=0, width=0, height=1)
  let insets = @graphics.NinePatchInsets::new(left=1, top=0, right=1, bottom=0)
  let pipeline = RenderPipeline::new()
    .draw_rgba_bytes_keyed("rgba", Bytes::from_array([0]), 2, 1, 0, 0, paint)
    .draw_png_bytes_rect_keyed(
      "png-sprite",
      Bytes::from_array([137, 80]),
      src,
      3,
      0,
      paint,
    )
    .draw_sampled_bmp_bytes_keyed(
      "bmp-sampled",
      Bytes::from_array([66, 77]),
      0,
      1,
      2,
      1,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_quality_png_bytes_rect_keyed(
      "png-quality-sprite",
      Bytes::from_array([137, 80]),
      src,
      2,
      1,
      2,
      1,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-transform-quality",
      b"not a bmp",
      4.0,
      1.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_sampled_rgba_bytes_rect_keyed(
      "rgba-transform-sprite",
      b"not rgba",
      2,
      1,
      src,
      6.0,
      1.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_tiled_bmp_bytes_rect_keyed(
      "bmp-tile",
      Bytes::from_array([66, 77]),
      src,
      0,
      2,
      3,
      1,
      paint,
    )
    .draw_nine_patch_png_bytes_keyed(
      "png-panel",
      Bytes::from_array([137, 80]),
      3,
      2,
      2,
      1,
      insets,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_sampled_rgba_bytes_rect_keyed(
      "empty-source",
      Bytes::from_array([]),
      2,
      1,
      empty_src,
      5,
      2,
      2,
      1,
      paint,
      @graphics.ImageSampling::Nearest,
    )

  let analysis = pipeline.analyze(8, 3)
  assert_eq(analysis.get_command_count(), 9)
  assert_eq(analysis.get_image_count(), 9)
  assert_true(analysis.has_dirty())
  assert_true(
    analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=8, height=3)),
  )
  let present_plan = pipeline.dirty_present_plan(8, 3, 1)
  assert_true(!present_plan.uses_bounds_fallback())
  assert_eq(present_plan.get_rect_count(), 1)
  assert_eq(present_plan.get_present_pixel_count(), 24)
  let batches = pipeline.batch_plan(8, 3).get_batches()
  assert_eq(batches.length(), 1)
  assert_true(batches[0].get_kind() == RenderPipelineBatchKind::Image)
  assert_true(
    batches[0].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=8, height=3)),
  )

  let empty_source = RenderPipeline::new()
    .draw_sampled_png_bytes_rect_keyed(
      "empty",
      Bytes::from_array([137, 80]),
      empty_src,
      0,
      0,
      2,
      1,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .analyze(4, 1)
  assert_true(!empty_source.has_dirty())

  let unknown_full_images = RenderPipeline::new()
    .draw_bmp_bytes_keyed("bmp-full", Bytes::from_array([66, 77]), 2, 1, paint)
    .draw_png_bytes_keyed("png-full", Bytes::from_array([137, 80]), 1, 2, paint)
  let unknown_analysis = unknown_full_images.analyze(5, 4)
  assert_true(unknown_analysis.has_dirty())
  assert_eq(unknown_analysis.get_dirty_rect_count(), 1)
  assert_true(
    unknown_analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=5, height=4)),
  )
  let unknown_present = unknown_full_images.dirty_present_plan(5, 4, 4)
  assert_eq(unknown_present.get_rect_count(), 1)
  assert_eq(unknown_present.get_present_pixel_count(), 20)
}

///|
test "RenderPipeline transformed quality byte commands skip empty dirty targets" {
  let paint = @graphics.Paint::new()
  let empty_src = @graphics.PixelRect::new(x=0, y=0, width=0, height=1)
  let pipeline = RenderPipeline::new()
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-zero-width",
      Bytes::from_array([66, 77]),
      0.0,
      0.0,
      0.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_keyed(
      "png-zero-height",
      Bytes::from_array([137, 80]),
      1.0,
      0.0,
      2.0,
      0.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-empty-source",
      Bytes::from_array([66, 77]),
      empty_src,
      0.0,
      1.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-empty-source",
      Bytes::from_array([137, 80]),
      empty_src,
      1.0,
      1.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba-zero-width",
      Bytes::from_array([]),
      2,
      1,
      3.0,
      0.0,
      0.0,
      2.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-empty-source",
      Bytes::from_array([]),
      2,
      1,
      empty_src,
      2.0,
      1.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )

  let analysis = pipeline.analyze(4, 3)
  assert_eq(analysis.get_command_count(), 6)
  assert_eq(analysis.get_image_count(), 6)
  assert_true(!analysis.has_dirty())
  assert_eq(analysis.get_dirty_rect_count(), 0)
  assert_true(analysis.get_dirty_bounds() == None)
  let present = analysis.get_present_plan(4, 3, 4)
  assert_eq(present.get_rect_count(), 0)
  assert_eq(present.get_present_pixel_count(), 0)

  let batch_plan = pipeline.batch_plan(4, 3)
  assert_eq(batch_plan.get_command_count(), 6)
  assert_eq(batch_plan.get_batch_count(), 1)
  assert_true(!batch_plan.has_dirty())
  let batches = batch_plan.get_batches()
  assert_true(batches[0].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[0].get_command_count(), 6)
  assert_eq(batches[0].get_dirty_rect_count(), 0)
  assert_true(batches[0].get_dirty_bounds() == None)

  let resource_plan = pipeline.resource_plan()
  assert_eq(resource_plan.get_command_count(), 6)
  assert_eq(resource_plan.get_image_count(), 6)
  assert_eq(resource_plan.get_keyed_image_count(), 6)
  assert_eq(resource_plan.get_image_source_pixel_count(), 2)
  let images = resource_plan.get_image_dependencies()
  assert_true(images[4].get_resource_key() == Some("rgba-zero-width"))
  assert_eq(images[4].get_source_width(), 2)
  assert_eq(images[4].get_source_height(), 1)
}

///|
test "RenderPipeline transformed quality byte commands use fractional dirty bounds" {
  let source = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let paint = @graphics.Paint::new()
  let pipeline = RenderPipeline::new()
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-fractional",
      source.to_bmp_bytes(),
      1.25,
      0.5,
      1.25,
      1.25,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-rect-fractional",
      must_renderer_test_png_bytes(source),
      src_right,
      5.25,
      2.25,
      1.5,
      1.5,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-rect-fractional",
      source.to_rgba_bytes(),
      2,
      1,
      src_right,
      8.1,
      0.1,
      0.6,
      0.6,
      paint,
      @graphics.ImageQuality::Fast,
    )

  let analysis = pipeline.analyze(10, 5)
  assert_eq(analysis.get_command_count(), 3)
  assert_eq(analysis.get_image_count(), 3)
  assert_eq(analysis.get_dirty_rect_count(), 3)
  assert_true(
    analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=8, height=4)),
  )
  let dirty_rects = analysis.get_dirty_region().get_rects()
  assert_true(
    dirty_rects[0] == @graphics.PixelRect::new(x=1, y=0, width=2, height=2),
  )
  assert_true(
    dirty_rects[1] == @graphics.PixelRect::new(x=5, y=2, width=2, height=2),
  )
  assert_true(
    dirty_rects[2] == @graphics.PixelRect::new(x=8, y=0, width=1, height=1),
  )
  let rect_present = analysis.get_present_plan(10, 5, 3)
  assert_true(!rect_present.uses_bounds_fallback())
  assert_eq(rect_present.get_rect_count(), 3)
  let present_rects = rect_present.get_rects()
  assert_true(present_rects[0] == dirty_rects[0])
  assert_true(present_rects[1] == dirty_rects[1])
  assert_true(present_rects[2] == dirty_rects[2])
  assert_eq(rect_present.get_present_pixel_count(), 9)
  let bounds_present = analysis.get_present_plan(10, 5, 2)
  assert_true(bounds_present.uses_bounds_fallback())
  assert_eq(bounds_present.get_rect_count(), 1)
  assert_true(
    bounds_present.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=8, height=4)),
  )
  assert_eq(bounds_present.get_present_pixel_count(), 32)

  let batches = pipeline.batch_plan(10, 5).get_batches()
  assert_eq(batches.length(), 1)
  assert_true(batches[0].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[0].get_dirty_rect_count(), 3)
  assert_true(
    batches[0].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=8, height=4)),
  )
}
