///|
test "wgpu facade advertises native renderer backend" {
  let info = @moui_wgpu_renderer.backend_info()
  assert_true(info.backend == NativeWgpu)
  assert_true(info.status == Supported)
  inspect(info.can_render, content="true")
  inspect(info.can_resize, content="true")
  inspect(info.owns_surface, content="false")
  let contract = @moui_wgpu_renderer.native_surface_contract()
  assert_true(contract.source == NativeHostSurface)
  inspect(contract.ready, content="true")
}
