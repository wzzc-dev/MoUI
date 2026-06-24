///|
test "sun renderer backend info is ready cpu raster" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::SunRasterNative)
  assert_true(info.status == @render.RendererCapabilityStatus::Supported)
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
test "sun renderer applies multiply blend mode in layer compositing" {
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
  // Base: fill with light gray (200,200,200), layer with Multiply blend mode fill (128,128,128)
  // Multiply result: 200*128/255 ≈ 100 per channel, different from SourceOver (128)
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.784, g=0.784, b=0.784, a=1.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Multiply),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.502, g=0.502, b=0.502, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      // With Multiply blend: 200*128/255 ≈ 100, not 128 (SourceOver would overwrite)
      let r = frame.pixels[0].to_int()
      assert_true(r > 85 && r < 115)
      // If it were SourceOver, r would be ~128
      assert_true(r < 120)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer draws text without unsupported diagnostic" {
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
  inspect(renderer.unsupported_command_count(), content="0")
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

///|
test "sun renderer renders linear gradient pixels" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=1.0),
    ),
    target,
  )
  let gradient = @core.Brush::linear_gradient(
    start=@core.Point::new(x=0.0, y=0.0),
    end=@core.Point::new(x=8.0, y=0.0),
    start_color=@core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    end_color=@core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0),
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=1.0),
      ),
      gradient,
    ),
  ])
  match presented.val {
    Some(frame) => {
      let left_r = frame.pixels[0].to_int()
      let right_r = frame.pixels[7 * 4].to_int()
      let left_b = frame.pixels[2].to_int()
      let right_b = frame.pixels[7 * 4 + 2].to_int()
      assert_true(left_r > right_r)
      assert_true(right_b > left_b)
    }
    None => fail("expected Sun frame")
  }
}

///|
fn sun_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "sun renderer records ready image lifecycle once for cached image draws" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let source = sun_test_png_data_uri()
  let callback_count = Ref(0)
  let revisions : Array[Int] = []
  renderer.set_image_resource_change_callback(
    Some(snapshot => {
      callback_count.val = callback_count.val + 1
      revisions.push(snapshot.revision)
    }),
  )
  let commands = [
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]

  renderer.render(commands)
  let first_snapshot = renderer.image_resource_snapshot()
  inspect(first_snapshot.revision, content="1")
  guard renderer.image_resources().length() == 1 else {
    fail("expected one sun image resource record")
  }
  guard renderer.image_resources()[0]
    is {
      status: @render.ImageResourceStatus::ImageReady,
      width: 1,
      height: 1,
      ..,
    } else {
    fail("expected ready sun image record")
  }
  inspect(callback_count.val, content="1")
  assert_true(revisions == [1])

  renderer.render(commands)
  let second_snapshot = renderer.image_resource_snapshot()
  inspect(second_snapshot.revision, content="1")
  inspect(callback_count.val, content="1")
}

///|
test "sun renderer records failed image lifecycle once for repeated decode errors" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let callback_count = Ref(0)
  renderer.set_image_resource_change_callback(
    Some(_snapshot => callback_count.val = callback_count.val + 1),
  )
  let source = "moui-sun-missing-image://not-decodable"
  let commands = [
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]

  renderer.render(commands)
  inspect(renderer.image_resource_snapshot().revision, content="1")
  guard renderer.image_resources().length() == 1 else {
    fail("expected one failed sun image resource record")
  }
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageFailed, diagnostic, .. } else {
    fail("expected failed sun image record")
  }
  assert_true(diagnostic.contains("could not decode image source"))
  inspect(callback_count.val, content="1")
  inspect(renderer.unsupported_command_count(), content="1")

  renderer.render(commands)
  inspect(renderer.image_resource_snapshot().revision, content="1")
  inspect(callback_count.val, content="1")
  inspect(renderer.unsupported_command_count(), content="1")
}

///|
test "sun renderer records disposed image resources and notifies once" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let source = sun_test_png_data_uri()
  let statuses : Array[@render.ImageResourceStatus] = []
  let revisions : Array[Int] = []
  renderer.set_image_resource_change_callback(
    Some(snapshot => {
      revisions.push(snapshot.revision)
      if snapshot.records.length() > 0 {
        statuses.push(snapshot.records[0].status)
      }
    }),
  )
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  renderer.dispose()
  inspect(renderer.image_resource_snapshot().revision, content="2")
  assert_true(
    statuses ==
    [
      @render.ImageResourceStatus::ImageReady,
      @render.ImageResourceStatus::ImageDisposed,
    ],
  )
  assert_true(revisions == [1, 2])
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageDisposed, .. } else {
    fail("expected disposed sun image record")
  }
}

///|
test "sun renderer exposes stale image load completion apply port" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  let callback_count = Ref(0)
  renderer.set_image_resource_change_callback(
    Some(_snapshot => callback_count.val = callback_count.val + 1),
  )

  let stale_ready = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=18, height=10),
  )
  inspect(stale_ready.revision, content="0")
  inspect(stale_ready.records.length(), content="0")
  inspect(callback_count.val, content="0")

  let source = "moui-sun-missing-image://not-decodable"
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  let stale_failed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      source,
      diagnostic="late native decode failed",
    ),
  )
  inspect(stale_failed.revision, content="1")
  inspect(callback_count.val, content="1")
  guard stale_failed.records[0]
    is { status: @render.ImageResourceStatus::ImageFailed, diagnostic, .. } else {
    fail("expected existing failed record after stale completion")
  }
  assert_true(diagnostic.contains("could not decode image source"))
}
