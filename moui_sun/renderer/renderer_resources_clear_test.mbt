///|
test "RendererTextResources::clear drops all text draw resources" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererTextResources::new(16, 16)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  ignore(
    renderer.draw_text_face_cached_with_resources(
      face,
      "A",
      1.0,
      1.0,
      config,
      resources,
      "label",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
  )
  ignore(
    renderer.draw_text_face_atlas_with_resources(
      face,
      "A",
      1.0,
      1.0,
      config,
      resources,
      "fixture",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
  )
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)

  resources.clear()
  assert_true(resources.get_text_mask_cache().is_empty())
  assert_true(resources.get_glyph_mask_cache().is_empty())
  assert_true(resources.get_glyph_mask_atlas().is_empty())
}

///|
test "RendererResources::clear drops font text and image resources" {
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let resources = RendererResources::new(16, 16)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let icon = @graphics.Pixmap::new(1, 1)
  icon.set_pixel(0, 0, @graphics.Color::green())
  ignore(resources.get_image_cache().insert("icon", icon))
  ignore(
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
    ),
  )
  ignore(
    renderer.draw_font_bytes_atlas_with_renderer_resources(
      b"not a font",
      "A",
      1.0,
      1.0,
      config,
      resources,
      "ui-font",
      "fixture",
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
  )
  assert_eq(resources.get_font_face_cache().len(), 1)
  assert_eq(resources.get_text_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_cache().len(), 1)
  assert_eq(resources.get_glyph_mask_atlas().len(), 1)
  assert_eq(resources.get_image_cache().len(), 1)

  resources.clear()
  assert_true(resources.get_font_face_cache().is_empty())
  assert_true(resources.get_text_mask_cache().is_empty())
  assert_true(resources.get_glyph_mask_cache().is_empty())
  assert_true(resources.get_glyph_mask_atlas().is_empty())
  assert_true(resources.get_image_cache().is_empty())
}
