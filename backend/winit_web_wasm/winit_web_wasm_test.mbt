///|
test "winit web wasm backend records current capability split" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::WebWasm)
  inspect(info.uses_window_web_backend, content="true")
  inspect(info.has_wgpu_wasm_renderer, content="false")
  inspect(info.keeps_js_webgpu_fallback, content="true")
  assert_true(
    info.renderer_info.backend == @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(
    info.renderer_info.status == @render.RendererCapabilityStatus::Unsupported,
  )
  assert_true(
    info.surface_contract.source ==
    @render.WgpuSurfaceSourceKind::WebCanvasSurface,
  )
  inspect(info.surface_contract.ready, content="false")
}

///|
test "winit web wasm exposes renderer readiness through adapter" {
  inspect(wasm_renderer_ready(), content="false")
  assert_true(
    renderer_backend_info().backend == @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(
    canvas_surface_contract().backend == @render.RendererBackendKind::WebGpuWasm,
  )
}

///|
test "winit web wasm maps close event to host event" {
  let event = window_event_to_host(
    @window_core.WindowEvent::CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::CloseRequested) => ()
    _ => fail("expected close requested")
  }
}

///|
test "winit web wasm maps surface resize to host metrics" {
  let event = window_event_to_host(
    @window_core.WindowEvent::SurfaceResized(@dpi.PhysicalSize::new(320, 200)),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=320.0, height=200.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=320.0, height=200.0),
      )
    }
    _ => fail("expected resize event")
  }
}

///|
test "winit web wasm maps scale factor changes to host metrics" {
  let writer = @window_core.SurfaceSizeWriter::new(
    @dpi.PhysicalSize::new(640, 360),
  )
  let event = window_event_to_host(
    @window_core.WindowEvent::ScaleFactorChanged(2.0, writer),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=360.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=640.0, height=360.0),
      )
      inspect(metrics.scale_factor, content="2")
    }
    _ => fail("expected scale factor resize event")
  }
}

///|
test "winit web wasm maps pointer move and left button to host events" {
  let moved = window_event_to_host(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::new(12.0, 34.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match moved {
    Some(@host.HostEvent::PointerMoved(position)) =>
      assert_true(position == @core.Point::new(x=12.0, y=34.0))
    _ => fail("expected pointer move")
  }

  let down = window_event_to_host(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::new(5.0, 6.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match down {
    Some(@host.HostEvent::PointerButton(position, phase, button)) => {
      assert_true(position == @core.Point::new(x=5.0, y=6.0))
      assert_true(phase == @core.PointerPhase::Down)
      inspect(button, content="0")
    }
    _ => fail("expected pointer button")
  }
}

///|
test "winit web wasm maps keyboard modifiers repeat and text" {
  let key_event = @window_core.KeyEvent::new(
    @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::KeyA),
    @window_core.Key::Character("a"),
    @window_core.Key::Character("a"),
    @window_core.KeyLocation::Standard,
    @window_core.ElementState::Pressed,
    true,
    Some("a"),
    Some("A"),
  )
  let event = window_event_to_host_with_modifiers(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
    @core.KeyModifiers::new(shift=true),
  )
  match event {
    Some(@host.HostEvent::Keyboard(event)) => {
      inspect(event.key, content="a")
      match event.text {
        Some(text) => inspect(text, content="a")
        None => fail("expected text")
      }
      inspect(event.pressed, content="true")
      inspect(event.repeat, content="true")
      inspect(event.modifiers.shift, content="true")
    }
    _ => fail("expected keyboard event")
  }
}

///|
test "winit web wasm maps named keys and ignores synthetic keyboard input" {
  let key_event = @window_core.KeyEvent::new(
    @window_core.PhysicalKey::from_key_code(@window_core.KeyCode::Enter),
    @window_core.Key::Named(@window_core.NamedKey::Enter),
    @window_core.Key::Named(@window_core.NamedKey::Enter),
    @window_core.KeyLocation::Standard,
    @window_core.ElementState::Released,
    false,
    None,
    None,
  )
  let event = window_event_to_host(
    @window_core.WindowEvent::KeyboardInput(None, key_event, false),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::Keyboard(event)) => {
      inspect(event.key, content="Enter")
      inspect(event.pressed, content="false")
    }
    _ => fail("expected named key event")
  }
  let synthetic = window_event_to_host(
    @window_core.WindowEvent::KeyboardInput(None, key_event, true),
    @core.Point::new(x=0.0, y=0.0),
  )
  match synthetic {
    None => ()
    Some(_) => fail("expected synthetic keyboard input to be ignored")
  }
}

///|
test "winit web wasm maps ime commit and redraw" {
  let ime = window_event_to_host(
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("hello")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match ime {
    Some(@host.HostEvent::TextInput(text)) => inspect(text, content="hello")
    _ => fail("expected text input")
  }

  let redraw = window_event_to_host(
    @window_core.WindowEvent::RedrawRequested,
    @core.Point::new(x=0.0, y=0.0),
  )
  match redraw {
    Some(@host.HostEvent::RedrawRequested) => ()
    _ => fail("expected redraw requested")
  }
}
