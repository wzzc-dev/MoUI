///|
test "skia renderer paints blend and saturation filter pixels" {
  guard skia_available() else { return () }
  let saturation_available = @skia_native.ColorFilter::saturation(0.0)
    is Some(_)
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=32.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Multiply),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=0.0, g=0.0, b=1.0),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(0.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=16.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
    @core.DrawCommand::PopFilter,
  ]) catch {
    err => fail("expected Skia blend/filter render: \{err.message()}")
  }
  // When saturation filter is unavailable (Skia release header structure),
  // the filter command is recorded as unsupported but rendering continues.
  let unsupported = renderer.unsupported_command_count()
  if saturation_available {
    assert_true(unsupported == 0)
  } else {
    assert_true(unsupported == 1)
  }
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=4.0, y=4.0, width=8.0, height=8.0),
      (r, g, b, a) => a > 0 && r < 80 && g < 80 && b < 80,
    ),
  )
  // When saturation filter is unavailable, the saturated region renders
  // as plain red instead of grayscale. Accept either the saturated result
  // (filtered) or the unfiltered red result.
  if saturation_available {
    assert_true(
      skia_test_region_has_matching_pixel(
        frame,
        @core.Rect::new(x=20.0, y=4.0, width=8.0, height=8.0),
        (r, g, b, a) => {
          a > 0 && r > 25 && r < 120 && g > 25 && g < 120 && b > 25 && b < 120
        },
      ),
    )
  } else {
    assert_true(
      skia_test_region_has_matching_pixel(
        frame,
        @core.Rect::new(x=20.0, y=4.0, width=8.0, height=8.0),
        (r, g, b, a) => a > 0 && r > 150 && g < 100 && b < 100,
      ),
    )
  }
}

///|
test "skia renderer paints path fill and stroke pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=40.0, height=40.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=6.0, y=6.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=32.0, y=6.0)),
          @core.PathVerb::QuadTo(
            @core.Point::new(x=36.0, y=18.0),
            @core.Point::new(x=30.0, y=32.0),
          ),
          @core.PathVerb::CubicTo(
            @core.Point::new(x=22.0, y=36.0),
            @core.Point::new(x=12.0, y=34.0),
            @core.Point::new(x=6.0, y=28.0),
          ),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::rgba(r=0.95, g=0.08, b=0.08))),
        stroke=Some(@core.Brush::solid(@core.Color::black())),
        stroke_width=2.0,
      ),
    ),
  ]) catch {
    err => fail("expected Skia path render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.present_count(), content="1")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=14.0, y=14.0, width=12.0, height=12.0),
      (r, g, b, a) => a > 0 && r > 180 && g < 120 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=5.0, y=5.0, width=28.0, height=4.0),
    ),
  )
}

///|
test "skia renderer paints path linear gradient pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=40.0, height=20.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=2.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=38.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=38.0, y=18.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=2.0, y=18.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::linear_gradient(
            start=@core.Point::new(x=2.0, y=0.0),
            end=@core.Point::new(x=38.0, y=0.0),
            start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
            end_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
          ),
        ),
      ),
    ),
  ]) catch {
    err => fail("expected Skia path gradient render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=5.0, y=8.0, width=6.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 150 && g < 140 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=29.0, y=8.0, width=6.0, height=4.0),
      (r, g, b, a) => a > 0 && b > 150 && r < 120 && g < 140,
    ),
  )
}

///|
test "skia renderer paints radial gradient brush pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=24.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=20.0, height=20.0),
        radius=10.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=12.0, y=12.0),
        radius=10.0,
        center_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
        edge_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
      ),
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=26.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=46.0, y=2.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=46.0, y=22.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=26.0, y=22.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::radial_gradient(
            center=@core.Point::new(x=36.0, y=12.0),
            radius=10.0,
            center_color=@core.Color::rgba(r=0.05, g=0.85, b=0.18),
            edge_color=@core.Color::black(),
          ),
        ),
      ),
    ),
  ]) catch {
    err => fail("expected Skia radial gradient render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=10.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 150 && g < 130 && b < 130,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=19.0, y=10.0, width=3.0, height=4.0),
      (r, _, b, a) => a > 0 && b > 130 && r < 150,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=34.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && g > 130 && r < 130 && b < 130,
    ),
  )
}

///|
test "skia renderer paints built-in shader effect pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=16.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=0.0, y=0.0, width=24.0, height=16.0),
        uniforms=[4.0],
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=24.0, y=0.0),
          start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
          end_color=@core.Color::rgba(r=0.05, g=0.20, b=0.95),
        ),
      ),
    ),
  ]) catch {
    err => fail("expected Skia shader effect render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=1.0, y=1.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 180 && g < 100 && b < 100,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=7.0, y=1.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r < 100 && g < 120 && b > 180,
    ),
  )
}

///|
test "skia renderer paints shader gradient and vignette pixels" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=24.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="linear-gradient-debug",
        frame=@core.Rect::new(x=0.0, y=0.0, width=24.0, height=24.0),
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=24.0, y=0.0),
          start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
          end_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
        ),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=@core.Rect::new(x=24.0, y=0.0, width=24.0, height=24.0),
        uniforms=[1.0],
        fallback=@core.Brush::solid(@core.Color::rgba(r=0.05, g=0.85, b=0.20)),
      ),
    ),
  ]) catch {
    err => fail("expected Skia shader variant render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=2.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && r > 150 && g < 140 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=18.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && b > 150 && r < 120 && g < 140,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=34.0, y=10.0, width=4.0, height=4.0),
      (r, g, b, a) => a > 0 && g > 130 && r < 120 && b < 120,
    ),
  )
  assert_true(
    skia_test_region_has_matching_pixel(
      frame,
      @core.Rect::new(x=45.0, y=0.0, width=3.0, height=3.0),
      (r, g, b, a) => a > 0 && r < 80 && g < 80 && b < 80,
    ),
  )
}
