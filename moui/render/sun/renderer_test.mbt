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
test "sun renderer applies layer spec opacity at compositing" {
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
    @core.DrawCommand::PushLayer(@core.LayerSpec::new(opacity=0.5)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let idx = (2 * frame.width + 2) * 4
      assert_true(frame.pixels[idx].to_int() > 240)
      assert_true(frame.pixels[idx + 1].to_int() > 100)
      assert_true(frame.pixels[idx + 1].to_int() < 200)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer applies rectangular layer mask" {
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
      let inside = (1 * frame.width + 1) * 4
      let outside = 0
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
test "sun renderer applies rounded layer mask corners" {
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
  let rounded = @core.RoundedRect::new(
    rect=@core.Rect::new(x=2.0, y=2.0, width=12.0, height=12.0),
    radius=4.0,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(mask=@core.LayerMask::RoundedMask(rounded)),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let corner = (2 * frame.width + 2) * 4
      let center = (8 * frame.width + 8) * 4
      assert_true(frame.pixels[corner].to_int() > 240)
      assert_true(frame.pixels[corner + 1].to_int() > 240)
      assert_true(frame.pixels[center + 2].to_int() > 200)
      inspect(renderer.unsupported_command_count(), content="0")
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
test "sun renderer async image loading waits for explicit completion" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
    async_image_loading=true,
  )
  let source = sun_test_png_data_uri()
  let revisions : Array[Int] = []
  renderer.set_image_resource_change_callback(
    Some(snapshot => revisions.push(snapshot.revision)),
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
  inspect(renderer.present_count(), content="1")
  inspect(renderer.image_resource_snapshot().revision, content="1")
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageLoading, .. } else {
    fail("expected loading sun image record")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  assert_true(revisions == [1])

  let completion = sun_image_load_completion(source)
  guard completion
    is {
      status: @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
      width: 1,
      height: 1,
      ..,
    } else {
    fail("expected ready sun image load completion")
  }
  let ready_snapshot = renderer.apply_image_resource_load_completion(completion)
  inspect(ready_snapshot.revision, content="2")
  guard renderer.image_resources()[0]
    is { status: @render.ImageResourceStatus::ImageReady, .. } else {
    fail("expected ready sun image record")
  }
  assert_true(revisions == [1, 2])

  renderer.render(commands)
  inspect(renderer.present_count(), content="2")
  inspect(renderer.image_resource_snapshot().revision, content="2")
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun image load completion reports decode failures" {
  let completion = sun_image_load_completion("moui-sun-missing-image://async")
  guard completion
    is {
      status: @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
      diagnostic,
      ..,
    } else {
    fail("expected failed sun image load completion")
  }
  assert_true(diagnostic.contains("could not decode image source"))
}

///|
test "sun image load completion from bytes decodes provided image bytes" {
  let source = sun_test_png_data_uri()
  let data = try! @base64.decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==",
    ignore_whitespace=true,
  )
  let completion = sun_image_load_completion_from_bytes(
    source,
    data,
    background_io=true,
  )
  assert_true(
    completion.status ==
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady,
  )
  inspect(completion.source, content=source)
  inspect(completion.width, content="1")
  inspect(completion.height, content="1")
  inspect(completion.background_io, content="true")
  let failed = sun_image_load_completion_from_bytes(
    "invalid.png", b"not-an-image",
  )
  assert_true(
    failed.status == @render.ImageResourceLoadCompletionStatus::ImageLoadFailed,
  )
  assert_true(failed.diagnostic.contains("could not decode PNG image bytes"))
}

///|
test "sun renderer rounded clip + blur integration" {
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
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=12.0, height=12.0),
        radius=4.0,
      ),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(1.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::PopRoundedClip,
  ])
  match presented.val {
    Some(frame) => {
      // Center should be red (inside rounded clip, blurred)
      let center_r = frame.pixels[(8 * 16 + 8) * 4].to_int()
      assert_true(center_r > 200)
      // Corner should be white (outside rounded clip)
      let corner_r = frame.pixels[(0 * 16 + 0) * 4].to_int()
      assert_true(corner_r > 240)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer nested layers with opacity compositing" {
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
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::SourceOver),
    ),
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      // With 50% opacity red over white, center should show blended color
      let center_g = frame.pixels[(4 * 8 + 4) * 4 + 1].to_int()
      // Green channel should be ~127 (white blended through 50% opacity)
      assert_true(center_g > 100)
      assert_true(center_g < 200)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer triple-pass blur produces smooth falloff" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=8.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(2.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
  ])
  match presented.val {
    Some(frame) => {
      // Three-pass blur should produce a smooth gradient at the boundary.
      // Check that the boundary pixel at x=8 is a blend of red and white,
      // not a sharp edge (neither pure red nor pure white).
      let far_left_g = frame.pixels[(4 * 16 + 2) * 4 + 1].to_int()
      let boundary_g = frame.pixels[(4 * 16 + 8) * 4 + 1].to_int()
      let far_right_g = frame.pixels[(4 * 16 + 14) * 4 + 1].to_int()
      // Far left should be mostly red (low green)
      assert_true(far_left_g < 50)
      // Boundary should be a blend (green channel between 0 and 255)
      assert_true(boundary_g > 30)
      assert_true(boundary_g < 230)
      // Far right should be mostly white (high green)
      assert_true(far_right_g > 230)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer vignette shader darkens center" {
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
        fallback=@core.Brush::solid(
          @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
        ),
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      // Vignette draws concentric dark circles at the center
      // Center pixel should be darkened
      let center_r = frame.pixels[(8 * 16 + 8) * 4].to_int()
      assert_true(center_r < 255)
      assert_true(center_r < 200)
      // Corner pixel is outside the vignette circles, should stay white
      let corner_r = frame.pixels[(0 * 16 + 0) * 4].to_int()
      assert_true(corner_r == 255)
      // Center should be darker than corner
      assert_true(center_r < corner_r)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer brightness filter applies via pixmap compositing" {
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
  // Draw a mid-gray rect with brightness=2.0 filter
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0)),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(2.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.5, g=0.5, b=0.5, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
  ])
  match presented.val {
    Some(frame) => {
      // Center pixel should be brightened (0.5 * 2.0 = 1.0 = 255)
      let idx = (2 * 4 + 2) * 4
      let r = frame.pixels[idx].to_int()
      assert_true(r > 240)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer blur filter softens edge" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=16.0, height=8.0),
    ),
    target,
  )
  // Left half red, right half blue, separated by a sharp edge at x=8
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Blur(2.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=8.0, y=0.0, width=8.0, height=8.0),
      @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
  ])
  match presented.val {
    Some(frame) => {
      // Far-left pixel should be mostly red
      let left_idx = (4 * 16 + 1) * 4
      let left_r = frame.pixels[left_idx].to_int()
      assert_true(left_r > 200)
      // Far-right pixel should be mostly blue
      let right_idx = (4 * 16 + 14) * 4
      let right_b = frame.pixels[right_idx + 2].to_int()
      assert_true(right_b > 200)
      // Boundary pixel (x=8) should be a blend of red and blue, not pure red or pure blue
      let bound_idx = (4 * 16 + 8) * 4
      let bound_r = frame.pixels[bound_idx].to_int()
      let bound_b = frame.pixels[bound_idx + 2].to_int()
      // After blur, boundary should have both red and blue components
      assert_true(bound_r > 50)
      assert_true(bound_b > 50)
      // Unsupported command count should be 0 (blur is now implemented)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer rounded clip draws center pixel" {
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
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=12.0, height=12.0),
        radius=3.0,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopRoundedClip,
  ])
  match presented.val {
    Some(frame) => {
      // center pixel (8,8) should be blue
      let idx = (8 * 16 + 8) * 4
      assert_true(frame.pixels[idx + 2].to_int() > 200) // blue channel
      assert_true(frame.pixels[idx + 3].to_int() > 200) // alpha
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer rounded clip masks corner pixel" {
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
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=12.0, height=12.0),
        radius=4.0,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopRoundedClip,
  ])
  match presented.val {
    Some(frame) => {
      // top-left corner pixel (2,2) of the rounded rect should be masked (white background shows through)
      // since the radius is 4, the corner is well inside the rounding region
      let idx = (2 * 16 + 2) * 4
      // background is white (255,255,255,255), corner pixel should be mostly white
      let r = frame.pixels[idx].to_int()
      assert_true(r > 200) // still mostly white
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer rounded clip with zero radius acts as rect clip" {
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
    @core.DrawCommand::PushRoundedClip(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
        radius=0.0,
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
      // pixel inside the clip rect should be blue
      let inside_idx = (4 * 8 + 4) * 4
      assert_true(frame.pixels[inside_idx + 2].to_int() > 200)
      // pixel outside the clip rect should be white
      let outside_idx = (0 * 8 + 0) * 4
      assert_true(frame.pixels[outside_idx].to_int() > 200) // red channel of white
    }
    None => fail("expected Sun frame")
  }
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

///|
test "sun renderer cached layer renders and caches on first draw" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer("test-layer"),
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  inspect(renderer.cached_layer_hit_count(), content="0")
  inspect(renderer.unsupported_command_count(), content="0")
  match presented.val {
    Some(frame) => {
      let r = frame.pixels[0].to_int()
      assert_true(r > 200)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer cached layer hits on second render with same revision" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=4.0),
    ),
    target,
  )
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::EndCachedLayer("test-layer"),
  ]
  renderer.render(commands)
  inspect(renderer.cached_layer_miss_count(), content="1")
  inspect(renderer.cached_layer_hit_count(), content="0")
  renderer.render(commands)
  inspect(renderer.cached_layer_miss_count(), content="1")
  inspect(renderer.cached_layer_hit_count(), content="1")
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer cached layer misses on revision change" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer("test-layer"),
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=2,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.0, g=1.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer("test-layer"),
  ])
  inspect(renderer.cached_layer_miss_count(), content="2")
  inspect(renderer.cached_layer_hit_count(), content="0")
}

