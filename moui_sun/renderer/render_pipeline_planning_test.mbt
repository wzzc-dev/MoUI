///|
test "RenderPipeline batch plan groups contiguous command categories" {
  let icon = @graphics.Pixmap::new(2, 2)
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=12.0,
    font_size=10.0,
    line_height=10.0,
  )
  let fill_paint = @graphics.Paint::new().set_color(@graphics.Color::red())
  let stroke_paint = @graphics.Paint::new()
    .set_style(@graphics.PaintStyle::Stroke)
    .set_stroke_width(2.0)
  let path = @graphics.Path::new().move_to(0.0, 4.0).line_to(4.0, 4.0)
  let plan = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .fill_rect(1.0, 1.0, 2.0, 2.0, fill_paint)
    .fill_path(@graphics.Path::new().add_rect(3.0, 1.0, 1.0, 2.0), fill_paint)
    .stroke_path(path, stroke_paint)
    .draw_pixmap(icon, 6, 0, @graphics.Paint::new())
    .draw_pixmap_rect(
      icon,
      @graphics.PixelRect::new(x=0, y=0, width=1, height=1),
      6,
      1,
      @graphics.Paint::new(),
    )
    .draw_text_face(
      face,
      "A",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    )
    .batch_plan(8, 6)

  assert_eq(plan.get_command_count(), 7)
  assert_eq(plan.get_batch_count(), 5)
  assert_true(plan.has_dirty())
  assert_true(
    plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=8, height=6)),
  )
  let batches = plan.get_batches()
  assert_true(batches[0].get_kind() == RenderPipelineBatchKind::Clear)
  assert_eq(batches[0].get_start_index(), 0)
  assert_eq(batches[0].get_command_count(), 1)
  assert_true(
    batches[0].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=8, height=6)),
  )
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Fill)
  assert_eq(batches[1].get_start_index(), 1)
  assert_eq(batches[1].get_command_count(), 2)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=3, height=2)),
  )
  assert_true(batches[2].get_kind() == RenderPipelineBatchKind::Stroke)
  assert_eq(batches[2].get_start_index(), 3)
  assert_eq(batches[2].get_command_count(), 1)
  assert_true(
    batches[2].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=3, width=5, height=2)),
  )
  assert_true(batches[3].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[3].get_start_index(), 4)
  assert_eq(batches[3].get_command_count(), 2)
  assert_true(
    batches[3].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=6, y=0, width=2, height=2)),
  )
  assert_true(batches[4].get_kind() == RenderPipelineBatchKind::Text)
  assert_eq(batches[4].get_start_index(), 6)
  assert_eq(batches[4].get_command_count(), 1)
  assert_true(batches[4].has_dirty())
}

///|
test "Renderer batch plan uses canvas bounds for present planning" {
  let empty = RenderPipeline::new().batch_plan(5, 3)
  assert_eq(empty.get_command_count(), 0)
  assert_eq(empty.get_batch_count(), 0)
  assert_true(!empty.has_dirty())
  assert_true(empty.get_dirty_bounds() == None)

  let icon = @graphics.Pixmap::new(4, 1)
  let renderer = Renderer::new(@graphics.Canvas::new(5, 3))
  let plan = renderer.plan_pipeline_batches(
    RenderPipeline::new().draw_pixmap(icon, 3, 1, @graphics.Paint::new()),
  )
  assert_eq(plan.get_batch_count(), 1)
  assert_true(
    plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=3, y=1, width=2, height=1)),
  )
  let present_plan = plan.get_present_plan(5, 3, 4)
  assert_eq(present_plan.get_rect_count(), 1)
  assert_eq(present_plan.get_present_pixel_count(), 2)
}

