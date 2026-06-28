///|
test "sun renderer layer inherits 2x scale factor" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
      scale_factor=2.0,
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushLayer(@core.LayerSpec::new()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let inside = (5 * frame.width + 5) * 4
      let outside = (1 * frame.width + 1) * 4
      assert_true(frame.pixels[inside + 2].to_int() > 200)
      assert_true(frame.pixels[outside].to_int() > 240)
      assert_true(frame.pixels[outside + 1].to_int() > 240)
      assert_true(frame.pixels[outside + 2].to_int() > 240)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer rectangular layer mask inherits 2x scale factor" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
      scale_factor=2.0,
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
        ),
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let inside = (5 * frame.width + 5) * 4
      let outside = (1 * frame.width + 1) * 4
      assert_true(frame.pixels[inside + 2].to_int() > 200)
      assert_true(frame.pixels[outside].to_int() > 240)
      assert_true(frame.pixels[outside + 1].to_int() > 240)
      assert_true(frame.pixels[outside + 2].to_int() > 240)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer rectangular clip inherits 2x scale factor" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
      scale_factor=2.0,
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
  ])
  match presented.val {
    Some(frame) => {
      let inside = (5 * frame.width + 5) * 4
      let outside = (1 * frame.width + 1) * 4
      assert_true(frame.pixels[inside + 2].to_int() > 200)
      assert_true(frame.pixels[outside].to_int() > 240)
      assert_true(frame.pixels[outside + 1].to_int() > 240)
      assert_true(frame.pixels[outside + 2].to_int() > 240)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer rounded clip inherits 2x scale factor" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
      scale_factor=2.0,
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
        radius=2.0,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopRoundedClip,
  ])
  match presented.val {
    Some(frame) => {
      let center = (8 * frame.width + 8) * 4
      let corner = (3 * frame.width + 3) * 4
      assert_true(frame.pixels[center + 2].to_int() > 200)
      assert_true(frame.pixels[corner].to_int() > 240)
      assert_true(frame.pixels[corner + 1].to_int() > 240)
      assert_true(frame.pixels[corner + 2].to_int() > 240)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer transform scope translates drawing" {
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
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=4.0, dy=4.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopTransform,
  ])
  match presented.val {
    Some(frame) => {
      assert_true(frame.pixels[0].to_int() > 200)
      assert_true(frame.pixels[1].to_int() > 200)
      assert_true(frame.pixels[2].to_int() > 200)
      let idx = (5 * 8 + 5) * 4
      assert_true(frame.pixels[idx].to_int() > 200)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer layer inherits transform scope" {
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
    @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0)),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=3.0, dy=3.0),
    ),
    @core.DrawCommand::PushLayer(@core.LayerSpec::new()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=2.0, height=2.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::PopTransform,
  ])
  match presented.val {
    Some(frame) => {
      let translated = (4 * frame.width + 4) * 4
      assert_true(frame.pixels[translated].to_int() > 200)
      assert_true(frame.pixels[0].to_int() < 20)
      assert_true(frame.pixels[1].to_int() < 20)
      assert_true(frame.pixels[2].to_int() < 20)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer nested filter inside transform scope" {
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
    @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0)),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=2.0, dy=2.0),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(3.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.3, g=0.3, b=0.3, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopTransform,
  ])
  match presented.val {
    Some(frame) => {
      let idx = (4 * 8 + 4) * 4
      let r = frame.pixels[idx].to_int()
      assert_true(r > 200)
      assert_true(frame.pixels[0].to_int() < 20)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}
