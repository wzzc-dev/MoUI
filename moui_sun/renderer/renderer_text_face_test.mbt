///|
test "Renderer::draw_text_face renders parsed TTF bytes to pixmap" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  renderer.draw_text_face(
    face,
    "A",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer::draw_text_face_atlas renders parsed TTF bytes" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(12, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let glyph_cache = @text.GlyphMaskCache::new()
  let atlas = @text.GlyphMaskAtlas::new(16, 16)
  let result = renderer.draw_text_face_atlas(
    face,
    "A",
    1.0,
    1.0,
    config,
    glyph_cache,
    atlas,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(result.get_glyph_count(), 1)
  assert_eq(result.get_drawn_glyph_count(), 1)
  assert_eq(result.get_skipped_glyph_count(), 0)
  assert_eq(result.get_cache_hit_count(), 0)
  assert_eq(result.get_rasterized_glyph_count(), 1)
  assert_eq(result.get_atlas_hit_count(), 0)
  assert_eq(result.get_atlas_inserted_count(), 1)
  assert_true(!result.did_clear_atlas())
  assert_eq(glyph_cache.len(), 1)
  assert_eq(atlas.len(), 1)
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(0, 0), @graphics.Color::white())
}

///|
test "Renderer::draw_text_face_atlas reports atlas rotation" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(16, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let glyph_cache = @text.GlyphMaskCache::new()
  let atlas = @text.GlyphMaskAtlas::new(10, 10)
  let result = renderer.draw_text_face_atlas(
    face,
    "AB",
    1.0,
    1.0,
    config,
    glyph_cache,
    atlas,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(result.get_glyph_count(), 2)
  assert_eq(result.get_drawn_glyph_count(), 2)
  assert_eq(result.get_skipped_glyph_count(), 0)
  assert_eq(result.get_cache_hit_count(), 0)
  assert_eq(result.get_rasterized_glyph_count(), 2)
  assert_eq(result.get_atlas_hit_count(), 0)
  assert_eq(result.get_atlas_inserted_count(), 2)
  assert_true(result.did_clear_atlas())
  assert_eq(glyph_cache.len(), 2)
  assert_eq(atlas.len(), 1)
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(14, 4), @graphics.Color::black())
}

///|
test "Renderer::draw_text_face_atlas reports glyph cache hits" {
  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let glyph_cache = @text.GlyphMaskCache::new()
  let atlas = @text.GlyphMaskAtlas::new(16, 16)
  let result = renderer.draw_text_face_atlas(
    face,
    "AA",
    1.0,
    1.0,
    config,
    glyph_cache,
    atlas,
    "fixture",
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(result.get_glyph_count(), 2)
  assert_eq(result.get_drawn_glyph_count(), 2)
  assert_eq(result.get_skipped_glyph_count(), 0)
  assert_eq(result.get_cache_hit_count(), 1)
  assert_eq(result.get_rasterized_glyph_count(), 1)
  assert_eq(result.get_atlas_hit_count(), 1)
  assert_eq(result.get_atlas_inserted_count(), 1)
  assert_true(!result.did_clear_atlas())
  assert_eq(glyph_cache.len(), 1)
  assert_eq(atlas.len(), 1)
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(11, 1), @graphics.Color::black())
}
