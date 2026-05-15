///|
pub struct WgpuRenderer {
  priv backend : RendererHandle
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::NativeWgpu,
    status=@render.RendererCapabilityStatus::Ready,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="Native wgpu facade over wgpu_mbt/libwgpu_native; platform hosts provide HostWgpuSurface.",
  )
}

///|
pub fn native_surface_contract() -> @render.WgpuSurfaceContract {
  @render.WgpuSurfaceContract::new(
    source=@render.WgpuSurfaceSourceKind::NativeHostSurface,
    backend=@render.RendererBackendKind::NativeWgpu,
    ready=true,
    description="Native host owns HWND/Metal/window handles and passes an initialized wgpu surface to render/wgpu.",
  )
}

///|
pub fn create_with_host_surface(
  size : @core.Size,
  surface : HostWgpuSurface,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  { backend: RendererHandle::create_with_host_surface(size, surface) }
}

///|
pub fn WgpuRenderer::resize(self : WgpuRenderer, size : @core.Size) -> Unit {
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
pub fn WgpuRenderer::backend_kind(
  self : WgpuRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  @render.RendererBackendKind::NativeWgpu
}

///|
pub fn WgpuRenderer::backend_info(
  self : WgpuRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn WgpuRenderer::last_batch_count(self : WgpuRenderer) -> Int {
  self.backend.last_batches.length()
}

///|
pub fn WgpuRenderer::present_count(self : WgpuRenderer) -> Int {
  self.backend.present_count
}
