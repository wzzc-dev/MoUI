///|
pub struct WgpuRenderer {
  backend : @native_wgpu.RendererHandle
}

///|
pub type HostWgpuSurface = @wgpu_surface.HostWgpuSurface

///|
pub type SurfaceHostInfo = @wgpu_surface.SurfaceHostInfo

///|
pub fn create_renderer_placeholder() -> WgpuRenderer {
  { backend: @native_wgpu.RendererHandle::new() }
}

///|
pub fn create_placeholder() -> WgpuRenderer {
  create_renderer_placeholder()
}

///|
pub fn create_with_host_surface(
  size : @core.Size,
  surface : HostWgpuSurface,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  {
    backend: @native_wgpu.RendererHandle::create_with_host_surface(
      size,
      surface,
    ),
  }
}

///|
pub fn WgpuRenderer::resize(
  self : WgpuRenderer,
  size : @core.Size,
) -> Unit {
  self.backend.resize(size)
}

///|
pub fn WgpuRenderer::render(
  self : WgpuRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  self.backend.render(commands)
}

///|
pub fn WgpuRenderer::dispose(self : WgpuRenderer) -> Unit {
  self.backend.dispose()
}

///|
pub fn WgpuRenderer::last_batch_count(self : WgpuRenderer) -> Int {
  self.backend.last_batches.length()
}

///|
pub fn WgpuRenderer::present_count(self : WgpuRenderer) -> Int {
  self.backend.present_count
}
