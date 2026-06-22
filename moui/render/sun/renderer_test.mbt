///|
test "sun renderer backend info is ready cpu raster" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::SunRasterNative);    assert_true(info.status == @render.RendererCapabilityStatus::Supported)
  assert_true(info.can_render)
  assert_true(info.can_resize)
  assert_true(info.owns_surface)
  assert_true(info.description.contains("moui_sun"))
}

///|
test "sun renderer descriptor exposes sun cpu pixel backend" {
  let descriptor = renderer_descriptor()
  assert_true(
    descriptor.backend == @render.RendererBackendKind::SunRasterNative,
  )
  assert_true(descriptor.family == @render.RendererFamily::Sun)
  assert_true(
    descriptor.presentation == @render.RendererPresentationModel::CpuPixelFrame,
  )
  inspect(descriptor.capabilities.length(), content="17")
}

///|
test "sun renderer presents rect pixels" {
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
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
      @core.Color::blue(),
    ),
  ])
  inspect(renderer.present_count(), content="1")
  match presented.val {
    Some(frame) => {
      inspect(frame.width, content="4")
      inspect(frame.height, content="4")
      inspect(frame.bytes.length(), content="64")
      assert_true(frame.pixels[(1 * frame.width + 1) * 4 + 2].to_int() > 200)
      assert_true(frame.pixels[3].to_int() == 255)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer draws placeholder text and records diagnostic" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=12.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=0.0, y=0.0, width=24.0, height=12.0),
        font=@core.FontSpec::new(size=10.0),
        color=@core.Color::black(),
      ),
    ),
  ])
  inspect(renderer.unsupported_command_count(), content="1")
  let diagnostics = renderer.unsupported_command_diagnostics()
  assert_true(diagnostics[0].command == "DrawText")
  assert_true(diagnostics[0].reason.contains("placeholder glyphs"))
  match presented.val {
    Some(frame) => {
      let mut dark_pixels = 0
      for index in 0..<(frame.width * frame.height) {
        let offset = index * 4
        if frame.pixels[offset].to_int() < 64 &&
          frame.pixels[offset + 1].to_int() < 64 &&
          frame.pixels[offset + 2].to_int() < 64 {
          dark_pixels = dark_pixels + 1
        }
      }
      assert_true(dark_pixels > 0)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer works at 2x scale factor" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  // Create with 2x scale factor
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
      scale_factor=2.0,
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=1.0, y=1.0, width=2.0, height=2.0),
      @core.Color::blue(),
    ),
  ])
  inspect(renderer.present_count(), content="1")
  match presented.val {
    Some(frame) => {
      // At 2x scale, canvas is 8x8 physical pixels
      inspect(frame.width, content="8")
      inspect(frame.height, content="8")
      inspect(frame.bytes.length(), content="256")
      // Logical (1,1) mapped to physical (2,2), blue channel should be > 200
      let blue_byte = frame.pixels[(2 * frame.width + 2) * 4 + 2]
      assert_true(blue_byte.to_int() > 200)
      assert_true(frame.pixels[3].to_int() == 255)
    }
    None => fail("expected Sun frame")
  }
}
