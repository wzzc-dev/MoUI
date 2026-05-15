///|
test "wgpu facade advertises native renderer backend" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::NativeWgpu)
  assert_true(info.status == @render.RendererCapabilityStatus::Ready)
  inspect(info.can_render, content="true")
  inspect(info.can_resize, content="true")
  inspect(info.owns_surface, content="false")
  let contract = native_surface_contract()
  assert_true(
    contract.source == @render.WgpuSurfaceSourceKind::NativeHostSurface,
  )
  inspect(contract.ready, content="true")
}

///|
test "wgpu renderer package re-exports native renderer boundary" {
  let renderer = create_placeholder()
  assert_true(
    renderer.backend_kind() == @render.RendererBackendKind::NativeWgpu,
  )
  assert_true(
    renderer.backend_info().backend == @render.RendererBackendKind::NativeWgpu,
  )
  renderer.resize(@core.Size::new(width=64.0, height=48.0))
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::gray(),
    ),
  ])
  inspect(renderer.last_batch_count(), content="1")
}

///|
test "wgpu facade keeps legacy placeholder alias" {
  let renderer = create_renderer_placeholder()
  renderer.render([])
  inspect(renderer.last_batch_count(), content="0")
}
