///|
test "Renderer::draw_text_fallback_line_cached reuses fallback span masks" {
  let primary = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([65])),
  )
  let fallback = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([66])),
  )
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let text_cache = @text.TextMaskCache::new()
  let first = renderer.draw_text_fallback_line_cached(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    text_cache,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(first.get_span_count(), 3)
  assert_eq(first.get_drawn_span_count(), 2)
  assert_eq(first.get_skipped_span_count(), 1)
  assert_eq(first.get_missing_char_count(), 1)
  assert_eq(first.get_rendered_mask_count(), 2)
  assert_eq(first.get_cache_hit_count(), 0)
  assert_eq(text_cache.len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_fallback_line_cached(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    text_cache,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(second.get_drawn_span_count(), 2)
  assert_eq(second.get_skipped_span_count(), 1)
  assert_eq(second.get_rendered_mask_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(text_cache.len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer::draw_text_fallback_line_atlas reuses fallback glyph resources" {
  let primary = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([65])),
  )
  let fallback = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([66])),
  )
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let glyph_cache = @text.GlyphMaskCache::new()
  let atlas = @text.GlyphMaskAtlas::new(24, 12)
  let first = renderer.draw_text_fallback_line_atlas(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    glyph_cache,
    atlas,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(first.get_span_count(), 3)
  assert_eq(first.get_drawn_span_count(), 2)
  assert_eq(first.get_skipped_span_count(), 1)
  assert_eq(first.get_missing_char_count(), 1)
  assert_eq(first.get_glyph_count(), 2)
  assert_eq(first.get_drawn_glyph_count(), 2)
  assert_eq(first.get_rasterized_glyph_count(), 2)
  assert_eq(first.get_cache_hit_count(), 0)
  assert_eq(first.get_atlas_inserted_count(), 2)
  assert_eq(first.get_atlas_hit_count(), 0)
  assert_eq(glyph_cache.len(), 2)
  assert_eq(atlas.len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_fallback_line_atlas(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    glyph_cache,
    atlas,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(second.get_drawn_span_count(), 2)
  assert_eq(second.get_skipped_span_count(), 1)
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_inserted_count(), 0)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_eq(glyph_cache.len(), 2)
  assert_eq(atlas.len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer fallback atlas text path uses RendererResources" {
  let primary = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([65])),
  )
  let fallback = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([66])),
  )
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(24, 12, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = renderer.draw_text_fallback_line_atlas_with_renderer_resources(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(first.get_rasterized_glyph_count(), 2)
  assert_eq(first.get_cache_hit_count(), 0)
  assert_eq(first.get_atlas_inserted_count(), 2)
  assert_eq(resources.get_glyph_mask_cache().len(), 2)
  assert_eq(resources.get_glyph_mask_atlas().len(), 2)

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_fallback_line_atlas_with_renderer_resources(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer fallback cached text path uses RendererResources" {
  let primary = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([65])),
  )
  let fallback = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([66])),
  )
  let canvas = @graphics.Canvas::new(36, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 4, 4, 1)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = renderer.draw_text_fallback_line_cached_with_renderer_resources(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(first.get_rendered_mask_count(), 2)
  assert_eq(first.get_cache_hit_count(), 0)
  assert_eq(resources.get_text_mask_cache().len(), 2)

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_fallback_line_cached_with_renderer_resources(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(second.get_rendered_mask_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(resources.get_text_mask_cache().len(), 2)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}
