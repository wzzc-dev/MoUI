///|
test "sun renderer linear gradient debug shader uses fallback colors" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=1.0),
    ),
    target,
  )
  let fallback = @core.Brush::radial_gradient(
    center=@core.Point::new(x=8.0, y=0.0),
    radius=8.0,
    center_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
    edge_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0)),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="linear-gradient-debug",
        frame=@core.Rect::new(x=0.0, y=0.0, width=16.0, height=1.0),
        fallback~,
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      let left_idx = 0
      let mid_idx = 8 * 4
      let right_idx = 15 * 4
      let left_r = frame.pixels[left_idx].to_int()
      let left_b = frame.pixels[left_idx + 2].to_int()
      let mid_r = frame.pixels[mid_idx].to_int()
      let mid_b = frame.pixels[mid_idx + 2].to_int()
      let right_r = frame.pixels[right_idx].to_int()
      let right_b = frame.pixels[right_idx + 2].to_int()
      assert_true(left_r > 200 && left_b < 80)
      assert_true(mid_r > 80 && mid_b > 80)
      assert_true(right_r < 80 && right_b > 200)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer solid shader fills fallback without diagnostic" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="solid",
        frame=@core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
        fallback=@core.Brush::solid(
          @core.Color::rgba(r=0.1, g=0.8, b=0.2, a=1.0),
        ),
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      let painted_idx = (1 * 4 + 1) * 4
      let outside_idx = 0
      assert_true(frame.pixels[painted_idx + 1].to_int() > 180)
      assert_true(frame.pixels[painted_idx].to_int() < 80)
      assert_true(frame.pixels[outside_idx].to_int() == 255)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer checker shader uses fallback colors and cell count" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
        uniforms=[2.0],
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=8.0, y=0.0),
          start_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
          end_color=@core.Color::rgba(r=0.05, g=0.10, b=0.95),
        ),
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      let red_idx = (1 * 8 + 1) * 4
      let blue_idx = (1 * 8 + 5) * 4
      assert_true(frame.pixels[red_idx].to_int() > 200)
      assert_true(frame.pixels[red_idx + 2].to_int() < 80)
      assert_true(frame.pixels[blue_idx].to_int() < 80)
      assert_true(frame.pixels[blue_idx + 2].to_int() > 200)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer vignette shader uses fallback center color" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=16.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=@core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
        uniforms=[1.0],
        fallback=@core.Brush::solid(
          @core.Color::rgba(r=0.05, g=0.85, b=0.20, a=1.0),
        ),
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      let center_idx = (8 * 16 + 8) * 4
      let edge_idx = (0 * 16 + 0) * 4
      assert_true(frame.pixels[center_idx + 1].to_int() > 180)
      assert_true(frame.pixels[center_idx].to_int() < 80)
      assert_true(frame.pixels[edge_idx].to_int() < 80)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}
