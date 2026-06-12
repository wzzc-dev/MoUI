///|
test "wgpu facade advertises native renderer backend" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::NativeWgpu)
  assert_true(info.status == @render.RendererCapabilityStatus::Supported)
  inspect(info.can_render, content="true")
  inspect(info.can_resize, content="true")
  inspect(info.owns_surface, content="false")
  let contract = native_surface_contract()
  assert_true(
    contract.source == @render.WgpuSurfaceSourceKind::NativeHostSurface,
  )
  inspect(contract.ready, content="true")
}
