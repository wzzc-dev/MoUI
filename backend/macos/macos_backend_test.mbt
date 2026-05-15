///|
test "macos backend scaffold is explicit" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Native)
  inspect(info.renderer_ready, content="false")
}
