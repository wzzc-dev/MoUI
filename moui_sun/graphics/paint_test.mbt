///|
test "Paint exposes default configuration getters" {
  let paint = @graphics.Paint::new()
  assert_eq(paint.get_color(), @graphics.Color::black())
  assert_true(paint.get_shader() is None)
  assert_true(!paint.has_shader())
  assert_true(paint.get_filter() is None)
  assert_true(!paint.has_filter())
  assert_true(paint.get_style() == Fill)
  assert_true(paint.get_blend_mode() == SourceOver)
  assert_eq(paint.get_stroke_width(), 1.0)
  assert_true(paint.get_stroke_cap() == Butt)
  assert_true(paint.get_stroke_join() == Miter)
  assert_eq(paint.get_miter_limit(), 4.0)
  assert_true(!paint.has_stroke_dash())
  assert_eq(paint.get_stroke_dash_pattern().length(), 0)
  assert_eq(paint.get_stroke_dash_offset(), 0.0)
  assert_true(paint.get_fill_rule() == NonZero)
  assert_eq(paint.get_opacity(), 1.0)
}

///|
test "Paint exposes configured state without leaking dash storage" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let filter = @graphics.PaintFilter::invert()
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::white())
    .set_shader(shader)
    .set_filter(filter)
    .set_style(Stroke)
    .set_blend_mode(Multiply)
    .set_stroke_width(3.0)
    .set_stroke_cap(Round)
    .set_stroke_join(Bevel)
    .set_miter_limit(0.25)
    .set_stroke_dash([2.0, -1.0, 3.0], 1.5)
    .set_fill_rule(EvenOdd)
    .set_opacity(0.4)

  assert_eq(paint.get_color(), @graphics.Color::white())
  assert_true(paint.has_shader())
  assert_true(paint.get_shader() is Some(_))
  assert_true(paint.has_filter())
  assert_true(paint.get_filter() is Some(_))
  assert_true(paint.get_style() == Stroke)
  assert_true(paint.get_blend_mode() == Multiply)
  assert_eq(paint.get_stroke_width(), 3.0)
  assert_true(paint.get_stroke_cap() == Round)
  assert_true(paint.get_stroke_join() == Bevel)
  assert_eq(paint.get_miter_limit(), 1.0)
  assert_true(paint.has_stroke_dash())
  assert_eq(paint.get_stroke_dash_offset(), 1.5)
  assert_true(paint.get_fill_rule() == EvenOdd)
  assert_eq(paint.get_opacity(), 0.4)
  assert_eq(paint.sample_color(0.0, 0.0).a, 102)

  let dash = paint.get_stroke_dash_pattern()
  assert_eq(dash.length(), 2)
  assert_eq(dash[0], 2.0)
  assert_eq(dash[1], 3.0)
  dash[0] = 100.0
  let fresh = paint.get_stroke_dash_pattern()
  assert_eq(fresh[0], 2.0)
  assert_eq(fresh[1], 3.0)

  ignore(paint.clear_shader().clear_filter().clear_stroke_dash())
  assert_true(!paint.has_shader())
  assert_true(!paint.has_filter())
  assert_true(!paint.has_stroke_dash())
  assert_eq(paint.get_stroke_dash_pattern().length(), 0)
  assert_eq(paint.get_stroke_dash_offset(), 0.0)
}

///|
test "Paint normalizes opacity metadata and sampled alpha" {
  let negative = @graphics.Paint::new()
    .set_color(@graphics.Color::white())
    .set_opacity(-1.0)
  assert_eq(negative.get_opacity(), 0.0)
  assert_eq(negative.sample_color(0.0, 0.0).a, 0)

  let high = @graphics.Paint::new()
    .set_color(@graphics.Color::white())
    .set_opacity(2.0)
  assert_eq(high.get_opacity(), 1.0)
  assert_eq(high.sample_color(0.0, 0.0).a, 255)

  let nan = @graphics.Paint::new()
    .set_color(@graphics.Color::white())
    .set_opacity(0.0 / 0.0)
  assert_eq(nan.get_opacity(), 0.0)
  assert_eq(nan.sample_color(0.0, 0.0).a, 0)
}

///|
test "Paint normalizes stroke width metadata" {
  let zero = @graphics.Paint::new().set_stroke_width(0.0)
  assert_eq(zero.get_stroke_width(), 0.0)

  let negative = @graphics.Paint::new().set_stroke_width(-3.0)
  assert_eq(negative.get_stroke_width(), 0.0)

  let nan = @graphics.Paint::new().set_stroke_width(0.0 / 0.0)
  assert_eq(nan.get_stroke_width(), 0.0)

  let positive = @graphics.Paint::new().set_stroke_width(2.5)
  assert_eq(positive.get_stroke_width(), 2.5)

  ignore(negative.set_dotted_stroke())
  assert_eq(negative.get_stroke_width(), 0.0)
  assert_true(negative.get_stroke_cap() == Round)
  let dash = negative.get_stroke_dash_pattern()
  assert_eq(dash.length(), 2)
  assert_eq(dash[0], 0.0001)
  assert_eq(dash[1], 0.0001)
}
