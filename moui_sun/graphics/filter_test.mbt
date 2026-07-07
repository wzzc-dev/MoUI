///|
test "PaintFilter::modulate multiplies straight-alpha channels" {
  let filter = PaintFilter::modulate(Color::new(r=128, g=255, b=0, a=128))
  let color = Color::new(r=200, g=100, b=50, a=200)
  assert_eq(filter.apply(color), Color::new(r=100, g=100, b=0, a=100))
}

///|
test "PaintFilter::grayscale preserves alpha" {
  let filter = PaintFilter::grayscale()
  assert_eq(filter.apply(Color::red()), Color::new(r=77, g=77, b=77))
  assert_eq(
    filter.apply(Color::new(r=10, g=20, b=30, a=64)),
    Color::new(r=18, g=18, b=18, a=64),
  )
}

///|
test "PaintFilter::invert preserves alpha" {
  let filter = PaintFilter::invert()
  assert_eq(
    filter.apply(Color::new(r=10, g=20, b=30, a=64)),
    Color::new(r=245, g=235, b=225, a=64),
  )
}

///|
test "PaintFilter::brightness scales RGB and preserves alpha" {
  let brighter = PaintFilter::brightness(1.25)
  assert_eq(
    brighter.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=250, g=125, b=63, a=64),
  )

  let darker = PaintFilter::brightness(0.5)
  assert_eq(
    darker.apply(Color::new(r=200, g=101, b=50, a=64)),
    Color::new(r=100, g=51, b=25, a=64),
  )

  let clipped = PaintFilter::brightness(3.0)
  assert_eq(
    clipped.apply(Color::new(r=100, g=120, b=200, a=64)),
    Color::new(r=255, g=255, b=255, a=64),
  )

  let negative = PaintFilter::brightness(-1.0)
  assert_true(negative.get_stage_factor(0) == Some(0.0))
  assert_eq(
    negative.apply(Color::new(r=100, g=120, b=200, a=64)),
    Color::new(r=0, g=0, b=0, a=64),
  )

  let nan = PaintFilter::brightness(0.0 / 0.0)
  assert_true(nan.get_stage_factor(0) == Some(1.0))
  assert_eq(
    nan.apply(Color::new(r=100, g=120, b=200, a=64)),
    Color::new(r=100, g=120, b=200, a=64),
  )
}

///|
test "PaintFilter::contrast scales RGB around mid-gray and preserves alpha" {
  let stronger = PaintFilter::contrast(2.0)
  assert_eq(
    stronger.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=255, g=72, b=0, a=64),
  )

  let softer = PaintFilter::contrast(0.5)
  assert_eq(
    softer.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=164, g=114, b=89, a=64),
  )

  let negative = PaintFilter::contrast(-1.0)
  assert_true(negative.get_stage_factor(0) == Some(0.0))
  assert_eq(
    negative.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=128, g=128, b=128, a=64),
  )

  let nan = PaintFilter::contrast(0.0 / 0.0)
  assert_true(nan.get_stage_factor(0) == Some(1.0))
  assert_eq(
    nan.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=200, g=100, b=50, a=64),
  )
}

///|
test "PaintFilter::saturate scales RGB around luminance and preserves alpha" {
  let grayscale = PaintFilter::saturate(0.0)
  assert_eq(
    grayscale.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=124, g=124, b=124, a=64),
  )

  let softer = PaintFilter::saturate(0.5)
  assert_eq(
    softer.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=162, g=112, b=87, a=64),
  )

  let identity = PaintFilter::saturate(1.0)
  assert_eq(
    identity.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=200, g=100, b=50, a=64),
  )

  let clipped = PaintFilter::saturate(2.0)
  assert_eq(
    clipped.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=255, g=76, b=0, a=64),
  )

  let negative = PaintFilter::saturate(-1.0)
  assert_true(negative.get_stage_factor(0) == Some(0.0))
  assert_eq(
    negative.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=124, g=124, b=124, a=64),
  )

  let nan = PaintFilter::saturate(0.0 / 0.0)
  assert_true(nan.get_stage_factor(0) == Some(1.0))
  assert_eq(
    nan.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=200, g=100, b=50, a=64),
  )
}

