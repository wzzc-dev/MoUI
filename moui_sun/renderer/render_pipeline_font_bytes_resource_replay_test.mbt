///|
test "RenderPipeline font bytes replay uses RendererResources and preserves errors" {
  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 1, 1, 2, 1)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_font_bytes_keyed(
      "ui-font",
      make_minimal_ttf(),
      "label",
      "A",
      1.0,
      1.0,
      config,
      paint,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_font_count(), 1)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_true(plan.get_font_byte_count() > 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "ui-font")
  assert_true(fonts[0].get_font_byte_count() > 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("label"))
  assert_eq(texts[0].get_glyph_count(), 1)

  let first = match
    renderer.draw_pipeline_with_renderer_resources_result(
      first_pipeline, resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected font-byte pipeline replay")
  }
  assert_eq(first.get_command_count(), 2)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_font_count(), 1)
  assert_eq(first.get_keyed_text_count(), 1)
  assert_eq(first.get_keyed_resource_count(), 2)
  assert_eq(first.get_font_parse_count(), 1)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_text_mask_render_count(), 1)
  assert_eq(first.get_text_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 2)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_font_face("ui-font"))
  assert_true(resources.contains_text_mask("label"))
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 1),
    @graphics.Color::black(),
  )

  let second = match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_font_bytes_keyed(
        "ui-font", b"not a font", "label", "O", 1.0, 1.0, config, paint,
      ),
      resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font-byte pipeline replay")
  }
  assert_eq(second.get_font_parse_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 1)
  assert_eq(second.get_text_mask_render_count(), 0)
  assert_eq(second.get_text_cache_hit_count(), 1)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 2)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 1),
    @graphics.Color::black(),
  )

  let bad_resources = RendererResources::new(16, 16)
  match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_font_bytes_keyed(
        "bad-font", b"not a font", "bad-label", "A", 1.0, 1.0, config, paint,
      ),
      bad_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::FontParseFailed(
        "bad-font",
        @text.FontParseError::UnexpectedEndOfData(0, 12, 10)
      )
    ) => ()
    _ => abort("expected checked parser error")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_text_mask_cache().is_empty())
}

///|
test "RenderPipeline font bytes atlas replay uses RendererResources and preserves errors" {
  let renderer = Renderer::new(@graphics.Canvas::new(24, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 1, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_font_bytes_atlas_keyed(
      "ui-font",
      make_minimal_ttf(),
      "glyph-label",
      "AA",
      1.0,
      1.0,
      config,
      paint,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_font_count(), 1)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_true(plan.get_font_byte_count() > 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "ui-font")
  assert_true(fonts[0].get_font_byte_count() > 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("glyph-label"))
  assert_eq(texts[0].get_text_byte_count(), 2)
  assert_eq(texts[0].get_glyph_count(), 2)

  let first = match
    renderer.draw_pipeline_with_renderer_resources_result(
      first_pipeline, resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected font-byte atlas pipeline replay")
  }
  assert_eq(first.get_command_count(), 2)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_font_count(), 1)
  assert_eq(first.get_keyed_text_count(), 0)
  assert_eq(first.get_keyed_atlas_text_count(), 1)
  assert_eq(first.get_keyed_resource_count(), 2)
  assert_eq(first.get_font_parse_count(), 1)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_text_mask_render_count(), 0)
  assert_eq(first.get_text_cache_hit_count(), 0)
  assert_eq(first.get_glyph_mask_render_count(), 1)
  assert_eq(first.get_glyph_cache_hit_count(), 1)
  assert_eq(first.get_atlas_insert_count(), 1)
  assert_eq(first.get_atlas_cache_hit_count(), 1)
  assert_eq(first.get_atlas_clear_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 3)
  assert_eq(first.get_resource_cache_hit_count(), 2)
  assert_true(resources.contains_font_face("ui-font"))
  assert_eq(resources.get_glyph_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 1),
    @graphics.Color::black(),
  )

  let second = match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_font_bytes_atlas_keyed(
        "ui-font", b"not a font", "glyph-label", "AA", 1.0, 1.0, config, paint,
      ),
      resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font-byte atlas pipeline replay")
  }
  assert_eq(second.get_font_parse_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 1)
  assert_eq(second.get_glyph_mask_render_count(), 0)
  assert_eq(second.get_glyph_cache_hit_count(), 2)
  assert_eq(second.get_atlas_insert_count(), 0)
  assert_eq(second.get_atlas_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 5)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)

  let bad_resources = RendererResources::with_font_capacity(16, 16, 1, 4, 4, 1)
  match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_font_bytes_atlas_keyed(
        "bad-font", b"not a font", "bad-glyph", "A", 1.0, 1.0, config, paint,
      ),
      bad_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::FontParseFailed(
        "bad-font",
        @text.FontParseError::UnexpectedEndOfData(0, 12, 10)
      )
    ) => ()
    _ => abort("expected checked atlas parser error")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_atlas().is_empty())
}

