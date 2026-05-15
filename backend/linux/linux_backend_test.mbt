///|
test "linux backend scaffold is explicit" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.window_backend_available, content="false")
  inspect(info.renderer_ready, content="false")
}
