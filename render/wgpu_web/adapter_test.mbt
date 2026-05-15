///|
test "wgpu web adapter reports unsupported contract-only capability" {
  let info = adapter_info()
  assert_true(info.renderer.backend == @render.RendererBackendKind::WebGpuWasm)
  assert_true(
    info.renderer.status == @render.RendererCapabilityStatus::Unsupported,
  )
  assert_true(info.capability == WebGpuWasmCapability::ContractOnly)
  assert_true(
    info.surface_contract.source ==
    @render.WgpuSurfaceSourceKind::WebCanvasSurface,
  )
  inspect(info.renderer.can_render, content="false")
  inspect(info.surface_contract.ready, content="false")
  inspect(info.requires_secure_context, content="true")
}

///|
test "wgpu web device contract is explicit about missing bindings" {
  let contract = device_contract()
  inspect(contract.can_request_adapter, content="false")
  inspect(contract.can_request_device, content="false")
  inspect(contract.can_create_surface_from_canvas, content="false")
  inspect(contract.can_configure_surface, content="false")
  inspect(contract.can_create_render_pipeline, content="false")
  inspect(contract.can_present, content="false")
}

///|
test "wgpu web canvas surface records canvas id size and dpr" {
  let surface = create_canvas_surface(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=320.0, height=180.0),
    scale_factor=1.5,
  )
  inspect(surface.canvas_id, content="moui-web-wasm")
  assert_true(
    surface.metrics.logical_size == @core.Size::new(width=320.0, height=180.0),
  )
  assert_true(
    surface.metrics.physical_size == @core.Size::new(width=480.0, height=270.0),
  )
  inspect(surface.metrics.scale_factor, content="1.5")
}

///|
test "wgpu web placeholder renderer never presents before real binding exists" {
  let surface = create_canvas_surface(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
  )
  let renderer = create_renderer_placeholder(surface)
  assert_true(
    renderer.backend_kind() == @render.RendererBackendKind::WebGpuWasm,
  )
  assert_true(
    renderer.backend_info().status ==
    @render.RendererCapabilityStatus::Unsupported,
  )
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=200.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
  ])
  inspect(renderer.present_count(), content="0")
}
