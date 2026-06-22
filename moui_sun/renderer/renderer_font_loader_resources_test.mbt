///|
test "RendererResources exposes font cache for font loaders" {
  let resources = RendererResources::with_font_capacity(16, 16, 1, 1, 1, 1)
  let loader = @text.MemoryFontLoader::new()
  ignore(loader.insert("ui-font", @text.FontData::new(make_minimal_ttf())))

  match resources.get_font_face_cache().get_or_load_result("ui-font", loader) {
    Ok(first) => {
      assert_true(first.did_parse())
      assert_true(!first.did_hit_cache())
      assert_eq(first.get_face().get_units_per_em(), 10)
    }
    Err(_) => abort("expected renderer font loader miss")
  }
  assert_true(resources.contains_font_face("ui-font"))
  assert_eq(resources.snapshot().get_font_face_count(), 1)

  loader.clear()
  match resources.get_font_face_cache().get_or_load("ui-font", loader) {
    Ok(cached) => assert_eq(cached.get_units_per_em(), 10)
    Err(_) => abort("expected renderer font loader cache hit")
  }

  match resources.get_font_face_cache().get_or_load("missing-font", loader) {
    Err(@text.FontLoadError::MissingFontData("missing-font")) => ()
    _ => abort("expected missing renderer font loader source")
  }
}

///|
test "Renderer loaded font draw paths reuse font cache" {
  let canvas = @graphics.Canvas::new(18, 14)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(32, 32, 2, 2, 8, 1)
  let loader = @text.MemoryFontLoader::new()
  ignore(loader.insert("ui-font", @text.FontData::new(make_minimal_ttf())))
  let config = @text.LayoutConfig::new(
    max_width=18.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())

  match
    renderer.draw_loaded_font_cached_with_renderer_resources(
      loader, "A", 1.0, 1.0, config, resources, "ui-font", "label:A", paint,
    ) {
    Ok(first) => {
      assert_true(first.did_parse_font())
      assert_true(!first.did_hit_font_cache())
      assert_true(first.did_render_mask())
    }
    Err(_) => abort("expected loaded font text draw")
  }
  assert_true(pixmap_has_ink(canvas.get_pixmap()))

  loader.clear()
  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_loaded_font_atlas_with_renderer_resources(
      loader, "A", 1.0, 1.0, config, resources, "ui-font", "glyph:A", paint,
    ) {
    Ok(second) => {
      assert_true(!second.did_parse_font())
      assert_true(second.did_hit_font_cache())
      assert_true(second.get_drawn_glyph_count() > 0)
    }
    Err(_) => abort("expected loaded font atlas draw cache hit")
  }
  assert_true(pixmap_has_ink(canvas.get_pixmap()))
}

///|
test "Renderer loaded font draw paths accept TextSystem font loader" {
  let canvas = @graphics.Canvas::new(18, 14)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(32, 32, 2, 2, 8, 1)
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
    max_width=18.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())

  match
    renderer.draw_loaded_font_cached_with_renderer_resources(
      system, "A", 1.0, 1.0, config, resources, "ui-font", "label:A", paint,
    ) {
    Ok(first) => {
      assert_true(first.did_parse_font())
      assert_true(!first.did_hit_font_cache())
      assert_true(first.did_render_mask())
    }
    Err(_) => abort("expected TextSystem loaded font text draw")
  }
  assert_true(pixmap_has_ink(canvas.get_pixmap()))
  assert_true(resources.contains_font_face("ui-font"))

  system.clear_fonts()
  canvas.clear(@graphics.Color::white())
  match
    renderer.draw_loaded_font_atlas_with_renderer_resources(
      system, "A", 1.0, 1.0, config, resources, "ui-font", "glyph:A", paint,
    ) {
    Ok(second) => {
      assert_true(!second.did_parse_font())
      assert_true(second.did_hit_font_cache())
      assert_true(second.get_drawn_glyph_count() > 0)
    }
    Err(_) => abort("expected TextSystem loaded font atlas cache hit")
  }
  assert_true(pixmap_has_ink(canvas.get_pixmap()))
}