///|
test "RenderPipeline planning dirty snapshots are isolated" {
  let fill_paint = @graphics.Paint::new().set_color(@graphics.Color::red())
  let stroke_paint = @graphics.Paint::new()
    .set_style(@graphics.PaintStyle::Stroke)
    .set_stroke_width(1.0)
  let pipeline = RenderPipeline::new()
    .fill_rect(1.0, 1.0, 1.0, 1.0, fill_paint)
    .stroke_rect(3.0, 1.0, 1.0, 1.0, stroke_paint)

  let analysis = pipeline.analyze(6, 4)
  let analysis_region = analysis.get_dirty_region()
  analysis_region.clear()
  analysis_region.add_rect(
    @graphics.PixelRect::new(x=20, y=20, width=1, height=1),
  )
  assert_true(analysis.has_dirty())
  assert_true(
    analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=4, height=3)),
  )

  let diff = RenderPipeline::diff(RenderPipeline::new(), pipeline, 6, 4)
  let diff_region = diff.get_dirty_region()
  diff_region.clear()
  assert_true(diff.has_dirty())
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=4, height=3)),
  )

  let plan = pipeline.batch_plan(6, 4)
  let plan_region = plan.get_dirty_region()
  plan_region.clear()
  assert_true(plan.has_dirty())
  assert_true(
    plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=4, height=3)),
  )

  let batches = plan.get_batches()
  assert_eq(batches.length(), 2)
  batches[0] = batches[1]
  batches.push(batches[1])
  assert_eq(plan.get_batch_count(), 2)

  let batch = plan.get_batches()[0]
  let batch_region = batch.get_dirty_region()
  batch_region.clear()
  assert_true(batch.has_dirty())

  let fresh = plan.get_batches()
  assert_eq(fresh.length(), 2)
  assert_true(fresh[0].get_kind() == RenderPipelineBatchKind::Fill)
  assert_true(fresh[0].has_dirty())
  assert_true(fresh[1].get_kind() == RenderPipelineBatchKind::Stroke)
}

///|
test "RenderPipeline resource plan pre-resolves image and text dependencies" {
  let icon = @graphics.Pixmap::new(4, 3)
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let plan = RenderPipeline::new()
    .fill_rect(0.0, 0.0, 1.0, 1.0, @graphics.Paint::new())
    .draw_pixmap(icon, 0, 0, @graphics.Paint::new())
    .draw_pixmap_rect(
      icon,
      @graphics.PixelRect::new(x=2, y=1, width=4, height=3),
      0,
      0,
      @graphics.Paint::new(),
    )
    .draw_text_face(
      face,
      "AA",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    )
    .resource_plan()

  assert_eq(plan.get_command_count(), 4)
  assert_true(plan.has_resources())
  assert_eq(plan.get_resource_count(), 3)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_image_source_pixel_count(), 16)
  assert_eq(plan.get_text_byte_count(), 2)
  assert_eq(plan.get_text_run_count(), 1)
  assert_eq(plan.get_text_glyph_count(), 2)

  let images = plan.get_image_dependencies()
  assert_eq(images[0].get_command_index(), 1)
  assert_true(!images[0].has_resource_key())
  assert_true(images[0].get_resource_key() == None)
  assert_eq(images[0].get_source_width(), 4)
  assert_eq(images[0].get_source_height(), 3)
  assert_eq(images[0].get_source_pixel_count(), 12)
  assert_eq(images[1].get_command_index(), 2)
  assert_true(!images[1].has_resource_key())
  assert_eq(images[1].get_source_width(), 2)
  assert_eq(images[1].get_source_height(), 2)
  assert_eq(images[1].get_source_pixel_count(), 4)

  let texts = plan.get_text_dependencies()
  assert_eq(texts[0].get_command_index(), 3)
  assert_true(!texts[0].has_resource_key())
  assert_eq(texts[0].get_text_byte_count(), 2)
  assert_eq(texts[0].get_run_count(), 1)
  assert_eq(texts[0].get_glyph_count(), 2)
  assert_eq(texts[0].get_layout_width(), 20.0)
  assert_true(texts[0].get_layout_height() > 0.0)
}

///|
test "Renderer resource plan reports empty and clipped-away dependencies" {
  let renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let empty = renderer.plan_pipeline_resources(RenderPipeline::new())
  assert_eq(empty.get_command_count(), 0)
  assert_eq(empty.get_resource_count(), 0)
  assert_true(!empty.has_resources())

  let icon = @graphics.Pixmap::new(2, 2)
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let plan = renderer.plan_pipeline_resources(
    RenderPipeline::new()
    .draw_pixmap_rect(
      icon,
      @graphics.PixelRect::new(x=4, y=4, width=2, height=2),
      0,
      0,
      @graphics.Paint::new(),
    )
    .draw_text_face(
      face,
      "",
      0.0,
      0.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
  )

  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_image_count(), 1)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_image_source_pixel_count(), 0)
  assert_eq(plan.get_text_byte_count(), 0)
  assert_eq(plan.get_text_run_count(), 0)
  assert_eq(plan.get_text_glyph_count(), 0)
  let images = plan.get_image_dependencies()
  assert_eq(images[0].get_source_width(), 0)
  assert_eq(images[0].get_source_height(), 0)
  let texts = plan.get_text_dependencies()
  assert_eq(texts[0].get_layout_width(), 0.0)
  assert_eq(texts[0].get_layout_height(), 0.0)
}

