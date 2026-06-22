///|
test "RenderPipeline analyzes dirty bounds and present plan" {
  let icon = @graphics.Pixmap::new(2, 2)
  let pipeline = RenderPipeline::new()
    .fill_rect(
      1.0,
      1.0,
      2.0,
      2.0,
      @graphics.Paint::new().set_color(@graphics.Color::red()),
    )
    .draw_pixmap(icon, 7, 1, @graphics.Paint::new())

  let analysis = pipeline.analyze(10, 8)
  assert_eq(analysis.get_command_count(), 2)
  assert_eq(analysis.get_fill_count(), 1)
  assert_eq(analysis.get_image_count(), 1)
  assert_eq(analysis.get_clear_count(), 0)
  assert_true(analysis.has_dirty())
  assert_eq(analysis.get_dirty_rect_count(), 2)
  assert_true(
    analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=8, height=2)),
  )

  let bounds_plan = analysis.get_present_plan(10, 8, 1)
  assert_true(bounds_plan.uses_bounds_fallback())
  assert_eq(bounds_plan.get_rect_count(), 1)
  assert_true(
    bounds_plan.get_present_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=8, height=2)),
  )

  let rect_plan = pipeline.dirty_present_plan(10, 8, 4)
  assert_true(!rect_plan.uses_bounds_fallback())
  assert_eq(rect_plan.get_rect_count(), 2)
  assert_eq(rect_plan.get_present_pixel_count(), 8)
}

///|
test "RenderPipeline analysis clips canvas bounds and estimates stroke paths" {
  let renderer = Renderer::new(@graphics.Canvas::new(4, 3))
  let clear_analysis = renderer.analyze_pipeline(
    RenderPipeline::new().clear_canvas(@graphics.Color::white()),
  )
  assert_true(
    clear_analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=3)),
  )
  assert_eq(clear_analysis.get_dirty_rect_count(), 1)

  let stroke_paint = @graphics.Paint::new()
    .set_style(@graphics.PaintStyle::Stroke)
    .set_stroke_width(4.0)
  let stroke_path = @graphics.Path::new().move_to(4.0, 4.0).line_to(6.0, 4.0)
  let stroke_analysis = RenderPipeline::new()
    .stroke_path(stroke_path, stroke_paint)
    .analyze(10, 10)
  assert_eq(stroke_analysis.get_stroke_count(), 1)
  assert_true(
    stroke_analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=2, width=6, height=4)),
  )
}

///|
test "RenderPipeline analysis uses path control bounds" {
  let path = @graphics.Path::new().move_to(1.0, 1.0).quad_to(5.0, 2.0, 1.0, 3.0)
  let analysis = RenderPipeline::new()
    .fill_path(path, @graphics.Paint::new())
    .analyze(8, 6)
  assert_true(
    analysis.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=4, height=2)),
  )
}
