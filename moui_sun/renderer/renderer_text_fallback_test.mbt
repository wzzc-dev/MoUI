///|
test "Renderer::draw_text_fallback_line draws spans with covering faces" {
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
  let result = renderer.draw_text_fallback_line(
    [primary, fallback],
    "ABZ",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(result.get_span_count(), 3)
  assert_eq(result.get_drawn_span_count(), 2)
  assert_eq(result.get_skipped_span_count(), 1)
  assert_eq(result.get_missing_span_count(), 1)
  assert_eq(result.get_missing_char_count(), 1)
  assert_eq(result.get_rendered_mask_count(), 0)
  assert_eq(result.get_cache_hit_count(), 0)
  assert_true(result.has_missing_glyphs())
  assert_eq(result.get_advance_width(), 26.0)
  let plan = result.get_plan()
  assert_eq(plan.get_missing_char_count(), 1)
  let spans = plan.get_spans()
  assert_eq(spans[0].get_face_index(), 0)
  assert_eq(spans[1].get_face_index(), 1)
  assert_true(spans[2].is_missing())

  let pixmap = renderer.get_canvas().get_pixmap()
  assert_eq(pixmap.get_pixel(1, 1), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(14, 5), @graphics.Color::black())
  assert_eq(pixmap.get_pixel(21, 1), @graphics.Color::white())
}

///|
test "Renderer::draw_text_fallback_line handles empty fallback stack" {
  let canvas = @graphics.Canvas::new(24, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
  )
  let result = renderer.draw_text_fallback_line(
    [],
    "AB",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(result.get_span_count(), 1)
  assert_eq(result.get_drawn_span_count(), 0)
  assert_eq(result.get_skipped_span_count(), 1)
  assert_eq(result.get_missing_char_count(), 2)
  assert_eq(result.get_rendered_mask_count(), 0)
  assert_eq(result.get_cache_hit_count(), 0)
  assert_eq(result.get_advance_width(), 12.0)
  assert_true(!pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}

///|
test "Renderer::draw_text_fallback_line keeps spacing across fallback spans" {
  let primary = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([65])),
  )
  let fallback = unwrap_font_face(
    @text.FontFace::from_bytes(make_ttf_for_codes([66])),
  )
  let canvas = @graphics.Canvas::new(40, 12)
  canvas.clear(@graphics.Color::white())
  let renderer = Renderer::new(canvas)
  let config = @text.LayoutConfig::new(
    max_width=40.0,
    font_size=10.0,
    line_height=10.0,
    letter_spacing=2.0,
  )
  let result = renderer.draw_text_fallback_line(
    [primary, fallback],
    "AB",
    1.0,
    1.0,
    config,
    @graphics.Paint::new().set_color(@graphics.Color::black()),
  )
  assert_eq(result.get_advance_width(), 22.0)
  assert_eq(result.get_rendered_mask_count(), 0)
  assert_eq(result.get_cache_hit_count(), 0)
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(16, 5),
    @graphics.Color::black(),
  )
}
