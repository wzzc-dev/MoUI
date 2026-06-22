///|
test "Renderer cached font bytes fallback path uses RendererResources" {
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(16, 16, 2, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = match
    renderer.draw_font_bytes_fallback_line_cached_with_renderer_resources(
      [
        FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("fallback", make_ttf_for_codes([66])),
      ],
      "ABZ",
      1.0,
      1.0,
      config,
      resources,
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached fallback font-byte draw")
  }
  assert_eq(first.get_parsed_font_count(), 2)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_span_count(), 3)
  assert_eq(first.get_drawn_span_count(), 2)
  assert_eq(first.get_skipped_span_count(), 1)
  assert_eq(first.get_missing_span_count(), 1)
  assert_eq(first.get_missing_char_count(), 1)
  assert_true(first.has_missing_glyphs())
  assert_eq(first.get_advance_width(), 26.0)
  assert_eq(first.get_rendered_mask_count(), 2)
  assert_eq(first.get_text_cache_hit_count(), 0)
  assert_eq(resources.get_font_face_cache().len(), 2)
  assert_eq(resources.get_text_mask_cache().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  canvas.clear(@graphics.Color::white())
  let second = match
    renderer.draw_font_bytes_fallback_line_cached_with_renderer_resources(
      [
        FontBytesFallbackSource::new("primary", b"not a font"),
        FontBytesFallbackSource::new("fallback", b"also not a font"),
      ],
      "ABZ",
      1.0,
      1.0,
      config,
      resources,
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached font hits to skip invalid bytes")
  }
  assert_eq(second.get_parsed_font_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 2)
  assert_eq(second.get_rendered_mask_count(), 0)
  assert_eq(second.get_text_cache_hit_count(), 2)
  assert_eq(resources.get_font_face_cache().len(), 2)
  assert_eq(resources.get_text_mask_cache().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer cached font bytes fallback atlas path uses RendererResources" {
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_font_capacity(24, 12, 2, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = match
    renderer.draw_font_bytes_fallback_line_atlas_with_renderer_resources(
      [
        FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("fallback", make_ttf_for_codes([66])),
      ],
      "ABZ",
      1.0,
      1.0,
      config,
      resources,
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached fallback font-byte atlas draw")
  }
  assert_eq(first.get_parsed_font_count(), 2)
  assert_eq(first.get_font_cache_hit_count(), 0)
  assert_eq(first.get_span_count(), 3)
  assert_eq(first.get_drawn_span_count(), 2)
  assert_eq(first.get_skipped_span_count(), 1)
  assert_eq(first.get_missing_span_count(), 1)
  assert_eq(first.get_missing_char_count(), 1)
  assert_true(first.has_missing_glyphs())
  assert_eq(first.get_advance_width(), 26.0)
  assert_eq(first.get_atlas_result().get_glyph_count(), 2)
  assert_eq(first.get_glyph_count(), 2)
  assert_eq(first.get_drawn_glyph_count(), 2)
  assert_eq(first.get_rasterized_glyph_count(), 2)
  assert_eq(first.get_cache_hit_count(), 0)
  assert_eq(first.get_atlas_inserted_count(), 2)
  assert_eq(first.get_atlas_hit_count(), 0)
  assert_eq(resources.get_font_face_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_atlas().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  canvas.clear(@graphics.Color::white())
  let second = match
    renderer.draw_font_bytes_fallback_line_atlas_with_renderer_resources(
      [
        FontBytesFallbackSource::new("primary", b"not a font"),
        FontBytesFallbackSource::new("fallback", b"also not a font"),
      ],
      "ABZ",
      1.0,
      1.0,
      config,
      resources,
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Ok(result) => result
    Err(_) => abort("expected cached fallback atlas font hits")
  }
  assert_eq(second.get_parsed_font_count(), 0)
  assert_eq(second.get_font_cache_hit_count(), 2)
  assert_eq(second.get_span_count(), 3)
  assert_eq(second.get_missing_span_count(), 1)
  assert_true(second.has_missing_glyphs())
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_inserted_count(), 0)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_eq(resources.get_font_face_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_atlas().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer cached font bytes fallback path preserves parse errors" {
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::new(16, 16)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  match
    renderer.draw_font_bytes_fallback_line_cached_with_renderer_resources(
      [
        FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("bad-fallback", b"not a font"),
      ],
      "AB",
      1.0,
      1.0,
      config,
      resources,
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ) {
    Err(@text.FontParseError::UnexpectedEndOfData(0, 12, 10)) => ()
    _ => abort("expected checked parser error")
  }
  assert_true(resources.get_text_mask_cache().is_empty())
  assert_true(!pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}
