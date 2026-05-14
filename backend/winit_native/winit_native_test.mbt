///|
test "winit native facade advertises shared host model" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.host_info.uses_shared_event_model, content="true")
  inspect(info.host_info.uses_shared_surface_model, content="true")
  inspect(info.host_info.uses_shared_input_model, content="true")
  inspect(info.wraps_current_windows_backend, content="true")
}

///|
test "winit native facade forwards window event mapping to host event" {
  let event = window_event_to_host(
    @window_core.WindowEvent::CloseRequested,
    @core.Point::new(x=0.0, y=0.0),
  )
  match event {
    Some(@host.HostEvent::CloseRequested) => ()
    _ => fail("expected close requested")
  }
}
