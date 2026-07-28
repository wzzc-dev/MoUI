///|
test "web backend requires wasm-gc WebGPU host imports" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Web)
  inspect(info.uses_window_web_backend, content="true")
  inspect(info.requires_browser_webgpu_renderer, content="true")
  assert_true(
    info.renderer_info.backend == @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(
    info.renderer_info.status == @render.RendererCapabilityStatus::Supported,
  )
  assert_true(
    info.surface_contract.source ==
    @render.WgpuSurfaceSourceKind::WebCanvasSurface,
  )
  inspect(info.surface_contract.ready, content="true")
}

///|
test "web exposes WebGPU renderer contract" {
  inspect(wasm_renderer_ready(), content="true")
  assert_true(
    renderer_backend_info().backend == @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(
    canvas_surface_contract().backend == @render.RendererBackendKind::WebGpuWasm,
  )
}

///|
test "web app options carry scene resolver and platform event sources" {
  let request = @host.HostWindowOpenRequest::new(
    title="Inspector",
    scene=@host.HostWindowScene::new(scene_id="inspector"),
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match WebAppOptions::new().scene_resolver.resolve(request) {
    @runtime.HostWindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Web scene resolver rejection")
  }
  let resolver = @runtime.HostWindowSceneResolver::new(resolve=request => {
    @runtime.HostWindowSceneResolution::SceneResolved(
      @runtime.HostWindowSceneInstance::new(
        request~,
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = WebAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
    route_source=Some(@runtime.HostRouteSource::new()),
  )
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Web platform event sources")
  }
  match options.route_source {
    Some(source) => inspect(source.active_handler_count(), content="0")
    None => fail("expected configured Web route source")
  }
  match options.scene_resolver.resolve(request) {
    @runtime.HostWindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Web scene resolver")
  }
}

///|
test "web renderer exposes app-visible ready image resource snapshots" {
  let port : @webgpu.WebGpuHostRendererPort = @webgpu.WebGpuHostRendererPort::new(
    capabilities=() => @webgpu.required_capabilities(),
    create_surface=(canvas_id, metrics) => {
      @webgpu.WebGpuHostSurface::new(canvas_id~, metrics~)
    },
    create_renderer=_surface => (),
    resize=_metrics => (),
    measure_text=input => @core.TextSystem::fallback().measure_text(input),
    register_font_data=(_family, _data) => (),
    image_resource=source => {
      Some(@render.ImageResourceRecord::ready(source, width=80, height=40))
    },
    submit=_calls => (),
    dispose=() => (),
  )
  let renderer : WebRenderer = {
    renderer: @webgpu.create_renderer(
      canvas_id="moui-test-canvas",
      logical_size=@core.Size::new(width=100.0, height=50.0),
      port~,
    ),
  }
  renderer.render([
    @core.DrawCommand::DrawImage({
      source: "ready.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=10.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  inspect(resources[0].source, content="ready.png")
  assert_true(resources[0].status == @render.ImageResourceStatus::ImageReady)
  inspect(resources[0].width, content="80")
  inspect(resources[0].height, content="40")
  let snapshot = renderer.image_resource_snapshot()
  inspect(snapshot.revision, content="2")
  inspect(snapshot.records.length(), content="1")
}

///|
test "web renderer exposes app-visible failed image resource snapshots" {
  let port : @webgpu.WebGpuHostRendererPort = @webgpu.WebGpuHostRendererPort::new(
    capabilities=() => @webgpu.required_capabilities(),
    create_surface=(canvas_id, metrics) => {
      @webgpu.WebGpuHostSurface::new(canvas_id~, metrics~)
    },
    create_renderer=_surface => (),
    resize=_metrics => (),
    measure_text=input => @core.TextSystem::fallback().measure_text(input),
    register_font_data=(_family, _data) => (),
    image_resource=source => {
      Some(
        @render.ImageResourceRecord::failed(source, diagnostic="load failed"),
      )
    },
    submit=_calls => (),
    dispose=() => (),
  )
  let renderer : WebRenderer = {
    renderer: @webgpu.create_renderer(
      canvas_id="moui-test-canvas",
      logical_size=@core.Size::new(width=100.0, height=50.0),
      port~,
    ),
  }
  renderer.render([
    @core.DrawCommand::DrawImage({
      source: "missing.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=10.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  inspect(resources[0].source, content="missing.png")
  assert_true(resources[0].status == @render.ImageResourceStatus::ImageFailed)
  inspect(resources[0].diagnostic, content="load failed")
}

///|
test "web renderer applies app-visible image load completions" {
  let port : @webgpu.WebGpuHostRendererPort = @webgpu.WebGpuHostRendererPort::new(
    capabilities=() => @webgpu.required_capabilities(),
    create_surface=(canvas_id, metrics) => {
      @webgpu.WebGpuHostSurface::new(canvas_id~, metrics~)
    },
    create_renderer=_surface => (),
    resize=_metrics => (),
    measure_text=input => @core.TextSystem::fallback().measure_text(input),
    register_font_data=(_family, _data) => (),
    image_resource=_source => None,
    submit=_calls => (),
    dispose=() => (),
  )
  let renderer : WebRenderer = {
    renderer: @webgpu.create_renderer(
      canvas_id="moui-test-canvas",
      logical_size=@core.Size::new(width=100.0, height=50.0),
      port~,
    ),
  }
  renderer.render([
    @core.DrawCommand::DrawImage({
      source: "async.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=10.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  let ready = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=30, height=15),
  )
  inspect(ready.revision, content="2")
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  assert_true(resources[0].status == @render.ImageResourceStatus::ImageReady)
  inspect(resources[0].width, content="30")
  inspect(resources[0].height, content="15")
}

///|
test "web maps close event to host event" {
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
test "web maps browser theme change to host theme event" {
  let event = window_event_to_host(
    @window_core.WindowEvent::ThemeChanged(@window_core.Theme::Dark),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::ThemeChanged(@core.ColorScheme::Dark)) => ()
    _ => fail("expected host theme change")
  }
}

///|
test "web maps surface resize to host metrics" {
  let event = window_event_to_host(
    @window_core.WindowEvent::SurfaceResized(
      @dpi.PhysicalSize::PhysicalSize(320, 200),
    ),
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
test "web maps scale factor changes to host metrics" {
  let writer = @window_core.SurfaceSizeWriter::SurfaceSizeWriter(
    @dpi.PhysicalSize::PhysicalSize(640, 360),
  )
  let event = window_event_to_host(
    @window_core.WindowEvent::ScaleFactorChanged(2.0, writer),
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::Resized(metrics)) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=320.0, height=180.0),
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
test "web maps pointer move and left button to host events" {
  let moved = window_event_to_host(
    @window_core.WindowEvent::PointerMoved(
      None,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(12.0, 34.0),
      true,
      @window_core.PointerSource::Mouse,
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match moved {
    Some(
      @host.HostEvent::Pointer(
        { position, phase: @core.PointerPhase::Move, .. }
      )
    ) => assert_true(position == @core.Point::new(x=12.0, y=34.0))
    _ => fail("expected pointer move")
  }

  let down = window_event_to_host(
    @window_core.WindowEvent::PointerButton(
      None,
      @window_core.ElementState::Pressed,
      @dpi.PhysicalPositionF64::PhysicalPositionF64(5.0, 6.0),
      true,
      @window_core.ButtonSource::Mouse(@window_core.MouseButton::Left),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  match down {
    Some(@host.HostEvent::Pointer({ position, phase, button, .. })) => {
      assert_true(position == @core.Point::new(x=5.0, y=6.0))
      assert_true(phase == @core.PointerPhase::Down)
      inspect(button, content="0")
    }
    _ => fail("expected pointer button")
  }
}

///|
test "web maps wheel and focus to host input events" {
  let wheel = window_event_to_host(
    @window_core.WindowEvent::MouseWheel(
      None,
      @window_core.MouseScrollDelta::LineDelta(0.0, -3.0),
      @window_core.TouchPhase::Moved,
    ),
    @core.Point::new(x=12.0, y=34.0),
  )
  match wheel {
    Some(
      @host.HostEvent::Scroll(
        {
          position: { x: 12.0, y: 34.0 },
          delta: @host.HostScrollDelta::Lines({ y: -3.0, .. }),
          ..,
        }
      )
    ) => ()
    _ => fail("expected scroll event")
  }
  let focus = window_event_to_host(
    @window_core.WindowEvent::Focused(true),
    @core.Point::new(x=0.0, y=0.0),
  )
  match focus {
    Some(@host.HostEvent::Focus({ focused: true, .. })) => ()
    _ => fail("expected focus event")
  }
}

///|
test "web maps keyboard modifiers repeat and text" {
  let key_event = @window_core.KeyEvent::KeyEvent(
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
test "web maps named keys and ignores synthetic keyboard input" {
  let key_event = @window_core.KeyEvent::KeyEvent(
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
test "web maps ime composition lifecycle and redraw" {
  let preedit = window_event_to_host(
    @window_core.WindowEvent::Ime(
      @window_core.Ime::Preedit(
        "ni",
        Some(@window_core.ImeCursorRange::ImeCursorRange(0, 2)),
      ),
    ),
    @core.Point::new(x=0.0, y=0.0),
  )
  let expected_preedit = Some(
    @host.HostEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text="ni",
          cursor=Some(@core.TextRange::new(start=0, end=2)),
        ),
      ),
    ),
  )
  match preedit {
    event if event == expected_preedit => ()
    _ => fail("expected composition update")
  }

  let ime = window_event_to_host(
    @window_core.WindowEvent::Ime(@window_core.Ime::Commit("hello")),
    @core.Point::new(x=0.0, y=0.0),
  )
  match ime {
    Some(@host.HostEvent::TextInput(@core.TextInputEvent::CompositionEnd(text))) =>
      inspect(text, content="hello")
    _ => fail("expected composition end")
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
