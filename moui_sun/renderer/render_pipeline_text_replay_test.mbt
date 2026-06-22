///|
test "RenderPipeline replays parsed text commands and can be cleared" {
  let pipeline = RenderPipeline::new().clear_canvas(@graphics.Color::white())
  assert_eq(pipeline.len(), 1)
  pipeline.clear_commands()
  assert_true(pipeline.is_empty())

  let face = unwrap_font_face(@text.FontFace::from_bytes(make_minimal_ttf()))
  let config = @text.LayoutConfig::new(
    max_width=12.0,
    font_size=10.0,
    line_height=10.0,
  )
  ignore(
    pipeline
    .clear_canvas(@graphics.Color::white())
    .draw_text_face(
      face,
      "A",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    ),
  )
  let canvas = @graphics.Canvas::new(12, 12)
  let renderer = Renderer::new(canvas)
  let text_analysis = RenderPipeline::new()
    .draw_text_face(
      face,
      "A",
      1.0,
      1.0,
      config,
      @graphics.Paint::new().set_color(@graphics.Color::black()),
    )
    .analyze(12, 12)
  assert_eq(text_analysis.get_text_count(), 1)
  match text_analysis.get_dirty_bounds() {
    Some(bounds) => {
      assert_true(bounds.width > 0)
      assert_true(bounds.height > 0)
    }
    None => abort("expected text analysis dirty bounds")
  }
  let result = must_draw_pipeline(renderer, pipeline)
  assert_eq(result.get_command_count(), 2)
  assert_eq(result.get_clear_count(), 1)
  assert_eq(result.get_text_count(), 1)
  assert_true(pixmap_has_ink(renderer.get_canvas().get_pixmap()))
}
