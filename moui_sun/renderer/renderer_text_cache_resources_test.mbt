///|
test "Renderer::draw_text_face_cached_with_resources reuses text masks" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererTextResources::with_capacities(16, 16, 1, 2)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = renderer.draw_text_face_cached_with_resources(
    face,
    "A",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(first.did_render_mask())
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::black())

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_face_cached_with_resources(
    face,
    "O",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(second.did_hit_cache())
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::black())

  ignore(
    renderer.draw_text_face_cached_with_resources(
      face,
      "O",
      1.0,
      1.0,
      config,
      resources,
      "other-label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
  )
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_true(resources.get_text_mask_cache().get("label") is None)
}

///|
test "Renderer cached text path uses RendererResources" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 1, 2, 2)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = renderer.draw_text_face_cached_with_renderer_resources(
    face,
    "A",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(first.did_render_mask())
  assert_eq(resources.get_text_mask_cache().len(), 1)

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_face_cached_with_renderer_resources(
    face,
    "O",
    1.0,
    1.0,
    config,
    resources,
    "label",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_true(second.did_hit_cache())
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::black())
}

///|
test "Renderer::draw_text_face_atlas_with_resources reuses glyph resources" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererTextResources::with_capacities(16, 16, 4, 4)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = renderer.draw_text_face_atlas_with_resources(
    face,
    "AA",
    1.0,
    1.0,
    config,
    resources,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(first.get_glyph_count(), 2)
  assert_eq(first.get_drawn_glyph_count(), 2)
  assert_eq(first.get_rasterized_glyph_count(), 1)
  assert_eq(first.get_cache_hit_count(), 1)
  assert_eq(first.get_atlas_inserted_count(), 1)
  assert_eq(first.get_atlas_hit_count(), 1)
  assert_eq(resources.get_glyph_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_face_atlas_with_resources(
    face,
    "AA",
    1.0,
    1.0,
    config,
    resources,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_inserted_count(), 0)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_eq(canvas.get_pixmap().get_pixel(1, 1), @graphics.Color::black())
  assert_eq(canvas.get_pixmap().get_pixel(11, 1), @graphics.Color::black())
}

///|
test "Renderer atlas text path uses RendererResources" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::with_capacities(16, 16, 4, 4, 2)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let first = renderer.draw_text_face_atlas_with_renderer_resources(
    face,
    "AA",
    1.0,
    1.0,
    config,
    resources,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(first.get_rasterized_glyph_count(), 1)
  assert_eq(first.get_cache_hit_count(), 1)
  assert_eq(first.get_atlas_inserted_count(), 1)
  assert_eq(first.get_atlas_hit_count(), 1)

  canvas.clear(@graphics.Color::white())
  let second = renderer.draw_text_face_atlas_with_renderer_resources(
    face,
    "AA",
    1.0,
    1.0,
    config,
    resources,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(second.get_rasterized_glyph_count(), 0)
  assert_eq(second.get_cache_hit_count(), 2)
  assert_eq(second.get_atlas_inserted_count(), 0)
  assert_eq(second.get_atlas_hit_count(), 2)
  assert_eq(resources.get_glyph_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)
}
