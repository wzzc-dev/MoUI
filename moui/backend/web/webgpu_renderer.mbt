///|
pub type WebRendererError = @webgpu.WebGpuHostError

///|
pub(all) struct WebRenderer {
  renderer : @webgpu.WebGpuWasmRenderer
}

///|
pub fn webgpu_renderer_backend_info() -> @render.RendererBackendInfo {
  @webgpu.backend_info()
}

///|
pub fn webgpu_canvas_surface_contract() -> @render.WgpuSurfaceContract {
  @webgpu.canvas_surface_contract()
}

///|
pub fn WebRenderer::create(
  canvas_id~ : String,
  metrics~ : @host.HostSurfaceMetrics,
) -> WebRenderer raise WebRendererError {
  {
    renderer: @webgpu.create_webgpu_renderer(
      canvas_id~,
      logical_size=metrics.logical_size,
      scale_factor=metrics.scale_factor,
    ),
  }
}

///|
pub fn WebRenderer::resize(
  self : WebRenderer,
  metrics : @host.HostSurfaceMetrics,
) -> Unit raise WebRendererError {
  self.renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=metrics.logical_size,
      physical_size=metrics.physical_size,
      scale_factor=metrics.scale_factor,
    ),
  )
}

///|
pub fn WebRenderer::render(
  self : WebRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise WebRendererError {
  self.renderer.render(commands)
}

///|
pub fn WebRenderer::text_system(self : WebRenderer) -> @core.TextSystem {
  self.renderer.text_system()
}

///|
pub fn WebRenderer::image_resources(
  self : WebRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.renderer.image_resources()
}

///|
pub fn WebRenderer::image_resource_snapshot(
  self : WebRenderer,
) -> @render.ImageResourceSnapshot {
  self.renderer.image_resource_snapshot()
}

///|
pub fn WebRenderer::dispose(self : WebRenderer) -> Unit {
  self.renderer.dispose()
}