///|
test "RenderPipeline font bytes fallback replay uses RendererResources and preserves errors" {
  let renderer = Renderer::new(@graphics.Canvas::new(36, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 2, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_font_bytes_fallback_keyed(
      [
        FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("fallback", make_ttf_for_codes([66])),
      ],
      "label",
      "ABZ",
      1.0,
      1.0,
      config,
      paint,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_font_count(), 2)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 3)
  assert_eq(plan.get_keyed_resource_count(), 3)
  assert_true(plan.get_font_byte_count() > 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "primary")
  assert_eq(fonts[1].get_font_key(), "fallback")
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("label"))
  assert_eq(texts[0].get_text_byte_count(), 3)
  assert_eq(texts[0].get_glyph_count(), 0)

  let first = match
    renderer.draw_pipeline_with_renderer_resources_result(
      first_pipeline, resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected font-byte fallback pipeline replay")
  }
  assert_eq(first.get_command_count(), 2)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_font_count(), 2)
  assert_eq(first.get_keyed_text_count(), 2)
  assert_eq(first.get_keyed_resource_count(), 4)
  assert_eq(first.get_font_parse_count(), 2)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_text_mask_render_count(), 2)
  assert_eq(first.get_text_cache_hit_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 4)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_font_face("primary"))
  assert_true(resources.contains_font_face("fallback"))
  assert_eq(resources.get_text_mask_cache().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  let second = match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_font_bytes_fallback_keyed(
        [
          FontBytesFallbackSource::new("primary", b"not a font"),
          FontBytesFallbackSource::new("fallback", b"also not a font"),
        ],
        "label",
        "ABZ",
        1.0,
        1.0,
        config,
        paint,
      ),
      resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached fallback pipeline replay")
  }
  assert_eq(second.get_font_parse_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 2)
  assert_eq(second.get_text_mask_render_count(), 0)
  assert_eq(second.get_text_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 4)
  assert_eq(resources.get_font_face_cache().len(), 2)
  assert_eq(resources.get_text_mask_cache().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  let bad_resources = RendererResources::new(16, 16)
  match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_font_bytes_fallback_keyed(
        [FontBytesFallbackSource::new("bad-font", b"not a font")],
        "bad-label",
        "A",
        1.0,
        1.0,
        config,
        paint,
      ),
      bad_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::FontParseFailed(
        "bad-font",
        @text.FontParseError::UnexpectedEndOfData(0, 12, 10)
      )
    ) => ()
    _ => abort("expected checked fallback parser error")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_text_mask_cache().is_empty())
}