///|
test "RenderPipeline resource dependency snapshots are isolated" {
  let icon = @graphics.Pixmap::new(2, 1)
  let font_data = make_minimal_ttf()
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new()
  let plan = RenderPipeline::new()
    .draw_pixmap_keyed("image-a", icon, 0, 0, paint)
    .draw_pixmap_keyed("image-b", icon, 1, 0, paint)
    .draw_font_bytes_keyed(
      "font-a", font_data, "text-a", "A", 0.0, 0.0, config, paint,
    )
    .draw_font_bytes_atlas_keyed(
      "font-b", font_data, "glyph-b", "B", 0.0, 0.0, config, paint,
    )
    .resource_plan()

  assert_eq(plan.get_font_count(), 2)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_text_count(), 2)

  let fonts = plan.get_font_dependencies()
  let images = plan.get_image_dependencies()
  let texts = plan.get_text_dependencies()
  fonts[0] = fonts[1]
  fonts.push(fonts[1])
  images[0] = images[1]
  images.push(images[1])
  texts[0] = texts[1]
  texts.push(texts[1])

  assert_eq(plan.get_font_count(), 2)
  assert_eq(plan.get_image_count(), 2)
  assert_eq(plan.get_text_count(), 2)
  let fresh_fonts = plan.get_font_dependencies()
  let fresh_images = plan.get_image_dependencies()
  let fresh_texts = plan.get_text_dependencies()
  assert_eq(fresh_fonts.length(), 2)
  assert_eq(fresh_images.length(), 2)
  assert_eq(fresh_texts.length(), 2)
  assert_eq(fresh_fonts[0].get_font_key(), "font-a")
  assert_eq(fresh_fonts[1].get_font_key(), "font-b")
  assert_true(fresh_images[0].get_resource_key() == Some("image-a"))
  assert_true(fresh_images[1].get_resource_key() == Some("image-b"))
  assert_true(fresh_texts[0].get_resource_key() == Some("text-a"))
  assert_true(fresh_texts[1].get_resource_key() == Some("glyph-b"))
}

