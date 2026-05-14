///|
fn test_renderer() -> @webgpu.WebGpuRenderer {
  test_renderer_impl()
}

///|
extern "js" fn test_renderer_impl() -> @webgpu.WebGpuRenderer =
  #|() => ({
  #|  resize() {},
  #|  begin() {},
  #|  clear() {},
  #|  fillRect() {},
  #|  drawText() {},
  #|  pushClip() {},
  #|  popClip() {},
  #|  present() {},
  #|  dispose() {},
  #|})

///|
test "winit web facade advertises shared web host model" {
  let info = backend_info()
  assert_true(info.host_info.backend == @host.HostBackendKind::Web)
  inspect(info.host_info.uses_shared_event_model, content="true")
  inspect(info.host_info.uses_shared_surface_model, content="true")
  inspect(info.host_info.uses_shared_input_model, content="true")
  inspect(info.uses_current_js_webgpu_backend, content="true")
  inspect(info.keeps_wasm_path_experimental, content="true")
}

///|
test "winit web facade creates app and forwards host dispatch" {
  let runtime = runtime_for_canvas(
    root=@core.ViewNode::Empty,
    width=80.0,
    height=40.0,
  )
  let app = new_app(runtime~, renderer=test_renderer())
  let result = host_dispatch(
    app,
    @host.HostEvent::Resized(
      @host.HostSurfaceMetrics::from_logical(
        size=@core.Size::new(width=120.0, height=60.0),
      ),
    ),
  )
  assert_true(surface_metrics(app).logical_size == @core.Size::new(width=120.0, height=60.0))
  inspect(result.redraw_requested, content="true")
}
