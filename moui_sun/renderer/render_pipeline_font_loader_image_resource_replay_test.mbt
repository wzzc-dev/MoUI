///|
test "RenderPipeline font-loader replay reuses transformed quality image resources" {
  let sprite = make_renderer_test_tile_source()
  let src_right = @graphics.PixelRect::new(x=1, y=0, width=1, height=1)
  let renderer = Renderer::new(@graphics.Canvas::new(18, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 2, 2, 2, 6)
  let loader = @text.MemoryFontLoader::new()
  ignore(loader.insert("ui-font", @text.FontData::new(make_minimal_ttf())))
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
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
    .draw_transformed_quality_png_bytes_keyed(
      "png-transform-quality",
      must_renderer_test_png_bytes(sprite),
      6.0,
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
      9.0,
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
      12.0,
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
      15.0,
      0.0,
      2.0,
      1.0,
      @graphics.Paint::new(),
      @graphics.ImageQuality::Fast,
    )
    .draw_loaded_font_keyed("ui-font", "label", "A", 1.0, 1.0, config, paint)
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 8)
  assert_eq(plan.get_image_count(), 6)
  assert_eq(plan.get_font_count(), 1)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 8)
  assert_eq(plan.get_keyed_resource_count(), 8)
  assert_eq(plan.get_image_source_pixel_count(), 9)
  assert_eq(plan.get_font_byte_count(), 0)
  assert_eq(plan.get_text_byte_count(), 1)
  let images = plan.get_image_dependencies()
  assert_true(images[0].get_resource_key() == Some("bmp-transform-quality"))
  assert_eq(images[0].get_command_index(), 1)
  assert_eq(images[0].get_source_pixel_count(), 2)
  assert_true(
    images[1].get_resource_key() == Some("bmp-transform-quality-sprite"),
  )
  assert_eq(images[1].get_command_index(), 2)
  assert_eq(images[1].get_source_pixel_count(), 1)
  assert_true(images[2].get_resource_key() == Some("png-transform-quality"))
  assert_eq(images[2].get_command_index(), 3)
  assert_eq(images[2].get_source_pixel_count(), 2)
  assert_true(
    images[3].get_resource_key() == Some("png-transform-quality-sprite"),
  )
  assert_eq(images[3].get_command_index(), 4)
  assert_eq(images[3].get_source_pixel_count(), 1)
  assert_true(images[4].get_resource_key() == Some("rgba-transform-quality"))
  assert_eq(images[4].get_command_index(), 5)
  assert_eq(images[4].get_source_pixel_count(), 2)
  assert_true(
    images[5].get_resource_key() == Some("rgba-transform-quality-sprite"),
  )
  assert_eq(images[5].get_command_index(), 6)
  assert_eq(images[5].get_source_pixel_count(), 1)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_font_key(), "ui-font")
  assert_eq(fonts[0].get_command_index(), 7)
  assert_eq(fonts[0].get_font_byte_count(), 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("label"))
  assert_eq(texts[0].get_command_index(), 7)
  assert_eq(texts[0].get_text_byte_count(), 1)
  let batch_plan = first_pipeline.batch_plan(18, 12)
  assert_eq(batch_plan.get_command_count(), 8)
  assert_eq(batch_plan.get_batch_count(), 3)
  assert_true(
    batch_plan.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=18, height=12)),
  )
  let batches = batch_plan.get_batches()
  assert_true(batches[0].get_kind() == RenderPipelineBatchKind::Clear)
  assert_eq(batches[0].get_start_index(), 0)
  assert_eq(batches[0].get_command_count(), 1)
  assert_true(
    batches[0].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=18, height=12)),
  )
  assert_true(batches[1].get_kind() == RenderPipelineBatchKind::Image)
  assert_eq(batches[1].get_start_index(), 1)
  assert_eq(batches[1].get_command_count(), 6)
  assert_eq(batches[1].get_dirty_rect_count(), 6)
  assert_true(
    batches[1].get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=17, height=1)),
  )
  let image_rect_present = batches[1].get_present_plan(18, 12, 6)
  assert_true(!image_rect_present.uses_bounds_fallback())
  assert_eq(image_rect_present.get_rect_count(), 6)
  assert_eq(image_rect_present.get_present_pixel_count(), 12)
  let image_bounds_present = batches[1].get_present_plan(18, 12, 4)
  assert_true(image_bounds_present.uses_bounds_fallback())
  assert_eq(image_bounds_present.get_rect_count(), 1)
  assert_true(
    image_bounds_present.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=17, height=1)),
  )
  assert_eq(image_bounds_present.get_present_pixel_count(), 17)
  assert_true(batches[2].get_kind() == RenderPipelineBatchKind::Text)
  assert_eq(batches[2].get_start_index(), 7)
  assert_eq(batches[2].get_command_count(), 1)
  assert_true(batches[2].has_dirty())

  let first = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      first_pipeline, resources, loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected transformed-quality image and loaded font replay")
  }
  assert_eq(first.get_command_count(), 8)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_image_count(), 6)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_image_count(), 6)
  assert_eq(first.get_keyed_resource_count(), 8)
  assert_eq(first.get_image_cache_insert_count(), 6)
  assert_eq(first.get_image_cache_hit_count(), 0)
  assert_eq(first.get_keyed_font_count(), 1)
  assert_eq(first.get_keyed_text_count(), 1)
  assert_eq(first.get_font_parse_count(), 1)
  assert_eq(first.get_text_mask_render_count(), 1)
  assert_eq(first.get_resource_cache_miss_count(), 8)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_image("bmp-transform-quality"))
  assert_true(resources.contains_image("bmp-transform-quality-sprite"))
  assert_true(resources.contains_image("png-transform-quality"))
  assert_true(resources.contains_image("png-transform-quality-sprite"))
  assert_true(resources.contains_image("rgba-transform-quality"))
  assert_true(resources.contains_image("rgba-transform-quality-sprite"))
  assert_true(resources.contains_font_face("ui-font"))
  assert_true(resources.contains_text_mask("label"))
  let filled_snapshot = resources.snapshot()
  assert_eq(filled_snapshot.get_image_count(), 6)
  assert_eq(filled_snapshot.get_image_capacity(), 6)
  assert_true(filled_snapshot.is_image_capacity_bounded())
  assert_eq(filled_snapshot.get_font_face_count(), 1)
  assert_eq(filled_snapshot.get_font_face_capacity(), 2)
  assert_true(filled_snapshot.is_font_face_capacity_bounded())
  let filled_text_snapshot = filled_snapshot.get_text_snapshot()
  assert_eq(filled_text_snapshot.get_text_mask_count(), 1)
  assert_eq(filled_text_snapshot.get_text_mask_capacity(), 2)
  assert_true(filled_text_snapshot.is_text_mask_capacity_bounded())
  assert_eq(filled_text_snapshot.get_glyph_mask_count(), 0)
  assert_eq(filled_text_snapshot.get_glyph_mask_capacity(), 2)
  assert_true(filled_text_snapshot.is_glyph_mask_capacity_bounded())
  assert_eq(filled_text_snapshot.get_atlas_entry_count(), 0)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(3, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(6, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(9, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(12, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(15, 0),
    @graphics.Color::green(),
  )

  loader.clear()
  let second = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
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
      .draw_transformed_quality_png_bytes_keyed(
        "png-transform-quality",
        Bytes::from_array([137, 80]),
        7.0,
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
        10.0,
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
        13.0,
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
        16.0,
        0.0,
        2.0,
        1.0,
        @graphics.Paint::new(),
        @graphics.ImageQuality::Fast,
      )
      .draw_loaded_font_keyed("ui-font", "label", "A", 1.0, 1.0, config, paint),
      resources,
      loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected transformed-quality image and font cache hits")
  }
  assert_eq(second.get_command_count(), 8)
  assert_eq(second.get_image_count(), 6)
  assert_eq(second.get_text_count(), 1)
  assert_eq(second.get_keyed_image_count(), 6)
  assert_eq(second.get_keyed_resource_count(), 8)
  assert_eq(second.get_image_cache_insert_count(), 0)
  assert_eq(second.get_image_cache_hit_count(), 6)
  assert_eq(second.get_font_parse_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 1)
  assert_eq(second.get_text_mask_render_count(), 0)
  assert_eq(second.get_text_cache_hit_count(), 1)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 8)
  assert_eq(resources.get_image_cache().len(), 6)
  assert_eq(resources.get_font_face_cache().len(), 1)
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(4, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(7, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(10, 0),
    @graphics.Color::green(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(13, 0),
    @graphics.Color::red(),
  )
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(16, 0),
    @graphics.Color::green(),
  )
}
