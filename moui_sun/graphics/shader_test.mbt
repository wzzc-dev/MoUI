///|
test "PaintShader::linear_gradient samples and clamps device coordinates" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(shader.sample(-10.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(0.0, 4.0), @graphics.Color::red())
  assert_eq(
    shader.sample(1.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::blue())
  assert_eq(shader.sample(10.0, 0.0), @graphics.Color::blue())
}

///|
test "PaintShader::linear_gradient handles degenerate vectors" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=1.0,
    y0=1.0,
    x1=1.0,
    y1=1.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(shader.sample(10.0, 10.0), @graphics.Color::red())
}

///|
test "PaintShader::linear_gradient supports repeat and mirror spread" {
  let repeated = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Repeat,
  )
  assert_eq(repeated.sample(2.0, 0.0), @graphics.Color::red())
  assert_eq(
    repeated.sample(3.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(
    repeated.sample(-1.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )

  let mirrored = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Mirror,
  )
  assert_eq(mirrored.sample(2.0, 0.0), @graphics.Color::blue())
  assert_eq(
    mirrored.sample(3.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(mirrored.sample(4.0, 0.0), @graphics.Color::red())
  assert_eq(
    mirrored.sample(-1.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
}

///|
test "PaintShader::linear_gradient supports decal spread" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  assert_eq(shader.sample(-1.0, 0.0), @graphics.Color::transparent())
  assert_eq(
    shader.sample(1.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(shader.sample(3.0, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader::linear_gradient handles non-finite spread coordinates" {
  let positive_infinity = 1.0 / 0.0
  let negative_infinity = 0.0 - positive_infinity
  let nan = 0.0 / 0.0
  let clamped = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(clamped.sample(positive_infinity, 0.0), @graphics.Color::blue())
  assert_eq(clamped.sample(negative_infinity, 0.0), @graphics.Color::red())
  assert_eq(clamped.sample(nan, 0.0), @graphics.Color::red())

  let repeated = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Repeat,
  )
  assert_eq(repeated.sample(positive_infinity, 0.0), @graphics.Color::red())
  assert_eq(repeated.sample(negative_infinity, 0.0), @graphics.Color::red())
  assert_eq(repeated.sample(nan, 0.0), @graphics.Color::red())

  let mirrored = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Mirror,
  )
  assert_eq(mirrored.sample(positive_infinity, 0.0), @graphics.Color::red())
  assert_eq(mirrored.sample(negative_infinity, 0.0), @graphics.Color::red())
  assert_eq(mirrored.sample(nan, 0.0), @graphics.Color::red())

  let decal = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  assert_eq(
    decal.sample(positive_infinity, 0.0),
    @graphics.Color::transparent(),
  )
  assert_eq(
    decal.sample(negative_infinity, 0.0),
    @graphics.Color::transparent(),
  )
  assert_eq(decal.sample(nan, 0.0), @graphics.Color::red())
}

///|
test "PaintShader::transformed samples local shader coordinates" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  ).transformed(@graphics.Transform::translate(tx=10.0, ty=0.0))
  assert_eq(shader.sample(10.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(11.0, 0.0), @graphics.Color::new(r=128, g=0, b=128))
  assert_eq(shader.sample(12.0, 0.0), @graphics.Color::blue())

  let scaled = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  ).transformed(@graphics.Transform::scale(sx=2.0, sy=1.0))
  assert_eq(scaled.sample(1.0, 0.0), @graphics.Color::new(r=128, g=0, b=128))
}

///|
test "PaintShader::transformed composes and rejects singular transforms" {
  let shader = @graphics.PaintShader::linear_gradient(
      x0=0.0,
      y0=0.0,
      x1=1.0,
      y1=0.0,
      start_color=@graphics.Color::red(),
      end_color=@graphics.Color::blue(),
    )
    .transformed(@graphics.Transform::translate(tx=1.0, ty=0.0))
    .transformed(@graphics.Transform::scale(sx=2.0, sy=1.0))
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(3.0, 0.0), @graphics.Color::new(r=128, g=0, b=128))

  let singular = shader.transformed(@graphics.Transform::scale(sx=0.0, sy=1.0))
  assert_eq(singular.sample(3.0, 0.0), @graphics.Color::transparent())
  assert_eq(
    singular
    .transformed(@graphics.Transform::translate(tx=1.0, ty=0.0))
    .sample(3.0, 0.0),
    @graphics.Color::transparent(),
  )
}

///|
test "PaintShader exposes metadata for pipeline planning" {
  let linear = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Mirror,
  )
  assert_true(linear.get_type() == LinearGradient)
  assert_true(linear.get_spread() == Mirror)
  assert_eq(linear.get_gradient_stop_count(), 2)
  assert_true(linear.is_sampleable())
  assert_true(!linear.has_local_transform())

  let radial = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=1.0,
    stops=[],
    spread=Decal,
  )
  assert_true(radial.get_type() == RadialGradient)
  assert_true(radial.get_spread() == Decal)
  assert_eq(radial.get_gradient_stop_count(), 0)

  let sweep = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
    spread=Repeat,
  )
  assert_true(sweep.get_type() == SweepGradient)
  assert_true(sweep.get_spread() == Repeat)
  assert_eq(sweep.get_gradient_stop_count(), 2)

  let moved = linear.transformed(@graphics.Transform::translate(tx=3.0, ty=0.0))
  assert_true(moved.is_sampleable())
  assert_true(moved.has_local_transform())
  assert_true(
    moved.get_local_from_device_transform() ==
    Some(@graphics.Transform::translate(tx=-3.0, ty=0.0)),
  )
  assert_true(moved.get_type() == LinearGradient)
  assert_true(moved.get_spread() == Mirror)
  assert_eq(moved.get_gradient_stop_count(), 2)

  let singular = linear.transformed(@graphics.Transform::scale(sx=0.0, sy=1.0))
  assert_true(!singular.is_sampleable())
  assert_true(!singular.has_local_transform())
  assert_true(singular.get_local_from_device_transform() is None)
  assert_true(singular.get_type() == LinearGradient)
  assert_true(singular.get_spread() == Mirror)
  assert_eq(singular.sample(0.0, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader exposes composed local-from-device transform" {
  let shader = @graphics.PaintShader::linear_gradient(
      x0=0.0,
      y0=0.0,
      x1=1.0,
      y1=0.0,
      start_color=@graphics.Color::red(),
      end_color=@graphics.Color::blue(),
    )
    .transformed(@graphics.Transform::translate(tx=3.0, ty=4.0))
    .transformed(@graphics.Transform::scale(sx=2.0, sy=4.0))
  assert_true(shader.has_local_transform())
  match shader.get_local_from_device_transform() {
    Some(transform) => {
      assert_true(
        transform ==
        @graphics.Transform::translate(tx=-3.0, ty=-4.0).multiply(
          @graphics.Transform::scale(sx=0.5, sy=0.25),
        ),
      )
      assert_true(transform.apply(4.0, 8.0) == (-1.0, -2.0))
    }
    None => abort("expected local-from-device transform")
  }

  let base = @graphics.PaintShader::radial_gradient(
    cx=0.0,
    cy=0.0,
    radius=1.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(base.get_local_from_device_transform() is None)

  let no_op = base.transformed(@graphics.Transform::identity())
  assert_true(no_op.is_sampleable())
  assert_true(!no_op.has_local_transform())
  assert_true(no_op.get_local_from_device_transform() is None)
  assert_eq(no_op.sample(0.0, 0.0), base.sample(0.0, 0.0))

  let canceled = base
    .transformed(@graphics.Transform::translate(tx=3.0, ty=4.0))
    .transformed(@graphics.Transform::translate(tx=-3.0, ty=-4.0))
  assert_true(canceled.is_sampleable())
  assert_true(!canceled.has_local_transform())
  assert_true(canceled.get_local_from_device_transform() is None)
  assert_eq(canceled.sample(0.0, 0.0), base.sample(0.0, 0.0))
}

///|
test "PaintShader exposes local gradient geometry metadata" {
  let linear = @graphics.PaintShader::linear_gradient(
    x0=-1.0,
    y0=2.0,
    x1=3.0,
    y1=4.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(
    linear.get_linear_gradient_points() ==
    Some(
      (@graphics.Point::new(x=-1.0, y=2.0), @graphics.Point::new(x=3.0, y=4.0)),
    ),
  )
  assert_true(linear.get_radial_gradient_circle() is None)
  assert_true(linear.get_sweep_gradient_geometry() is None)

  let linear_stops = @graphics.PaintShader::linear_gradient_stops(
    x0=5.0,
    y0=6.0,
    x1=7.0,
    y1=8.0,
    stops=[],
  )
  assert_true(
    linear_stops.get_linear_gradient_points() ==
    Some(
      (@graphics.Point::new(x=5.0, y=6.0), @graphics.Point::new(x=7.0, y=8.0)),
    ),
  )

  let moved = linear.transformed(
    @graphics.Transform::translate(tx=10.0, ty=20.0),
  )
  assert_true(moved.has_local_transform())
  assert_true(
    moved.get_linear_gradient_points() ==
    Some(
      (@graphics.Point::new(x=-1.0, y=2.0), @graphics.Point::new(x=3.0, y=4.0)),
    ),
  )

  let singular = linear.transformed(@graphics.Transform::scale(sx=0.0, sy=1.0))
  assert_true(!singular.is_sampleable())
  assert_true(
    singular.get_linear_gradient_points() ==
    Some(
      (@graphics.Point::new(x=-1.0, y=2.0), @graphics.Point::new(x=3.0, y=4.0)),
    ),
  )

  let degenerate_linear = @graphics.PaintShader::linear_gradient(
    x0=9.0,
    y0=10.0,
    x1=9.0,
    y1=10.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(
    degenerate_linear.get_linear_gradient_points() ==
    Some(
      (@graphics.Point::new(x=9.0, y=10.0), @graphics.Point::new(x=9.0, y=10.0)),
    ),
  )

  let radial = @graphics.PaintShader::radial_gradient(
    cx=1.0,
    cy=2.0,
    radius=3.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(
    radial.get_radial_gradient_circle() ==
    Some((@graphics.Point::new(x=1.0, y=2.0), 3.0)),
  )
  assert_true(radial.get_linear_gradient_points() is None)
  assert_true(radial.get_sweep_gradient_geometry() is None)

  let radial_stops = @graphics.PaintShader::radial_gradient_stops(
    cx=4.0,
    cy=5.0,
    radius=6.0,
    stops=[],
  )
  assert_true(
    radial_stops.get_radial_gradient_circle() ==
    Some((@graphics.Point::new(x=4.0, y=5.0), 6.0)),
  )

  let degenerate_radial = @graphics.PaintShader::radial_gradient(
    cx=7.0,
    cy=8.0,
    radius=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(
    degenerate_radial.get_radial_gradient_circle() ==
    Some((@graphics.Point::new(x=7.0, y=8.0), 0.0)),
  )
  let negative_radial = @graphics.PaintShader::radial_gradient(
    cx=9.0,
    cy=10.0,
    radius=-1.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(
    negative_radial.get_radial_gradient_circle() ==
    Some((@graphics.Point::new(x=9.0, y=10.0), 0.0)),
  )
  let nan_radial = @graphics.PaintShader::radial_gradient(
    cx=11.0,
    cy=12.0,
    radius=0.0 / 0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_true(
    nan_radial.get_radial_gradient_circle() ==
    Some((@graphics.Point::new(x=11.0, y=12.0), 0.0)),
  )
  let tiny_radial_stops = @graphics.PaintShader::radial_gradient_stops(
    cx=13.0,
    cy=14.0,
    radius=0.0000000001,
    stops=[],
  )
  assert_true(
    tiny_radial_stops.get_radial_gradient_circle() ==
    Some((@graphics.Point::new(x=13.0, y=14.0), 0.0)),
  )

  let sweep = @graphics.PaintShader::sweep_gradient(
    cx=1.0,
    cy=2.0,
    start_angle=0.25,
    sweep_angle=-0.5,
    start_color=@graphics.Color::white(),
    end_color=@graphics.Color::black(),
  )
  assert_true(
    sweep.get_sweep_gradient_geometry() ==
    Some((@graphics.Point::new(x=1.0, y=2.0), 0.25, -0.5)),
  )
  assert_true(sweep.get_linear_gradient_points() is None)
  assert_true(sweep.get_radial_gradient_circle() is None)

  let sweep_stops = @graphics.PaintShader::sweep_gradient_stops(
    cx=7.0,
    cy=8.0,
    start_angle=0.5,
    sweep_angle=1.25,
    stops=[],
  )
  assert_true(
    sweep_stops.get_sweep_gradient_geometry() ==
    Some((@graphics.Point::new(x=7.0, y=8.0), 0.5, 1.25)),
  )

  let degenerate_sweep = @graphics.PaintShader::sweep_gradient(
    cx=3.0,
    cy=4.0,
    start_angle=0.75,
    sweep_angle=0.0,
    start_color=@graphics.Color::white(),
    end_color=@graphics.Color::black(),
  )
  assert_true(
    degenerate_sweep.get_sweep_gradient_geometry() ==
    Some((@graphics.Point::new(x=3.0, y=4.0), 0.75, 0.0)),
  )

  let nan_sweep = @graphics.PaintShader::sweep_gradient(
    cx=5.0,
    cy=6.0,
    start_angle=0.0 / 0.0,
    sweep_angle=0.0 / 0.0,
    start_color=@graphics.Color::white(),
    end_color=@graphics.Color::black(),
  )
  assert_true(
    nan_sweep.get_sweep_gradient_geometry() ==
    Some((@graphics.Point::new(x=5.0, y=6.0), 0.0, 0.0)),
  )

  let tiny_sweep_stops = @graphics.PaintShader::sweep_gradient_stops(
    cx=7.0,
    cy=8.0,
    start_angle=-0.25,
    sweep_angle=0.0000000001,
    stops=[],
  )
  assert_true(
    tiny_sweep_stops.get_sweep_gradient_geometry() ==
    Some((@graphics.Point::new(x=7.0, y=8.0), -0.25, 0.0)),
  )
}

///|
test "PaintGradientStop clamps offsets and preserves color" {
  let negative = @graphics.PaintGradientStop::new(
    offset=-2.0,
    color=@graphics.Color::red(),
  )
  assert_eq(negative.get_offset(), 0.0)
  assert_eq(negative.get_color(), @graphics.Color::red())

  let high = @graphics.PaintGradientStop::new(
    offset=3.0,
    color=@graphics.Color::blue(),
  )
  assert_eq(high.get_offset(), 1.0)

  let positive_infinity = 1.0 / 0.0
  let infinity = @graphics.PaintGradientStop::new(
    offset=positive_infinity,
    color=@graphics.Color::blue(),
  )
  assert_eq(infinity.get_offset(), 1.0)

  let negative_infinity = @graphics.PaintGradientStop::new(
    offset=0.0 - positive_infinity,
    color=@graphics.Color::red(),
  )
  assert_eq(negative_infinity.get_offset(), 0.0)

  let nan = @graphics.PaintGradientStop::new(
    offset=0.0 / 0.0,
    color=@graphics.Color::green(),
  )
  assert_eq(nan.get_offset(), 0.0)
}

///|
test "PaintShader exposes copied gradient stop metadata" {
  let linear = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let implicit_stops = linear.get_gradient_stops()
  assert_eq(implicit_stops.length(), 2)
  assert_eq(implicit_stops[0].get_offset(), 0.0)
  assert_eq(implicit_stops[0].get_color(), @graphics.Color::red())
  assert_eq(implicit_stops[1].get_offset(), 1.0)
  assert_eq(implicit_stops[1].get_color(), @graphics.Color::blue())
  assert_true(
    linear.get_gradient_stop(1) ==
    Some(
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ),
  )
  assert_true(linear.get_gradient_stop(-1) is None)
  assert_true(linear.get_gradient_stop(2) is None)

  let source_stops = [
    @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
    @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::green()),
    @graphics.PaintGradientStop::new(offset=1.0, color=@graphics.Color::blue()),
  ]
  let explicit = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=1.0,
    stops=source_stops,
  )
  source_stops[1] = @graphics.PaintGradientStop::new(
    offset=0.5,
    color=@graphics.Color::white(),
  )
  let copied = explicit.get_gradient_stops()
  assert_eq(copied.length(), 3)
  assert_eq(copied[1].get_offset(), 0.5)
  assert_eq(copied[1].get_color(), @graphics.Color::green())
  copied[1] = @graphics.PaintGradientStop::new(
    offset=0.5,
    color=@graphics.Color::black(),
  )
  match explicit.get_gradient_stop(1) {
    Some(fresh) => assert_eq(fresh.get_color(), @graphics.Color::green())
    None => abort("expected copied gradient stop")
  }

  let sweep = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::white(),
    end_color=@graphics.Color::black(),
  )
  assert_eq(sweep.get_gradient_stops()[0].get_color(), @graphics.Color::white())
  assert_eq(sweep.get_gradient_stops()[1].get_color(), @graphics.Color::black())
}

///|
test "PaintShader::linear_gradient_stops samples multi-stop gradients" {
  let shader = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(shader.sample(0.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(1.0, 0.0), @graphics.Color::new(r=128, g=128, b=0))
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::green())
  assert_eq(shader.sample(3.0, 0.0), @graphics.Color::new(r=0, g=128, b=128))
  assert_eq(shader.sample(4.0, 0.0), @graphics.Color::blue())
}

///|
test "PaintShader::linear_gradient_stops samples duplicate-stop hard edges" {
  let shader = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::blue(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(shader.sample(1.999999, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(2.000001, 0.0), @graphics.Color::blue())

  let reversed = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(
        offset=0.0,
        color=@graphics.Color::blue(),
      ),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::blue(),
      ),
      @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(offset=1.0, color=@graphics.Color::red()),
    ],
  )
  assert_eq(reversed.sample(1.999999, 0.0), @graphics.Color::blue())
  assert_eq(reversed.sample(2.0, 0.0), @graphics.Color::blue())
  assert_eq(reversed.sample(2.000001, 0.0), @graphics.Color::red())
}

///|
test "PaintShader radial and sweep gradient stops preserve duplicate-stop hard edges" {
  let stops = [
    @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
    @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::red()),
    @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::blue()),
    @graphics.PaintGradientStop::new(offset=1.0, color=@graphics.Color::blue()),
  ]

  let radial = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=4.0,
    stops~,
  )
  assert_eq(radial.sample(1.999999, 0.0), @graphics.Color::red())
  assert_eq(radial.sample(2.0, 0.0), @graphics.Color::red())
  assert_eq(radial.sample(2.000001, 0.0), @graphics.Color::blue())

  let sweep = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops~,
  )
  assert_eq(sweep.sample(0.000001, 1.0), @graphics.Color::red())
  assert_eq(sweep.sample(0.0, 1.0), @graphics.Color::red())
  assert_eq(sweep.sample(-0.000001, 1.0), @graphics.Color::blue())
}

///|
test "PaintShader::linear_gradient_stops handles unordered and edge stop sets" {
  let unordered = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
    ],
  )
  assert_eq(unordered.sample(-1.0, 0.0), @graphics.Color::red())
  assert_eq(unordered.sample(1.0, 0.0), @graphics.Color::green())
  assert_eq(unordered.sample(3.0, 0.0), @graphics.Color::blue())

  let single = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(
        offset=0.75,
        color=@graphics.Color::green(),
      ),
    ],
  )
  assert_eq(single.sample(-10.0, 0.0), @graphics.Color::green())
  assert_eq(single.sample(10.0, 0.0), @graphics.Color::green())

  let empty = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    stops=[],
  )
  assert_eq(empty.sample(0.5, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader::linear_gradient_stops supports spread and copies stops" {
  let stops = [
    @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
    @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::green()),
    @graphics.PaintGradientStop::new(offset=1.0, color=@graphics.Color::blue()),
  ]
  let repeated = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops~,
    spread=Repeat,
  )
  stops.push(
    @graphics.PaintGradientStop::new(
      offset=0.25,
      color=@graphics.Color::white(),
    ),
  )
  assert_eq(repeated.sample(4.0, 0.0), @graphics.Color::red())
  assert_eq(repeated.sample(5.0, 0.0), @graphics.Color::new(r=128, g=128, b=0))
  assert_eq(repeated.sample(1.0, 0.0), @graphics.Color::new(r=128, g=128, b=0))

  let mirrored = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
    spread=Mirror,
  )
  assert_eq(mirrored.sample(4.0, 0.0), @graphics.Color::blue())
  assert_eq(mirrored.sample(6.0, 0.0), @graphics.Color::new(r=128, g=0, b=128))
  assert_eq(mirrored.sample(8.0, 0.0), @graphics.Color::red())

  let decal = @graphics.PaintShader::linear_gradient_stops(
    x0=0.0,
    y0=0.0,
    x1=4.0,
    y1=0.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
    spread=Decal,
  )
  assert_eq(decal.sample(-1.0, 0.0), @graphics.Color::transparent())
  assert_eq(decal.sample(2.0, 0.0), @graphics.Color::new(r=128, g=0, b=128))
  assert_eq(decal.sample(5.0, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader::radial_gradient samples distance from center" {
  let shader = @graphics.PaintShader::radial_gradient(
    cx=1.0,
    cy=1.0,
    radius=2.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(shader.sample(1.0, 1.0), @graphics.Color::red())
  assert_eq(
    shader.sample(2.0, 1.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(shader.sample(1.0, 3.0), @graphics.Color::blue())
  assert_eq(shader.sample(10.0, 1.0), @graphics.Color::blue())
}

///|
test "PaintShader::radial_gradient handles degenerate radius" {
  let shader = @graphics.PaintShader::radial_gradient(
    cx=1.0,
    cy=1.0,
    radius=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(shader.sample(10.0, 10.0), @graphics.Color::red())
}

///|
test "PaintShader::radial_gradient supports repeat spread" {
  let shader = @graphics.PaintShader::radial_gradient(
    cx=0.0,
    cy=0.0,
    radius=2.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Repeat,
  )
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::red())
  assert_eq(
    shader.sample(3.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
}

///|
test "PaintShader::radial_gradient supports decal spread" {
  let shader = @graphics.PaintShader::radial_gradient(
    cx=0.0,
    cy=0.0,
    radius=2.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  assert_eq(
    shader.sample(1.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(shader.sample(3.0, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader::radial_gradient supports mirror spread" {
  let shader = @graphics.PaintShader::radial_gradient(
    cx=0.0,
    cy=0.0,
    radius=2.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Mirror,
  )
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::blue())
  assert_eq(
    shader.sample(3.0, 0.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
  assert_eq(shader.sample(4.0, 0.0), @graphics.Color::red())
}

///|
test "PaintShader::radial_gradient_stops samples multi-stop gradients" {
  let shader = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=4.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(shader.sample(0.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(1.0, 0.0), @graphics.Color::new(r=128, g=128, b=0))
  assert_eq(shader.sample(2.0, 0.0), @graphics.Color::green())
  assert_eq(shader.sample(3.0, 0.0), @graphics.Color::new(r=0, g=128, b=128))
  assert_eq(shader.sample(4.0, 0.0), @graphics.Color::blue())
}

///|
test "PaintShader::radial_gradient_stops handles spread and degenerate radius" {
  let repeated = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=4.0,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
    spread=Repeat,
  )
  assert_eq(repeated.sample(4.0, 0.0), @graphics.Color::red())
  assert_eq(repeated.sample(5.0, 0.0), @graphics.Color::new(r=128, g=128, b=0))

  let degenerate = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=0.0,
    stops=[
      @graphics.PaintGradientStop::new(
        offset=0.25,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(degenerate.sample(100.0, 0.0), @graphics.Color::green())

  let empty = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=1.0,
    stops=[],
  )
  assert_eq(empty.sample(0.0, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader::sweep_gradient samples angles around a center" {
  let shader = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(shader.sample(1.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(0.0, 1.0), @graphics.Color::new(r=128, g=0, b=128))
  assert_eq(shader.sample(-1.0, 0.0), @graphics.Color::blue())
  assert_eq(shader.sample(0.0, -1.0), @graphics.Color::blue())
}

///|
test "PaintShader::sweep_gradient supports repeat and negative sweeps" {
  let repeated = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Repeat,
  )
  assert_eq(repeated.sample(-1.0, 0.0), @graphics.Color::red())
  assert_eq(repeated.sample(0.0, -1.0), @graphics.Color::new(r=128, g=0, b=128))

  let decal = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  )
  assert_eq(decal.sample(0.0, 1.0), @graphics.Color::new(r=128, g=0, b=128))
  assert_eq(decal.sample(0.0, -1.0), @graphics.Color::transparent())

  let reversed = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=-@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(reversed.sample(1.0, 0.0), @graphics.Color::red())
  assert_eq(reversed.sample(0.0, -1.0), @graphics.Color::new(r=128, g=0, b=128))
  assert_eq(reversed.sample(-1.0, 0.0), @graphics.Color::blue())
}

///|
test "PaintShader::sweep_gradient supports mirror spread" {
  let shader = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Mirror,
  )
  assert_eq(shader.sample(1.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(-1.0, 0.0), @graphics.Color::blue())
  assert_eq(
    shader.sample(0.0, -1.0),
    @graphics.Color::new(r=128, g=0, b=128, a=255),
  )
}

///|
test "PaintShader::sweep_gradient_stops samples multi-stop gradients" {
  let shader = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(shader.sample(1.0, 0.0), @graphics.Color::red())
  assert_eq(shader.sample(1.0, 1.0), @graphics.Color::new(r=128, g=128, b=0))
  assert_eq(shader.sample(0.0, 1.0), @graphics.Color::green())
  assert_eq(shader.sample(-1.0, 0.0), @graphics.Color::blue())
  assert_eq(shader.sample(0.0, -1.0), @graphics.Color::blue())
}

///|
test "PaintShader::sweep_gradient_stops supports repeat negative and degenerate sweeps" {
  let repeated = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
    spread=Repeat,
  )
  assert_eq(repeated.sample(-1.0, 0.0), @graphics.Color::red())
  assert_eq(repeated.sample(0.0, -1.0), @graphics.Color::green())

  let reversed = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=-@math.PI,
    stops=[
      @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
      @graphics.PaintGradientStop::new(
        offset=0.5,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(reversed.sample(1.0, 0.0), @graphics.Color::red())
  assert_eq(reversed.sample(0.0, -1.0), @graphics.Color::green())
  assert_eq(reversed.sample(-1.0, 0.0), @graphics.Color::blue())

  let degenerate = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=0.0,
    stops=[
      @graphics.PaintGradientStop::new(
        offset=0.25,
        color=@graphics.Color::green(),
      ),
      @graphics.PaintGradientStop::new(
        offset=1.0,
        color=@graphics.Color::blue(),
      ),
    ],
  )
  assert_eq(degenerate.sample(0.0, 1.0), @graphics.Color::green())

  let empty = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops=[],
  )
  assert_eq(empty.sample(1.0, 0.0), @graphics.Color::transparent())
}

///|
test "PaintShader gradient-stop shaders support mirror and decal spread" {
  let stops = [
    @graphics.PaintGradientStop::new(offset=0.0, color=@graphics.Color::red()),
    @graphics.PaintGradientStop::new(offset=0.5, color=@graphics.Color::green()),
    @graphics.PaintGradientStop::new(offset=1.0, color=@graphics.Color::blue()),
  ]
  let radial_mirror = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=2.0,
    stops~,
    spread=Mirror,
  )
  assert_eq(radial_mirror.sample(2.0, 0.0), @graphics.Color::blue())
  assert_eq(radial_mirror.sample(3.0, 0.0), @graphics.Color::green())
  assert_eq(radial_mirror.sample(4.0, 0.0), @graphics.Color::red())

  let radial_decal = @graphics.PaintShader::radial_gradient_stops(
    cx=0.0,
    cy=0.0,
    radius=2.0,
    stops~,
    spread=Decal,
  )
  assert_eq(radial_decal.sample(1.0, 0.0), @graphics.Color::green())
  assert_eq(radial_decal.sample(3.0, 0.0), @graphics.Color::transparent())

  let sweep_mirror = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops~,
    spread=Mirror,
  )
  assert_eq(sweep_mirror.sample(0.0, -1.0), @graphics.Color::green())

  let sweep_decal = @graphics.PaintShader::sweep_gradient_stops(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=@math.PI,
    stops~,
    spread=Decal,
  )
  assert_eq(sweep_decal.sample(0.0, 1.0), @graphics.Color::green())
  assert_eq(sweep_decal.sample(0.0, -1.0), @graphics.Color::transparent())
}

///|
test "PaintShader::sweep_gradient handles degenerate sweeps" {
  let shader = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0,
    sweep_angle=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(shader.sample(0.0, 1.0), @graphics.Color::red())

  let nan = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=0.0 / 0.0,
    sweep_angle=0.0 / 0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(nan.sample(0.0, 1.0), @graphics.Color::red())

  let tiny = @graphics.PaintShader::sweep_gradient(
    cx=0.0,
    cy=0.0,
    start_angle=@math.PI,
    sweep_angle=-0.0000000001,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  assert_eq(tiny.sample(0.0, -1.0), @graphics.Color::red())
}

///|
test "Paint shader overrides and can return to solid color" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let paint = @graphics.Paint::new()
    .set_color(@graphics.Color::green())
    .set_shader(shader)
  assert_true(paint.get_shader() is Some(_))
  assert_eq(paint.sample_color(0.0, 0.0), @graphics.Color::red())

  ignore(paint.clear_shader())
  assert_true(paint.get_shader() is None)
  assert_eq(paint.sample_color(0.0, 0.0), @graphics.Color::green())

  ignore(paint.set_shader(shader))
  ignore(paint.set_color(@graphics.Color::blue()))
  assert_true(paint.get_shader() is None)
  assert_eq(paint.sample_color(0.0, 0.0), @graphics.Color::blue())
}

///|
test "PaintShader::transformed participates in Canvas fill sampling" {
  let canvas = @graphics.Canvas::new(3, 1)
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  ).transformed(@graphics.Transform::translate(tx=1.0, ty=0.0))
  canvas.fill_rect(
    0.0,
    0.0,
    3.0,
    1.0,
    @graphics.Paint::new().set_shader(shader),
  )
  assert_eq(canvas.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(
    canvas.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=128, g=0, b=128),
  )
  assert_eq(canvas.get_pixmap().get_pixel(2, 0), @graphics.Color::blue())
}

///|
test "PaintShader::transformed maps radial and sweep Canvas fill sampling" {
  let radial_canvas = @graphics.Canvas::new(4, 1)
  radial_canvas.clear(@graphics.Color::white())
  let radial = @graphics.PaintShader::radial_gradient(
    cx=0.5,
    cy=0.5,
    radius=1.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  ).transformed(@graphics.Transform::translate(tx=1.0, ty=0.0))
  radial_canvas.fill_rect(
    0.0,
    0.0,
    4.0,
    1.0,
    @graphics.Paint::new().set_shader(radial),
  )
  let radial_pixmap = radial_canvas.get_pixmap()
  assert_eq(radial_pixmap.get_pixel(0, 0), @graphics.Color::blue())
  assert_eq(radial_pixmap.get_pixel(1, 0), @graphics.Color::red())
  assert_eq(radial_pixmap.get_pixel(2, 0), @graphics.Color::blue())
  assert_eq(radial_pixmap.get_pixel(3, 0), @graphics.Color::white())

  let sweep_canvas = @graphics.Canvas::new(3, 3)
  sweep_canvas.clear(@graphics.Color::white())
  let sweep = @graphics.PaintShader::sweep_gradient(
    cx=0.5,
    cy=0.5,
    start_angle=0.0,
    sweep_angle=@math.PI,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
    spread=Decal,
  ).transformed(@graphics.Transform::translate(tx=1.0, ty=1.0))
  sweep_canvas.fill_rect(
    0.0,
    0.0,
    3.0,
    3.0,
    @graphics.Paint::new().set_shader(sweep),
  )
  let sweep_pixmap = sweep_canvas.get_pixmap()
  assert_eq(sweep_pixmap.get_pixel(0, 0), @graphics.Color::white())
  assert_eq(sweep_pixmap.get_pixel(2, 1), @graphics.Color::red())
  assert_eq(
    sweep_pixmap.get_pixel(1, 2),
    @graphics.Color::new(r=128, g=0, b=128),
  )
  assert_eq(
    sweep_pixmap.get_pixel(2, 2),
    @graphics.Color::new(r=191, g=0, b=64),
  )
}