///|
test "PaintFilter::sepia maps RGB through a warm tone matrix and preserves alpha" {
  let filter = PaintFilter::sepia()
  assert_eq(
    filter.apply(Color::new(r=200, g=100, b=50, a=64)),
    Color::new(r=165, g=147, b=114, a=64),
  )
  assert_eq(filter.apply(Color::white()), Color::new(r=255, g=255, b=239))
  assert_eq(
    filter.apply(Color::new(r=0, g=0, b=0, a=42)),
    Color::new(r=0, g=0, b=0, a=42),
  )
}

///|
test "PaintFilter::color_matrix applies copied RGBA matrix" {
  let matrix = [
    0.0, 1.0, 0.0, 0.0, 10.0, 0.0, 0.0, 1.0, 0.0, -20.0, 1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.5, 0.0,
  ]
  let filter = PaintFilter::color_matrix(matrix)
  matrix[4] = 100.0
  assert_eq(
    filter.apply(Color::new(r=100, g=50, b=25, a=200)),
    Color::new(r=60, g=5, b=100, a=100),
  )
}

///|
test "PaintFilter::color_matrix can synthesize alpha from transparent input" {
  let filter = PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 128.0,
  ])
  assert_eq(
    filter.apply(Color::transparent()),
    Color::new(r=0, g=0, b=0, a=128),
  )
  assert_eq(
    Paint::new()
    .set_color(Color::transparent())
    .set_filter(filter)
    .set_opacity(0.5)
    .sample_color(0.0, 0.0),
    Color::new(r=0, g=0, b=0, a=64),
  )
}

///|
test "PaintFilter::color_matrix clamps output and falls back to identity" {
  let clipped = PaintFilter::color_matrix([
    2.0,
    0.0,
    0.0,
    0.0,
    20.0,
    0.0,
    -1.0,
    0.0,
    0.0,
    10.0,
    0.0,
    0.0,
    1.0,
    0.0,
    0.0 / 0.0,
    0.0,
    0.0,
    0.0,
    2.0,
    0.0,
  ])
  assert_eq(
    clipped.apply(Color::new(r=140, g=50, b=25, a=160)),
    Color::new(r=255, g=0, b=25, a=255),
  )

  let identity = PaintFilter::color_matrix([1.0, 0.0, 0.0])
  assert_eq(
    identity.apply(Color::new(r=10, g=20, b=30, a=40)),
    Color::new(r=10, g=20, b=30, a=40),
  )
}

///|
test "PaintFilter::color_matrix exposes normalized matrix metadata" {
  let matrix = [
    1.0,
    0.0 / 0.0,
    0.0,
    0.0,
    5.0,
    0.0,
    1.0,
    0.0 / 0.0,
    0.0,
    -7.0,
    0.0,
    0.0,
    1.0,
    0.0,
    11.0,
    0.0 / 0.0,
    0.0,
    0.0,
    1.0,
    13.0,
  ]
  let filter = PaintFilter::color_matrix(matrix)
  assert_true(!filter.is_identity())
  assert_eq(filter.get_filter_count(), 1)
  assert_true(filter.get_stage_type(0) == Some(PaintFilterType::ColorMatrix))
  assert_true(filter.get_stage_color(0) is None)
  assert_true(filter.get_stage_factor(0) is None)
  match filter.get_stage_color_matrix(0) {
    Some(copied) => {
      assert_eq(copied.length(), 20)
      assert_eq(copied[0], 1.0)
      assert_eq(copied[1], 0.0)
      assert_eq(copied[4], 5.0)
      assert_eq(copied[7], 0.0)
      assert_eq(copied[9], -7.0)
      assert_eq(copied[14], 11.0)
      assert_eq(copied[15], 0.0)
      assert_eq(copied[19], 13.0)
      copied[4] = 100.0
    }
    None => abort("expected normalized color matrix metadata")
  }
  match filter.get_stage_color_matrix(0) {
    Some(fresh) => assert_eq(fresh[4], 5.0)
    None => abort("expected fresh normalized color matrix metadata")
  }

  let identity_stage = PaintFilter::color_matrix([1.0, 0.0, 0.0])
  assert_true(!identity_stage.is_identity())
  assert_eq(identity_stage.get_filter_count(), 1)
  assert_true(
    identity_stage.get_stage_type(0) == Some(PaintFilterType::ColorMatrix),
  )
  match identity_stage.get_stage_color_matrix(0) {
    Some(identity) => {
      assert_eq(identity.length(), 20)
      assert_eq(identity[0], 1.0)
      assert_eq(identity[1], 0.0)
      assert_eq(identity[6], 1.0)
      assert_eq(identity[12], 1.0)
      assert_eq(identity[18], 1.0)
      assert_eq(identity[19], 0.0)
    }
    None => abort("expected identity color matrix metadata")
  }
}

