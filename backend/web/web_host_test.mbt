///|
test "web backend is wasm-gc only and rejects js fallback semantics" {
  let info = backend_info()
  inspect(info.uses_window_web_backend, content="true")
  inspect(info.requires_browser_webgpu_renderer, content="true")
  assert_true(
    info.renderer_info.backend == @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(
    info.renderer_info.status == @render.RendererCapabilityStatus::Ready,
  )
  assert_true(
    info.surface_contract.source ==
    @render.WgpuSurfaceSourceKind::WebCanvasSurface,
  )
  inspect(info.surface_contract.ready, content="true")
}

///|
test "canvas metrics promote dpr to host surface metrics" {
  let metrics = canvas_metrics(
    logical_width=200.0,
    logical_height=100.0,
    scale_factor=2.0,
  )
  assert_true(
    metrics.logical_size == @core.Size::new(width=200.0, height=100.0),
  )
  assert_true(
    metrics.physical_size == @core.Size::new(width=400.0, height=200.0),
  )
  inspect(metrics.scale_factor, content="2")
}

///|
test "web exposes host app info" {
  let info = web_host_info()
  assert_true(info.backend == @host.HostBackendKind::Web)
  inspect(info.uses_shared_event_model, content="true")
  inspect(info.uses_shared_surface_model, content="true")
  inspect(info.uses_shared_input_model, content="true")
}

///|
test "canvas host creates surface and input contracts" {
  let surface = canvas_surface_host(
    logical_width=100.0,
    logical_height=50.0,
    scale_factor=1.5,
  )
  assert_true(
    surface.logical_size() == @core.Size::new(width=100.0, height=50.0),
  )
  inspect(surface.owns_surface, content="false")
  inspect(surface.can_reconfigure, content="true")
  let input = canvas_input_host()
  inspect(input.focused, content="false")
  inspect(input.capabilities().text_input, content="true")
  inspect(input.capabilities().scroll, content="true")
  inspect(input.capabilities().ime, content="false")
  inspect(input.coordinate_policy().scale_factor_applied, content="true")
}

///|
test "web service bridge exposes open url and system theme scaffold" {
  let bridge = web_service_bridge(system_theme=@core.ColorScheme::Dark)
  match
    bridge.dispatch(@host.HostServiceRequest::OpenUrl("https://example.test")) {
    @host.HostServiceResponse::UrlOpened => ()
    _ => fail("expected URL opened scaffold response")
  }
  match bridge.dispatch(@host.HostServiceRequest::QuerySystemTheme) {
    @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Dark) => ()
    _ => fail("expected dark system theme")
  }
  match
    bridge.dispatch(
      @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText),
    ) {
    @host.HostServiceResponse::Unavailable(message) =>
      inspect(message, content="clipboard service is unavailable")
    _ => fail("expected clipboard to remain unavailable")
  }
}

///|
test "canvas host constraints document pointer and resize assumptions" {
  let constraints = canvas_host_constraints()
  inspect(constraints.requires_focusable_canvas, content="true")
  inspect(constraints.disallow_css_transform, content="true")
  inspect(constraints.disallow_canvas_border_padding, content="true")
  inspect(constraints.coordinates_are_logical_pixels, content="true")
}

///|
test "animation frame maps to redraw requested host event" {
  match request_animation_frame_event() {
    @host.HostEvent::RedrawRequested => ()
    _ => fail("expected redraw requested")
  }
}

///|
test "web accessibility maps semantics to aria nodes" {
  let checked = @core.State::new(true)
  let runtime = @core.AppRuntime::new_spec(
    root=@core.ViewSpec::CheckboxSpec({
      key: None,
      label: "Done",
      checked: checked.binding(),
      font: @core.FontSpec::new(),
      foreground: @core.Color::black(),
      check_color: @core.Color::blue(),
      size: @core.Size::new(width=20.0, height=32.0),
    }),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  let aria = semantics_to_aria(runtime.semantics())
  inspect(aria.role, content="checkbox")
  inspect(aria.label, content="Done")
  assert_true(aria.checked == Some(true))
}
