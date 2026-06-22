///|
test "RenderPipeline loaded font replay uses FontLoader and RendererResources" {
  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 1, 1, 2, 1)
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
    .draw_loaded_font_keyed("ui-font", "label", "A", 1.0, 1.0, config, paint)
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_font_count(), 1)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  assert_eq(plan.get_font_byte_count(), 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "ui-font")
  assert_eq(fonts[0].get_font_byte_count(), 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("label"))
  assert_eq(texts[0].get_text_byte_count(), 1)
  assert_eq(texts[0].get_glyph_count(), 0)

  let first = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      first_pipeline, resources, loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font pipeline replay")
  }
  assert_eq(first.get_command_count(), 2)
  assert_eq(first.get_clear_count(), 1)
  assert_eq(first.get_text_count(), 1)
  assert_eq(first.get_keyed_font_count(), 1)
  assert_eq(first.get_keyed_text_count(), 1)
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

  loader.clear()
  let second = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_loaded_font_keyed("ui-font", "label", "A", 1.0, 1.0, config, paint),
      resources,
      loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font pipeline cache hit")
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
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_loaded_font_keyed(
        "missing-font", "bad-label", "A", 1.0, 1.0, config, paint,
      ),
      bad_resources,
      loader,
    ) {
    Err(RenderPipelineResourceReplayError::FontDataMissing("missing-font")) =>
      ()
    _ => abort("expected missing loader-backed font")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_text_mask_cache().is_empty())
}

///|
test "RenderPipeline loaded font replay accepts TextSystem font loader" {
  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 1, 1, 2, 1)
  let system = @text.TextSystem::new()
  match
    system.register_font_data(
      "ui-font",
      @text.FontData::new(make_minimal_ttf()),
    ) {
    Ok(_) => ()
    Err(_) => abort("expected TextSystem font registration")
  }
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())

  let first = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_loaded_font_keyed("ui-font", "label", "A", 1.0, 1.0, config, paint),
      resources,
      system,
    ) {
    Ok(result) => result
    Err(_) => abort("expected TextSystem loaded-font pipeline replay")
  }
  assert_eq(first.get_keyed_font_count(), 1)
  assert_eq(first.get_font_parse_count(), 1)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_text_mask_render_count(), 1)
  assert_true(resources.contains_font_face("ui-font"))
  assert_true(resources.contains_text_mask("label"))
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(1, 1),
    @graphics.Color::black(),
  )

  system.clear_fonts()
  let second = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_loaded_font_keyed("ui-font", "label", "A", 1.0, 1.0, config, paint),
      resources,
      system,
    ) {
    Ok(result) => result
    Err(_) => abort("expected TextSystem loaded-font pipeline cache hit")
  }
  assert_eq(second.get_font_parse_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 1)
  assert_eq(second.get_text_mask_render_count(), 0)
  assert_eq(second.get_text_cache_hit_count(), 1)
}

