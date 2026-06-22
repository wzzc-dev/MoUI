///|
test "RenderPipeline diff skips retained vector commands and dirties changed pairs" {
  let red_paint = @graphics.Paint::new().set_color(@graphics.Color::red())
  let blue_paint = @graphics.Paint::new().set_color(@graphics.Color::blue())
  let stroke_paint = @graphics.Paint::new()
    .set_style(@graphics.PaintStyle::Stroke)
    .set_stroke_width(2.0)
  let path = @graphics.Path::new().move_to(0.0, 3.0).line_to(4.0, 3.0)
  let previous = RenderPipeline::new()
    .fill_rect(1.0, 1.0, 2.0, 2.0, red_paint)
    .stroke_path(path, stroke_paint)
    .fill_rect(6.0, 1.0, 1.0, 1.0, blue_paint)
  let next = RenderPipeline::new()
    .fill_rect(1.0, 1.0, 2.0, 2.0, red_paint)
    .stroke_path(path, stroke_paint)
    .fill_rect(7.0, 1.0, 1.0, 1.0, blue_paint)

  let diff = RenderPipeline::diff(previous, next, 10, 5)
  assert_true(diff.has_changes())
  assert_true(diff.has_dirty())
  assert_eq(diff.get_previous_command_count(), 3)
  assert_eq(diff.get_next_command_count(), 3)
  assert_eq(diff.get_retained_command_count(), 2)
  assert_eq(diff.get_changed_command_count(), 1)
  assert_eq(diff.get_inserted_command_count(), 0)
  assert_eq(diff.get_removed_command_count(), 0)
  assert_eq(diff.get_dirty_rect_count(), 1)
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=6, y=1, width=2, height=1)),
  )
}

///|
test "RenderPipeline diff tracks insertions removals and clipped present plan" {
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  let previous = RenderPipeline::new().fill_rect(0.0, 0.0, 1.0, 1.0, paint)
  let next = RenderPipeline::new()
    .fill_rect(0.0, 0.0, 1.0, 1.0, paint)
    .fill_rect(3.0, 1.0, 4.0, 1.0, paint)
  let renderer = Renderer::new(@graphics.Canvas::new(5, 3))

  let inserted = renderer.diff_pipelines(previous, next)
  assert_eq(inserted.get_retained_command_count(), 1)
  assert_eq(inserted.get_inserted_command_count(), 1)
  assert_eq(inserted.get_removed_command_count(), 0)
  assert_true(
    inserted.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=3, y=1, width=2, height=1)),
  )
  let plan = inserted.get_present_plan(5, 3, 4)
  assert_eq(plan.get_rect_count(), 1)
  assert_eq(plan.get_present_pixel_count(), 2)

  let removed = RenderPipeline::diff(next, previous, 5, 3)
  assert_eq(removed.get_retained_command_count(), 1)
  assert_eq(removed.get_inserted_command_count(), 0)
  assert_eq(removed.get_removed_command_count(), 1)
  assert_true(removed.get_dirty_bounds() == inserted.get_dirty_bounds())
}

///|
test "RenderPipeline diff treats paint shader changes as vector changes" {
  let previous_paint = @graphics.Paint::new().set_shader(
    @graphics.PaintShader::linear_gradient(
      x0=0.0,
      y0=0.0,
      x1=2.0,
      y1=0.0,
      start_color=@graphics.Color::red(),
      end_color=@graphics.Color::blue(),
    ),
  )
  let next_paint = @graphics.Paint::new().set_shader(
    @graphics.PaintShader::linear_gradient(
      x0=0.0,
      y0=0.0,
      x1=2.0,
      y1=0.0,
      start_color=@graphics.Color::red(),
      end_color=@graphics.Color::green(),
    ),
  )
  let previous = RenderPipeline::new().fill_rect(
    0.0, 0.0, 2.0, 1.0, previous_paint,
  )
  let next = RenderPipeline::new().fill_rect(0.0, 0.0, 2.0, 1.0, next_paint)
  let diff = RenderPipeline::diff(previous, next, 4, 2)
  assert_eq(diff.get_retained_command_count(), 0)
  assert_eq(diff.get_changed_command_count(), 1)
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "RenderPipeline diff treats paint filter changes as vector changes" {
  let previous_paint = @graphics.Paint::new().set_filter(
    @graphics.PaintFilter::modulate(@graphics.Color::new(r=255, g=128, b=128)),
  )
  let next_paint = @graphics.Paint::new().set_filter(
    @graphics.PaintFilter::grayscale(),
  )
  let previous = RenderPipeline::new().fill_rect(
    0.0, 0.0, 2.0, 1.0, previous_paint,
  )
  let next = RenderPipeline::new().fill_rect(0.0, 0.0, 2.0, 1.0, next_paint)
  let diff = RenderPipeline::diff(previous, next, 4, 2)
  assert_eq(diff.get_retained_command_count(), 0)
  assert_eq(diff.get_changed_command_count(), 1)
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )
}

///|
test "RenderPipeline diff treats paint blend mode changes as vector changes" {
  let previous_paint = @graphics.Paint::new()
  let next_paint = @graphics.Paint::new().set_blend_mode(
    @graphics.BlendMode::Multiply,
  )
  let previous = RenderPipeline::new().fill_rect(
    1.0, 0.0, 2.0, 1.0, previous_paint,
  )
  let next = RenderPipeline::new().fill_rect(1.0, 0.0, 2.0, 1.0, next_paint)
  let diff = RenderPipeline::diff(previous, next, 4, 2)
  assert_eq(diff.get_retained_command_count(), 0)
  assert_eq(diff.get_changed_command_count(), 1)
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=2, height=1)),
  )
}

///|
test "RenderPipeline diff keeps resource commands conservatively dirty" {
  let icon = @graphics.Pixmap::new(2, 2)
  let previous = RenderPipeline::new().draw_pixmap(
    icon,
    1,
    1,
    @graphics.Paint::new(),
  )
  let next = RenderPipeline::new().draw_pixmap(
    icon,
    1,
    1,
    @graphics.Paint::new(),
  )

  let diff = RenderPipeline::diff(previous, next, 8, 8)
  assert_eq(diff.get_retained_command_count(), 0)
  assert_eq(diff.get_changed_command_count(), 1)
  assert_true(
    diff.get_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=2, height=2)),
  )
}
