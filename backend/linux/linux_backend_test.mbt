///|
test "linux backend scaffold is explicit" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.window_backend_available, content="false")
  inspect(info.renderer_ready, content="false")
  inspect(info.capabilities.window, content="false")
  inspect(info.capabilities.accessibility, content="false")
}

///|
test "linux scaffold exposes host contracts without owning a surface" {
  let surface = scaffold_surface_host(
    logical_width=320.0,
    logical_height=200.0,
    scale_factor=2.0,
  )
  assert_true(
    surface.logical_size() == @core.Size::new(width=320.0, height=200.0),
  )
  inspect(surface.owns_surface, content="false")
  inspect(surface.can_reconfigure, content="false")
  let input = scaffold_input_host()
  inspect(input.text_input_supported, content="false")
  inspect(input.ime_supported, content="false")
}
