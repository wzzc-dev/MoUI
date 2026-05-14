///|
test "winit web wasm backend records current capability split" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::WebWasm)
  inspect(info.uses_window_web_backend, content="true")
  inspect(info.has_wgpu_wasm_renderer, content="false")
  inspect(info.keeps_js_webgpu_fallback, content="true")
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
      assert_true(metrics.logical_size == @core.Size::new(width=320.0, height=200.0))
      assert_true(metrics.physical_size == @core.Size::new(width=320.0, height=200.0))
    }
    _ => fail("expected resize event")
  }
}