///|
test "PaintFilter::color_matrix normalizes short and long payloads" {
  let short = PaintFilter::color_matrix([0.25, 0.5])
  match short.get_stage_color_matrix(0) {
    Some(matrix) => {
      assert_eq(matrix.length(), 20)
      assert_eq(matrix[0], 0.25)
      assert_eq(matrix[1], 0.5)
      assert_eq(matrix[6], 1.0)
      assert_eq(matrix[12], 1.0)
      assert_eq(matrix[18], 1.0)
      assert_eq(matrix[19], 0.0)
    }
    None => abort("expected short color matrix metadata")
  }
  assert_eq(
    short.apply(Color::new(r=40, g=80, b=20, a=200)),
    Color::new(r=50, g=80, b=20, a=200),
  )

  let long = PaintFilter::color_matrix([
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0,
  ])
  match long.get_stage_color_matrix(0) {
    Some(matrix) => {
      assert_eq(matrix.length(), 20)
      assert_eq(matrix[0], 0.0)
      assert_eq(matrix[18], 18.0)
      assert_eq(matrix[19], 19.0)
    }
    None => abort("expected long color matrix metadata")
  }
}

///|
test "PaintFilter chains apply filters in order" {
  let color = Color::new(r=10, g=20, b=30, a=64)
  let chain = PaintFilter::invert().then(PaintFilter::brightness(0.5))
  assert_eq(chain.get_filter_count(), 2)
  assert_eq(chain.apply(color), Color::new(r=123, g=118, b=113, a=64))

  let reversed = PaintFilter::brightness(0.5).then(PaintFilter::invert())
  assert_eq(reversed.apply(color), Color::new(r=250, g=245, b=240, a=64))

  let composed = PaintFilter::compose(
    PaintFilter::grayscale(),
    PaintFilter::invert(),
  )
  assert_eq(composed.get_filter_count(), 2)
  assert_eq(composed.apply(Color::red()), Color::new(r=178, g=178, b=178))
}

///|
test "PaintFilter identity composes as an empty stage chain" {
  let color = Color::new(r=10, g=20, b=30, a=64)
  let identity = PaintFilter::identity()
  assert_true(identity.is_identity())
  assert_eq(identity.get_filter_count(), 0)
  assert_true(identity.get_stage_type(0) is None)
  assert_true(identity.get_stage_color(0) is None)
  assert_true(identity.get_stage_factor(0) is None)
  assert_true(identity.get_stage_color_matrix(0) is None)
  assert_eq(identity.apply(color), color)

  let invert = PaintFilter::invert()
  let left = identity.then(invert)
  assert_true(!left.is_identity())
  assert_eq(left.get_filter_count(), 1)
  assert_true(left.get_stage_type(0) == Some(PaintFilterType::Invert))
  assert_eq(left.apply(color), invert.apply(color))

  let right = invert.then(identity)
  assert_eq(right.get_filter_count(), 1)
  assert_true(right.get_stage_type(0) == Some(PaintFilterType::Invert))
  assert_eq(right.apply(color), invert.apply(color))

  let composed = PaintFilter::compose(identity, PaintFilter::brightness(0.5))
  assert_eq(composed.get_filter_count(), 1)
  assert_true(composed.get_stage_type(0) == Some(PaintFilterType::Brightness))
  assert_true(composed.get_stage_factor(0) == Some(0.5))

  let paint = Paint::new().set_color(color).set_filter(identity)
  match paint.get_filter() {
    Some(filter) => assert_true(filter.is_identity())
    None => abort("expected configured identity filter")
  }
  assert_eq(paint.sample_color(0.0, 0.0), color)
}

///|
test "PaintFilter chains copy source filters" {
  let first = PaintFilter::invert()
  let second = PaintFilter::brightness(0.5)
  let chain = first.then(second)
  assert_eq(first.get_filter_count(), 1)
  assert_eq(second.get_filter_count(), 1)
  assert_eq(chain.get_filter_count(), 2)
  assert_eq(
    first.apply(Color::new(r=10, g=20, b=30, a=64)),
    Color::new(r=245, g=235, b=225, a=64),
  )
}

