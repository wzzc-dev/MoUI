///|
extern "C" fn win32_hinstance() -> @wgpu_c.OpaquePtr = "moui_win32_hinstance"

///|
extern "C" fn win32_hwnd_from_u64(hwnd : UInt64) -> @wgpu_c.OpaquePtr = "moui_win32_hwnd_from_u64"

///|
pub(all) struct HostWgpuSurface {
  instance : @wgpu.Instance
  surface : @wgpu.Surface
}

///|
pub(all) struct SurfaceHostInfo {
  platform : String
  owns_instance : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct NativeSurfaceFactory {
}

///|
pub fn NativeSurfaceFactory::info() -> SurfaceHostInfo {
  {
    platform: "native",
    owns_instance: true,
    description: "Native surface factory owns platform handles and creates wgpu surfaces outside the renderer",
  }
}

///|
pub fn NativeSurfaceFactory::create_metal_layer(
) -> HostWgpuSurface raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let surface = instance.create_surface_metal_layer()
  { instance, surface }
}

///|
pub fn NativeSurfaceFactory::create_windows_hwnd(
  hwnd : UInt64,
) -> HostWgpuSurface raise @wgpu.WgpuError {
  let instance = @wgpu.Instance::create()
  let surface = instance.create_surface_windows_hwnd(
    win32_hinstance(),
    win32_hwnd_from_u64(hwnd),
  )
  { instance, surface }
}
