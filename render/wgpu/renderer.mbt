///|
pub type WgpuRenderer = @native_wgpu.RendererHandle

///|
pub type HostWgpuSurface = @native_wgpu.HostWgpuSurface

///|
pub type SurfaceHostInfo = @native_wgpu.SurfaceHostInfo

///|
pub type SurfaceFactory = @native_wgpu.NativeSurfaceFactory

///|
pub fn create_renderer_placeholder() -> WgpuRenderer {
  @native_wgpu.RendererHandle::new()
}

///|
pub fn create_with_host_surface(
  size : @core.Size,
  surface : HostWgpuSurface,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  @native_wgpu.RendererHandle::create_with_host_surface(size, surface)
}

///|
pub fn surface_factory_info() -> SurfaceHostInfo {
  @native_wgpu.NativeSurfaceFactory::info()
}
