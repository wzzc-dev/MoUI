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
pub fn create_placeholder() -> WgpuRenderer {
  create_renderer_placeholder()
}

///|
pub fn create_with_host_surface(
  size : @core.Size,
  surface : HostWgpuSurface,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  @native_wgpu.RendererHandle::create_with_host_surface(size, surface)
}

///|
pub fn create_default_native_surface(
) -> HostWgpuSurface raise @wgpu_mbt.WgpuError {
  @native_wgpu.NativeSurfaceFactory::create_metal_layer()
}

///|
pub fn create_windows_hwnd_surface(
  hwnd : UInt64,
) -> HostWgpuSurface raise @wgpu_mbt.WgpuError {
  @native_wgpu.NativeSurfaceFactory::create_windows_hwnd(hwnd)
}

///|
pub fn create_with_windows_hwnd(
  size : @core.Size,
  hwnd : UInt64,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  create_with_host_surface(size, create_windows_hwnd_surface(hwnd))
}

///|
pub fn surface_factory_info() -> SurfaceHostInfo {
  @native_wgpu.NativeSurfaceFactory::info()
}