///|
test "RenderPipeline resource plan uses declared image sizes for placeholder bytes" {
  let paint = @graphics.Paint::new()
  let clipped_src = @graphics.PixelRect::new(x=2, y=1, width=5, height=4)
  let requested_src = @graphics.PixelRect::new(x=1, y=0, width=2, height=1)
  let tall_requested_src = @graphics.PixelRect::new(x=0, y=0, width=1, height=2)
  let transformed_src = @graphics.PixelRect::new(x=1, y=0, width=3, height=1)
  let transformed_png_src = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=2,
    height=1,
  )
  let transformed_rgba_src = @graphics.PixelRect::new(
    x=2,
    y=1,
    width=3,
    height=3,
  )
  let tile_src = @graphics.PixelRect::new(x=2, y=2, width=3, height=2)
  let tall_tile_src = @graphics.PixelRect::new(x=0, y=1, width=1, height=3)
  let plan = RenderPipeline::new()
    .draw_rgba_bytes_keyed(
      "rgba-full",
      Bytes::from_array([0]),
      3,
      2,
      0,
      0,
      paint,
    )
    .draw_rgba_bytes_rect_keyed(
      "rgba-rect",
      Bytes::from_array([]),
      4,
      3,
      clipped_src,
      0,
      0,
      paint,
    )
    .draw_sampled_bmp_bytes_rect_keyed(
      "bmp-rect",
      Bytes::from_array([66, 77]),
      requested_src,
      0,
      0,
      2,
      1,
      paint,
      @graphics.ImageSampling::Nearest,
    )
    .draw_quality_png_bytes_rect_keyed(
      "png-rect",
      Bytes::from_array([137, 80]),
      tall_requested_src,
      0,
      0,
      1,
      2,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_tiled_bmp_bytes_rect_keyed(
      "bmp-tile",
      Bytes::from_array([66, 77]),
      tile_src,
      0,
      0,
      3,
      2,
      paint,
    )
    .draw_tiled_png_bytes_rect_keyed(
      "png-tile",
      Bytes::from_array([137, 80]),
      tall_tile_src,
      0,
      0,
      1,
      3,
      paint,
    )
    .draw_bmp_bytes_keyed("bmp-full", Bytes::from_array([66, 77]), 0, 0, paint)
    .draw_png_bytes_keyed("png-full", Bytes::from_array([137, 80]), 0, 0, paint)
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-full",
      Bytes::from_array([137, 80]),
      0.0,
      0.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_png_bytes_rect_keyed(
      "png-transform-rect",
      Bytes::from_array([137, 80]),
      transformed_png_src,
      0.0,
      0.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_keyed(
      "bmp-transform-full",
      Bytes::from_array([66, 77]),
      0.0,
      0.0,
      2.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_bmp_bytes_rect_keyed(
      "bmp-transform-rect",
      Bytes::from_array([66, 77]),
      transformed_src,
      0.0,
      0.0,
      3.0,
      1.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_keyed(
      "rgba-transform-full",
      Bytes::from_array([]),
      4,
      3,
      0.0,
      0.0,
      4.0,
      3.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .draw_transformed_quality_rgba_bytes_rect_keyed(
      "rgba-transform-rect",
      Bytes::from_array([]),
      4,
      3,
      transformed_rgba_src,
      0.0,
      0.0,
      3.0,
      3.0,
      paint,
      @graphics.ImageQuality::Fast,
    )
    .resource_plan()

  assert_eq(plan.get_command_count(), 14)
  assert_eq(plan.get_image_count(), 14)
  assert_eq(plan.get_keyed_image_count(), 14)
  assert_eq(plan.get_image_source_pixel_count(), 44)
  let images = plan.get_image_dependencies()
  assert_eq(images.length(), 14)
  for index in 0..<images.length() {
    assert_eq(images[index].get_command_index(), index)
  }
  assert_true(images[0].get_resource_key() == Some("rgba-full"))
  assert_eq(images[0].get_source_width(), 3)
  assert_eq(images[0].get_source_height(), 2)
  assert_true(images[1].get_resource_key() == Some("rgba-rect"))
  assert_eq(images[1].get_source_width(), 2)
  assert_eq(images[1].get_source_height(), 2)
  assert_true(images[2].get_resource_key() == Some("bmp-rect"))
  assert_eq(images[2].get_source_pixel_count(), 2)
  assert_true(images[3].get_resource_key() == Some("png-rect"))
  assert_eq(images[3].get_source_pixel_count(), 2)
  assert_true(images[4].get_resource_key() == Some("bmp-tile"))
  assert_eq(images[4].get_source_width(), 3)
  assert_eq(images[4].get_source_height(), 2)
  assert_true(images[5].get_resource_key() == Some("png-tile"))
  assert_eq(images[5].get_source_width(), 1)
  assert_eq(images[5].get_source_height(), 3)
  assert_true(images[6].get_resource_key() == Some("bmp-full"))
  assert_eq(images[6].get_source_pixel_count(), 0)
  assert_true(images[7].get_resource_key() == Some("png-full"))
  assert_eq(images[7].get_source_pixel_count(), 0)
  assert_true(images[8].get_resource_key() == Some("png-transform-full"))
  assert_eq(images[8].get_source_pixel_count(), 0)
  assert_true(images[9].get_resource_key() == Some("png-transform-rect"))
  assert_eq(images[9].get_source_width(), 2)
  assert_eq(images[9].get_source_height(), 1)
  assert_true(images[10].get_resource_key() == Some("bmp-transform-full"))
  assert_eq(images[10].get_source_pixel_count(), 0)
  assert_true(images[11].get_resource_key() == Some("bmp-transform-rect"))
  assert_eq(images[11].get_source_width(), 3)
  assert_eq(images[11].get_source_height(), 1)
  assert_true(images[12].get_resource_key() == Some("rgba-transform-full"))
  assert_eq(images[12].get_source_width(), 4)
  assert_eq(images[12].get_source_height(), 3)
  assert_true(images[13].get_resource_key() == Some("rgba-transform-rect"))
  assert_eq(images[13].get_source_width(), 2)
  assert_eq(images[13].get_source_height(), 2)
}

///|
test "RenderPipeline keyed resources expose identity and replay normally" {
  let icon = @graphics.Pixmap::new(3, 2)
  icon.set_pixel(0, 0, @graphics.Color::red())
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let pipeline = RenderPipeline::new()
    .draw_pixmap_keyed("hero", icon, 0, 0, @graphics.Paint::new())
    .draw_pixmap_rect_keyed(
      "sprite",
      icon,
      @graphics.PixelRect::new(x=1, y=0, width=4, height=2),
      3,
      0,
      @graphics.Paint::new(),
    )
    .draw_text_face_keyed(
      "ui-font",
      face,
      "A",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    )
  let plan = pipeline.resource_plan()
  assert_eq(plan.get_resource_count(), 3)
  assert_eq(plan.get_keyed_resource_count(), 3)
  assert_eq(plan.get_keyed_image_count(), 2)
  assert_eq(plan.get_keyed_text_count(), 1)
  let images = plan.get_image_dependencies()
  assert_true(images[0].has_resource_key())
  assert_true(images[0].get_resource_key() == Some("hero"))
  assert_eq(images[0].get_source_pixel_count(), 6)
  assert_true(images[1].get_resource_key() == Some("sprite"))
  assert_eq(images[1].get_source_width(), 2)
  assert_eq(images[1].get_source_height(), 2)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("ui-font"))
  assert_eq(texts[0].get_glyph_count(), 1)

  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  renderer.get_canvas().clear(@graphics.Color::white())
  let result = must_draw_pipeline(renderer, pipeline)
  assert_eq(result.get_image_count(), 2)
  assert_eq(result.get_text_count(), 1)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "RenderPipeline resource replay caches keyed image and text commands" {
  let first_icon = @graphics.Pixmap::new(2, 1)
  first_icon.set_pixel(0, 0, @graphics.Color::red())
  first_icon.set_pixel(1, 0, @graphics.Color::green())
  let second_icon = @graphics.Pixmap::new(2, 1)
  second_icon.set_pixel(0, 0, @graphics.Color::blue())
  second_icon.set_pixel(1, 0, @graphics.Color::black())
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let resources = RendererResources::with_capacities(16, 16, 2, 4, 2)
  let renderer = Renderer::new(@graphics.Canvas::new(8, 12))
  let first = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_pixmap_keyed("icon", first_icon, 0, 0, @graphics.Paint::new())
    .draw_pixmap_rect_keyed(
      "icon",
      second_icon,
      @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      2,
      0,
      @graphics.Paint::new(),
    )
    .draw_text_face_keyed(
      "label",
      face,
      "A",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
    resources,
  )

  assert_eq(first.get_command_count(), 4)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 2)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_resource_count(), 3)
  assert_eq(first.get_keyed_image_count(), 2)
  assert_eq(first.get_keyed_text_count(), 1)
  assert_eq(first.get_image_cache_insert_count(), 1)
  assert_eq(first.get_image_cache_hit_count(), 1)
  assert_eq(first.get_text_mask_render_count(), 1)
  assert_eq(first.get_text_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_hit_count(), 1)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_true(resources.contains_image("icon"))
  assert_true(resources.contains_text_mask("label"))
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::green(),
  )

  let second = must_draw_pipeline_with_renderer_resources(
    renderer,
    RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_pixmap_keyed("icon", second_icon, 0, 0, @graphics.Paint::new())
    .draw_pixmap_rect_keyed(
      "icon",
      second_icon,
      @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
      2,
      0,
      @graphics.Paint::new(),
    )
    .draw_text_face_keyed(
      "label",
      face,
      "A",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
    resources,
  )

  assert_eq(second.get_command_count(), 4)
  assert_eq(second.get_image_count(), 2)
  assert_eq(second.get_text_count(), 1)
  assert_eq(second.get_keyed_resource_count(), 3)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 2)
  assert_eq(second.get_text_mask_render_count(), 0)
  assert_eq(second.get_text_cache_hit_count(), 1)
  assert_eq(second.get_resource_cache_hit_count(), 3)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_replay_result().get_command_count(), 4)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(2, 0),
    @graphics.Color::green(),
  )
}