///|
test "sun renderer DrawCachedLayer draws from cache" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer("test-layer"),
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
  ])
  inspect(renderer.cached_layer_hit_count(), content="1")
  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer dispose clears cached layers" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::EndCachedLayer("test-layer"),
  ])
  inspect(renderer.cached_layer_miss_count(), content="1")
  renderer.dispose()
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawCachedLayer(
      @core.CachedLayerSpec::new(
        key="test-layer",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
        content_revision=1,
      ),
    ),
  ])
  inspect(renderer.unsupported_command_count(), content="1")
}

///|
test "sun renderer DrawPath fills a rect path" {
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
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=4.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=4.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=12.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=12.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(
          @core.Brush::solid(@core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)),
        ),
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      // Center of path (8,8) should be red
      let center = (8 * 16 + 8) * 4
      assert_true(frame.pixels[center].to_int() > 200)
      assert_true(frame.pixels[center + 3].to_int() == 255)
      // Corner outside path (0,0) should be white
      assert_true(frame.pixels[0].to_int() > 200)
      assert_true(frame.pixels[1].to_int() > 200)
      assert_true(frame.pixels[2].to_int() > 200)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer DrawPath strokes a rect path" {
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
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=4.0, y=4.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=4.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=12.0, y=12.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=4.0, y=12.0)),
          @core.PathVerb::Close,
        ],
        stroke=Some(@core.Brush::solid(@core.Color::blue())),
        stroke_width=2.0,
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      // Edge pixel at (4,4) should be blue (on the stroke)
      let edge = (4 * 16 + 4) * 4
      assert_true(frame.pixels[edge + 2].to_int() > 200)
      // Interior at (8,8) should remain white (no fill)
      let center = (8 * 16 + 8) * 4
      assert_true(frame.pixels[center].to_int() > 200)
      assert_true(frame.pixels[center + 1].to_int() > 200)
      assert_true(frame.pixels[center + 2].to_int() > 200)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer DrawShadow renders shadow behind rect" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=32.0, height=32.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=@core.RoundedRect::new(
          rect=@core.Rect::new(x=8.0, y=8.0, width=16.0, height=16.0),
          radius=2.0,
        ),
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.5),
        offset=@core.Point::new(x=0.0, y=2.0),
        blur_radius=4.0,
        spread=0.0,
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      // A pixel in the shadow area should have some darkening
      // (16,16) is roughly at the center-bottom of the rect
      let px = (16 * 32 + 16) * 4
      let r = frame.pixels[px].to_int()
      // Should be darker than pure white (255)
      assert_true(r < 230)
      // Far corner (0,0) should be mostly white (beyond shadow reach)
      assert_true(frame.pixels[0].to_int() > 240)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer saturate filter desaturates red to gray" {
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
    @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(0.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
  ])
  match presented.val {
    Some(frame) => {
      let idx = (2 * 4 + 2) * 4
      let r = frame.pixels[idx].to_int()
      let g = frame.pixels[idx + 1].to_int()
      let b = frame.pixels[idx + 2].to_int()
      // Desaturated red should be gray-ish: all channels near luminance ~77
      assert_true(r > 60 && r < 95)
      assert_true(g > 60 && g < 95)
      assert_true(b > 60 && b < 95)
      // R and G should be very close (same luminance)
      let diff = (r - g).abs()
      assert_true(diff < 5)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer contrast filter increases contrast" {
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
    @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0)),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Contrast(2.0)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.7, g=0.7, b=0.7, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
  ])
  match presented.val {
    Some(frame) => {
      let idx = (2 * 4 + 2) * 4
      let r = frame.pixels[idx].to_int()
      // Light gray (178) with contrast(2.0): (178-128)*2+128 = 228
      assert_true(r > 210)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer checker shader alternates tiles" {
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
        uniforms=[4.0],
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      // Tile (0,0): row=0,col=0, (0+0)%2==0 → c1=(200,200,200)
      let c1_idx = (1 * 8 + 1) * 4
      let c1 = frame.pixels[c1_idx].to_int()
      assert_true(c1 > 190 && c1 < 210)
      // Tile (0,1): row=0,col=1, (0+1)%2==1 → c2=(255,255,255)
      let c2_idx = (1 * 8 + 5) * 4
      let c2 = frame.pixels[c2_idx].to_int()
      assert_true(c2 > 245)
      // They should be different
      assert_true(c1 < c2)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer radial gradient varies center to edge" {
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
  let gradient = @core.Brush::radial_gradient(
    center=@core.Point::new(x=8.0, y=0.0),
    radius=8.0,
    center_color=@core.Color::white(),
    edge_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0),
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=1.0)),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=16.0, height=1.0),
      ),
      gradient,
    ),
  ])
  match presented.val {
    Some(frame) => {
      // Center pixel (8,0) should be near white
      let center_r = frame.pixels[8 * 4].to_int()
      assert_true(center_r > 200)
      // Edge pixel (0,0) should be dark
      let edge_r = frame.pixels[0].to_int()
      assert_true(edge_r < 80)
      assert_true(center_r > edge_r)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer screen blend mode brightens" {
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
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.784, g=0.784, b=0.784, a=1.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Screen),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.502, g=0.502, b=0.502, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let r = frame.pixels[0].to_int()
      // Screen(200, 128) = 255 - (255-200)*(255-128)/255 = 255 - 55*127/255 ≈ 228
      // SourceOver would be ~128
      assert_true(r > 210)
      assert_true(r < 245)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer darken blend mode keeps darker" {
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
  // Base: dark gray (100,100,100), Layer: light gray (200,200,200)
  // Darken keeps the darker: min(100,200)=100
  // SourceOver would overwrite with 200
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.392, g=0.392, b=0.392, a=1.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Darken),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.784, g=0.784, b=0.784, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let r = frame.pixels[0].to_int()
      // Darken(100, 200) = 100, SourceOver would be 200
      assert_true(r > 85 && r < 115)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer lighten blend mode keeps lighter" {
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
  // Base: light gray (200,200,200), Layer: dark gray (100,100,100)
  // Lighten keeps the lighter: max(200,100)=200
  // SourceOver would overwrite with 100
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.784, g=0.784, b=0.784, a=1.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Lighten),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.392, g=0.392, b=0.392, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let r = frame.pixels[0].to_int()
      // Lighten(200, 100) = 200, SourceOver would be 100
      assert_true(r > 185 && r < 215)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer overlay blend mode combines correctly" {
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
  // Overlay: base=200, layer=100
  // If base > 128: result = 255 - (255-base)*(255-layer)*2/255
  // = 255 - 55*155*2/255 = 255 - 66.6 = ~188
  // SourceOver would be 100 (layer overwrites)
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.784, g=0.784, b=0.784, a=1.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(blend_mode=@core.BlendMode::Overlay),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=0.392, g=0.392, b=0.392, a=1.0),
    ),
    @core.DrawCommand::PopLayer,
  ])
  match presented.val {
    Some(frame) => {
      let r = frame.pixels[0].to_int()
      // Overlay(200, 100) should differ from SourceOver (100)
      assert_true(r > 150)
      assert_true(r < 220)
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer color matrix filter inverts via matrix" {
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
  // Invert matrix: R'=1-R, G'=1-G, B'=1-B
  // Matrix: [-1,0,0,0,1, 0,-1,0,0,1, 0,0,-1,0,1, 0,0,0,1,0]
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::PushFilter(
      @core.FilterEffect::ColorMatrix([
        -1.0, 0.0, 0.0, 0.0, 255.0, 0.0, -1.0, 0.0, 0.0, 255.0, 0.0, 0.0, -1.0, 0.0,
        255.0, 0.0, 0.0, 0.0, 1.0, 0.0,
      ]),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
    ),
    @core.DrawCommand::PopFilter,
  ])
  match presented.val {
    Some(frame) => {
      let idx = (2 * 4 + 2) * 4
      // Red (255,0,0) inverted should be (0,255,255) = cyan
      let r = frame.pixels[idx].to_int()
      let g = frame.pixels[idx + 1].to_int()
      let b = frame.pixels[idx + 2].to_int()
      assert_true(r < 20)
      assert_true(g > 230)
      assert_true(b > 230)
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer gradient stroke on path" {
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
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.5)),
          @core.PathVerb::LineTo(@core.Point::new(x=8.0, y=0.5)),
          @core.PathVerb::Close,
        ],
        stroke=Some(gradient),
        stroke_width=1.0,
      ),
    ),
  ])
  match presented.val {
    Some(frame) => {
      // Left pixel should lean red, right pixel should lean blue
      let left_r = frame.pixels[0].to_int()
      let right_b = frame.pixels[7 * 4 + 2].to_int()
      assert_true(left_r > 100)
      assert_true(right_b > 100)
    }
    None => fail("expected Sun frame")
  }
}
