///|
test "Paint exposes default configuration getters" {
  let paint = Paint::new()
  assert_eq(paint.get_color(), Color::black())
  assert_true(paint.get_shader() is None)
  assert_true(!paint.has_shader())
  assert_true(paint.get_filter() is None)
  assert_true(!paint.has_filter())
  assert_true(paint.get_style() == PaintStyle::Fill)
  assert_true(paint.get_blend_mode() == BlendMode::SourceOver)
  assert_eq(paint.get_stroke_width(), 1.0)
  assert_true(paint.get_stroke_cap() == StrokeCap::Butt)
  assert_true(paint.get_stroke_join() == StrokeJoin::Miter)
  assert_eq(paint.get_miter_limit(), 4.0)
  assert_true(!paint.has_stroke_dash())
  assert_eq(paint.get_stroke_dash_pattern().length(), 0)
  assert_eq(paint.get_stroke_dash_offset(), 0.0)
  assert_true(paint.get_fill_rule() == FillRule::NonZero)
  assert_eq(paint.get_opacity(), 1.0)
}

///|
test "Paint exposes configured state without leaking dash storage" {
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let filter = PaintFilter::invert()
  let paint = Paint::new()
    .set_color(Color::white())
    .set_shader(shader)
    .set_filter(filter)
    .set_style(PaintStyle::Stroke)
    .set_blend_mode(BlendMode::Multiply)
    .set_stroke_width(3.0)
    .set_stroke_cap(StrokeCap::Round)
    .set_stroke_join(StrokeJoin::Bevel)
    .set_miter_limit(0.25)
    .set_stroke_dash([2.0, -1.0, 3.0], 1.5)
    .set_fill_rule(FillRule::EvenOdd)
    .set_opacity(0.4)

  assert_eq(paint.get_color(), Color::white())
  assert_true(paint.has_shader())
  assert_true(paint.get_shader() is Some(_))
  assert_true(paint.has_filter())
  assert_true(paint.get_filter() is Some(_))
  assert_true(paint.get_style() == PaintStyle::Stroke)
  assert_true(paint.get_blend_mode() == BlendMode::Multiply)
  assert_eq(paint.get_stroke_width(), 3.0)
  assert_true(paint.get_stroke_cap() == StrokeCap::Round)
  assert_true(paint.get_stroke_join() == StrokeJoin::Bevel)
  assert_eq(paint.get_miter_limit(), 1.0)
  assert_true(paint.has_stroke_dash())
  assert_eq(paint.get_stroke_dash_offset(), 1.5)
  assert_true(paint.get_fill_rule() == FillRule::EvenOdd)
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
  let negative = Paint::new().set_color(Color::white()).set_opacity(-1.0)
  assert_eq(negative.get_opacity(), 0.0)
  assert_eq(negative.sample_color(0.0, 0.0).a, 0)

  let high = Paint::new().set_color(Color::white()).set_opacity(2.0)
  assert_eq(high.get_opacity(), 1.0)
  assert_eq(high.sample_color(0.0, 0.0).a, 255)

  let nan = Paint::new().set_color(Color::white()).set_opacity(0.0 / 0.0)
  assert_eq(nan.get_opacity(), 0.0)
  assert_eq(nan.sample_color(0.0, 0.0).a, 0)
}

///|
test "Paint normalizes stroke width metadata" {
  let zero = Paint::new().set_stroke_width(0.0)
  assert_eq(zero.get_stroke_width(), 0.0)

  let negative = Paint::new().set_stroke_width(-3.0)
  assert_eq(negative.get_stroke_width(), 0.0)

  let nan = Paint::new().set_stroke_width(0.0 / 0.0)
  assert_eq(nan.get_stroke_width(), 0.0)

  let positive = Paint::new().set_stroke_width(2.5)
  assert_eq(positive.get_stroke_width(), 2.5)

  ignore(negative.set_dotted_stroke())
  assert_eq(negative.get_stroke_width(), 0.0)
  assert_true(negative.get_stroke_cap() == StrokeCap::Round)
  let dash = negative.get_stroke_dash_pattern()
  assert_eq(dash.length(), 2)
  assert_eq(dash[0], 0.0001)
  assert_eq(dash[1], 0.0001)
}