///|
test "RenderPipeline loaded font fallback replay uses FontLoader and RendererResources" {
  let renderer = Renderer::new(@graphics.Canvas::new(36, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 2, 4, 4, 1)
  let loader = @text.MemoryFontLoader::new()
  ignore(
    loader.insert("primary", @text.FontData::new(make_ttf_for_codes([65]))),
  )
  ignore(
    loader.insert("fallback", @text.FontData::new(make_ttf_for_codes([66]))),
  )
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_loaded_font_fallback_keyed(
      ["primary", "fallback"],
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
  assert_eq(plan.get_font_byte_count(), 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "primary")
  assert_eq(fonts[0].get_font_byte_count(), 0)
  assert_eq(fonts[1].get_font_key(), "fallback")
  assert_eq(fonts[1].get_font_byte_count(), 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("label"))
  assert_eq(texts[0].get_text_byte_count(), 3)
  assert_eq(texts[0].get_glyph_count(), 0)

  let first = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      first_pipeline, resources, loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font fallback pipeline replay")
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

  loader.clear()
  let second = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_loaded_font_fallback_keyed(
        ["primary", "fallback"],
        "label",
        "ABZ",
        1.0,
        1.0,
        config,
        paint,
      ),
      resources,
      loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font fallback cache hit")
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
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_loaded_font_fallback_keyed(
        ["missing-font"],
        "bad-label",
        "A",
        1.0,
        1.0,
        config,
        paint,
      ),
      bad_resources,
      loader,
    ) {
    Err(RenderPipelineResourceReplayError::FontDataMissing("missing-font")) =>
      ()
    _ => abort("expected missing fallback font")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_text_mask_cache().is_empty())
}

///|
test "RenderPipeline loaded font fallback atlas replay uses FontLoader and RendererResources" {
  let renderer = Renderer::new(@graphics.Canvas::new(36, 12))
  let resources = RendererResources::with_font_capacity(24, 12, 2, 4, 4, 1)
  let loader = @text.MemoryFontLoader::new()
  ignore(
    loader.insert("primary", @text.FontData::new(make_ttf_for_codes([65]))),
  )
  ignore(
    loader.insert("fallback", @text.FontData::new(make_ttf_for_codes([66]))),
  )
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_loaded_font_fallback_atlas_keyed(
      ["primary", "fallback"],
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
  assert_eq(plan.get_font_byte_count(), 0)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "primary")
  assert_eq(fonts[0].get_font_byte_count(), 0)
  assert_eq(fonts[1].get_font_key(), "fallback")
  assert_eq(fonts[1].get_font_byte_count(), 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("glyph-label"))
  assert_eq(texts[0].get_text_byte_count(), 3)
  assert_eq(texts[0].get_glyph_count(), 0)

  let first = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      first_pipeline, resources, loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font fallback atlas pipeline replay")
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

  loader.clear()
  let second = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_loaded_font_fallback_atlas_keyed(
        ["primary", "fallback"],
        "glyph-label",
        "ABZ",
        1.0,
        1.0,
        config,
        paint,
      ),
      resources,
      loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font fallback atlas cache hit")
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
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_loaded_font_fallback_atlas_keyed(
        ["missing-font"],
        "bad-glyph",
        "A",
        1.0,
        1.0,
        config,
        paint,
      ),
      bad_resources,
      loader,
    ) {
    Err(RenderPipelineResourceReplayError::FontDataMissing("missing-font")) =>
      ()
    _ => abort("expected missing fallback atlas font")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_atlas().is_empty())
}

///|
test "RenderPipeline loaded font atlas replay uses FontLoader and RendererResources" {
  let renderer = Renderer::new(@graphics.Canvas::new(24, 12))
  let resources = RendererResources::with_font_capacity(16, 16, 1, 4, 4, 1)
  let loader = @text.MemoryFontLoader::new()
  ignore(loader.insert("ui-font", @text.FontData::new(make_minimal_ttf())))
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let first_pipeline = RenderPipeline::new()
    .clear_canvas(@graphics.Color::white())
    .draw_loaded_font_atlas_keyed(
      "ui-font", "glyph-label", "AA", 1.0, 1.0, config, paint,
    )
  let plan = first_pipeline.resource_plan()
  assert_eq(plan.get_command_count(), 2)
  assert_eq(plan.get_font_count(), 1)
  assert_eq(plan.get_text_count(), 1)
  assert_eq(plan.get_resource_count(), 2)
  assert_eq(plan.get_keyed_resource_count(), 2)
  let fonts = plan.get_font_dependencies()
  assert_eq(fonts[0].get_command_index(), 1)
  assert_eq(fonts[0].get_font_key(), "ui-font")
  assert_eq(fonts[0].get_font_byte_count(), 0)
  let texts = plan.get_text_dependencies()
  assert_true(texts[0].get_resource_key() == Some("glyph-label"))
  assert_eq(texts[0].get_text_byte_count(), 2)
  assert_eq(texts[0].get_glyph_count(), 0)

  let first = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      first_pipeline, resources, loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font atlas pipeline replay")
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

  loader.clear()
  let second = match
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new()
      .clear_canvas(@graphics.Color::white())
      .draw_loaded_font_atlas_keyed(
        "ui-font", "glyph-label", "AA", 1.0, 1.0, config, paint,
      ),
      resources,
      loader,
    ) {
    Ok(result) => result
    Err(_) => abort("expected loaded-font atlas pipeline cache hit")
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
    renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_loaded_font_atlas_keyed(
        "missing-font", "missing-glyph", "A", 1.0, 1.0, config, paint,
      ),
      bad_resources,
      loader,
    ) {
    Err(RenderPipelineResourceReplayError::FontDataMissing("missing-font")) =>
      ()
    _ => abort("expected missing loader-backed atlas font")
  }
  assert_true(bad_resources.get_font_face_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_cache().is_empty())
  assert_true(bad_resources.get_glyph_mask_atlas().is_empty())
}