///|
test "RenderPipeline font bytes fallback atlas replay uses RendererResources and preserves errors" {
  let renderer = Renderer::new(@graphics.Canvas::new(36, 12))
  let resources = RendererResources::with_font_capacity(24, 12, 2, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_font_bytes_fallback_atlas_keyed(
      [
        FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("fallback", make_ttf_for_codes([66])),
      ],
      "glyph-label",
      "ABZ",
      1.0,
      1.0,
      config,
      paint,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_font_count(), 2)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 3)
  assert_eq(plan.get_keyed_resource_count(), 3)
  assert_true(plan.get_font_byte_count() > 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "primary")
  assert_eq(fonts[1].get_font_key(), "fallback")
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("glyph-label"))
  assert_eq(texts[0].get_text_byte_count(), 3)
  assert_eq(texts[0].get_glyph_count(), 0)

  let first = match
    renderer.draw_pipeline_with_renderer_resources_result(
      first_pipeline, resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected font-byte fallback atlas pipeline replay")
  }
  assert_eq(first.get_command_count(), 2)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_font_count(), 2)
  assert_eq(first.get_keyed_text_count(), 0)
  assert_eq(first.get_keyed_atlas_text_count(), 2)
  assert_eq(first.get_keyed_resource_count(), 4)
  assert_eq(first.get_font_parse_count(), 2)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_text_mask_render_count(), 0)
  assert_eq(first.get_text_cache_hit_count(), 0)
  assert_eq(first.get_glyph_mask_render_count(), 2)
  assert_eq(first.get_glyph_cache_hit_count(), 0)
  assert_eq(first.get_atlas_insert_count(), 2)
  assert_eq(first.get_atlas_cache_hit_count(), 0)
  assert_eq(first.get_atlas_clear_count(), 0)
  assert_eq(first.get_resource_cache_miss_count(), 6)
  assert_eq(first.get_resource_cache_hit_count(), 0)
  assert_true(resources.contains_font_face("primary"))
  assert_true(resources.contains_font_face("fallback"))
  assert_eq(resources.get_glyph_mask_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_atlas().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  let second = match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_font_bytes_fallback_atlas_keyed(
        [
          FontBytesFallbackSource::new("primary", b"not a font"),
          FontBytesFallbackSource::new("fallback", b"also not a font"),
        ],
        "glyph-label",
        "ABZ",
        1.0,
        1.0,
        config,
        paint,
      ),
      resources,
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached fallback atlas pipeline replay")
  }
  assert_eq(second.get_font_parse_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 2)
  assert_eq(second.get_glyph_mask_render_count(), 0)
  assert_eq(second.get_glyph_cache_hit_count(), 2)
  assert_eq(second.get_atlas_insert_count(), 0)
  assert_eq(second.get_atlas_cache_hit_count(), 2)
  assert_eq(second.get_resource_cache_miss_count(), 0)
  assert_eq(second.get_resource_cache_hit_count(), 6)
  assert_eq(resources.get_font_face_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_atlas().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  let bad_resources = RendererResources::with_font_capacity(24, 12, 2, 4, 4, 1)
  match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_font_bytes_fallback_atlas_keyed(
        [FontBytesFallbackSource::new("bad-font", b"not a font")],
        "bad-glyph",
        "A",
        1.0,
        1.0,
        config,
        paint,
      ),
      bad_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::FontParseFailed(
        "bad-font",
        @text.FontParseError::UnexpectedEndOfData(0, 12, 10)
      )
    ) => ()
    _ => abort("expected checked fallback atlas parser error")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_atlas().is_empty())
}

///|
test "RenderPipeline renderer-resource replay reports loader-backed commands" {
  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  let resources = RendererResources::new(16, 16)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  match
    renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_loaded_font_keyed(
        "ui-font", "label", "A", 1.0, 1.0, config, paint,
      ),
      resources,
    ) {
    Err(RenderPipelineResourceReplayError::FontLoaderRequired("ui-font")) => ()
    _ => abort("expected loader-required replay error")
  }
  assert_true(resources.get_font_face_cache().is_empty())
  assert_true(resources.get_text_mask_cache().is_empty())
}
