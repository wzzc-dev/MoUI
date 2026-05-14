///|
test "web wasm backend is experimental and keeps js fallback" {
  let info = experimental_backend_info()
  assert_true(info.status == WebWasmBackendStatus::Experimental)
  inspect(info.uses_winit_canvas_host, content="true")
  inspect(info.uses_wgpu_wasm_surface, content="true")
  inspect(info.keeps_js_webgpu_fallback, content="true")
}

///|
test "canvas metrics promote dpr to host surface metrics" {
  let metrics = canvas_metrics(
    logical_width=200.0,
    logical_height=100.0,
    scale_factor=2.0,
  )
  assert_true(metrics.logical_size == @core.Size::new(width=200.0, height=100.0))
  assert_true(metrics.physical_size == @core.Size::new(width=400.0, height=200.0))
  inspect(metrics.scale_factor, content="2")
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