///|
test "PaintFilter exposes stage metadata and copied matrix parameters" {
  let matrix = [
    1.0, 0.0, 0.0, 0.0, 10.0, 0.0, 1.0, 0.0, 0.0, 20.0, 0.0, 0.0, 1.0, 0.0, 30.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ]
  let filter = PaintFilter::modulate(Color::new(r=128, g=64, b=32, a=255))
    .then(PaintFilter::brightness(0.5))
    .then(PaintFilter::contrast(1.25))
    .then(PaintFilter::saturate(0.75))
    .then(PaintFilter::sepia())
    .then(PaintFilter::color_matrix(matrix))
    .then(PaintFilter::grayscale())
    .then(PaintFilter::invert())

  assert_eq(filter.get_filter_count(), 8)
  assert_true(filter.get_stage_type(0) == Some(PaintFilterType::Modulate))
  assert_true(filter.get_stage_type(1) == Some(PaintFilterType::Brightness))
  assert_true(filter.get_stage_type(2) == Some(PaintFilterType::Contrast))
  assert_true(filter.get_stage_type(3) == Some(PaintFilterType::Saturate))
  assert_true(filter.get_stage_type(4) == Some(PaintFilterType::Sepia))
  assert_true(filter.get_stage_type(5) == Some(PaintFilterType::ColorMatrix))
  assert_true(filter.get_stage_type(6) == Some(PaintFilterType::Grayscale))
  assert_true(filter.get_stage_type(7) == Some(PaintFilterType::Invert))
  assert_true(filter.get_stage_type(-1) is None)
  assert_true(filter.get_stage_type(8) is None)

  assert_true(
    filter.get_stage_color(0) == Some(Color::new(r=128, g=64, b=32, a=255)),
  )
  assert_true(filter.get_stage_color(1) is None)
  assert_true(filter.get_stage_factor(1) == Some(0.5))
  assert_true(filter.get_stage_factor(2) == Some(1.25))
  assert_true(filter.get_stage_factor(3) == Some(0.75))
  assert_true(filter.get_stage_factor(4) is None)

  match filter.get_stage_color_matrix(5) {
    Some(copied) => {
      assert_eq(copied.length(), 20)
      assert_eq(copied[4], 10.0)
      copied[4] = 100.0
    }
    None => abort("expected copied color matrix")
  }
  match filter.get_stage_color_matrix(5) {
    Some(fresh) => assert_eq(fresh[4], 10.0)
    None => abort("expected fresh color matrix")
  }
  assert_true(filter.get_stage_color_matrix(4) is None)
}

///|
test "Paint filter applies before opacity and can be cleared" {
  let filter = PaintFilter::modulate(Color::new(r=128, g=255, b=255, a=128))
  let paint = Paint::new()
    .set_color(Color::new(r=100, g=50, b=0, a=200))
    .set_filter(filter)
    .set_opacity(0.5)
  assert_true(paint.get_filter() is Some(_))
  assert_eq(paint.sample_color(0.0, 0.0), Color::new(r=50, g=50, b=0, a=50))

  ignore(paint.clear_filter())
  assert_true(paint.get_filter() is None)
  assert_eq(paint.sample_color(0.0, 0.0), Color::new(r=100, g=50, b=0, a=100))
}

///|
test "Paint filter applies to shader samples" {
  let shader = PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=Color::red(),
    end_color=Color::blue(),
  )
  let paint = Paint::new()
    .set_shader(shader)
    .set_filter(PaintFilter::modulate(Color::new(r=128, g=255, b=255)))
  assert_eq(paint.sample_color(0.0, 0.0), Color::new(r=128, g=0, b=0))
  assert_eq(paint.sample_color(1.0, 0.0), Color::blue())
}

///|
test "Paint filter chains apply through Paint and Canvas fill" {
  let filter = PaintFilter::invert().then(PaintFilter::brightness(0.5))
  let paint = Paint::new()
    .set_color(Color::new(r=10, g=20, b=30, a=200))
    .set_filter(filter)
    .set_opacity(0.5)
  assert_eq(
    paint.sample_color(0.0, 0.0),
    Color::new(r=123, g=118, b=113, a=100),
  )

  let canvas = Canvas::new(1, 1)
  canvas.fill_rect(
    0.0,
    0.0,
    1.0,
    1.0,
    Paint::new().set_color(Color::new(r=10, g=20, b=30)).set_filter(filter),
  )
  assert_eq(
    canvas.get_pixmap().get_pixel(0, 0),
    Color::new(r=123, g=118, b=113),
  )
}
