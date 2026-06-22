///|
test "Renderer cached font bytes path uses RendererResources" {
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(16, 16, 1, 1, 2, 1)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )

  let first = match
    renderer.draw_font_bytes_cached_with_renderer_resources(
      make_minimal_ttf(),
      "A",
      1.0,
      1.0,
      config,
      resources,
      "ui-font",
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font text draw")
  }
  assert_true(first.did_parse_font())
  assert_true(!first.did_hit_font_cache())
  assert_true(first.did_render_mask())
  assert_true(!first.did_hit_text_cache())
  assert_true(first.get_text_result().did_render_mask())
  assert_eq(resources.get_font_face_cache().len(), 1)
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::black())

  canvas.clear(@graphics.Color::white())
  let second = match
    renderer.draw_font_bytes_cached_with_renderer_resources(
      b"not a font",
      "O",
      1.0,
      1.0,
      config,
      resources,
      "ui-font",
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font hit to skip invalid bytes")
  }
  assert_true(!second.did_parse_font())
  assert_true(second.did_hit_font_cache())
  assert_true(second.did_hit_text_cache())
  assert_eq(resources.get_font_face_cache().len(), 1)
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::black())
}

///|
test "Renderer cached font atlas path uses RendererResources" {
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(16, 16, 1, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )

  let first = match
    renderer.draw_font_bytes_atlas_with_renderer_resources(
      make_minimal_ttf(),
      "AA",
      1.0,
      1.0,
      config,
      resources,
      "ui-font",
      "fixture",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font atlas draw")
  }
  assert_true(first.did_parse_font())
  assert_eq(first.get_glyph_count(), 2)
  assert_eq(first.get_drawn_glyph_count(), 2)
  assert_eq(first.get_skipped_glyph_count(), 0)
  assert_eq(first.get_rasterized_glyph_count(), 1)
  assert_eq(first.get_cache_hit_count(), 1)
  assert_eq(first.get_atlas_inserted_count(), 1)
  assert_eq(first.get_atlas_hit_count(), 1)
  assert_true(!first.did_clear_atlas())
  assert_eq(first.get_atlas_result().get_glyph_count(), 2)

  canvas.clear(@graphics.Color::white())
  let second = match
    renderer.draw_font_bytes_atlas_with_renderer_resources(
      b"not a font",
      "AA",
      1.0,
      1.0,
      config,
      resources,
      "ui-font",
      "fixture",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font hit to skip invalid bytes")
  }
  assert_true(!second.did_parse_font())
  assert_true(second.did_hit_font_cache())
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_inserted_count(), 0)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_eq(resources.get_font_face_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)
}

///|
test "Renderer cached font bytes path preserves parse errors" {
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::new(16, 16)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  match
    renderer.draw_font_bytes_cached_with_renderer_resources(
      b"not a font",
      "A",
      1.0,
      1.0,
      config,
      resources,
      "bad-font",
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Err(@text.FontParseError::UnexpectedEndOfData(0, 12, 10)) => ()
    _ => abort("expected checked parser error")
  }
  assert_true(resources.get_font_face_cache().is_empty())
  assert_true(resources.get_text_mask_cache().is_empty())
}
