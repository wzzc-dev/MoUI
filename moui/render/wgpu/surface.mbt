///|
pub struct HostWgpuSurface {
  priv instance : @wgpu_mbt.Instance
  priv surface : @wgpu_mbt.Surface
}

///|
pub struct SurfaceHostInfo {
  priv platform : String
  priv owns_instance : Bool
  priv description : String
} derive(Eq, Debug, ToJson)

///|
pub fn HostWgpuSurface::new(
  instance~ : @wgpu_mbt.Instance,
  surface~ : @wgpu_mbt.Surface,
) -> HostWgpuSurface {
  { instance, surface }
}

///|
pub fn HostWgpuSurface::instance(self : HostWgpuSurface) -> @wgpu_mbt.Instance {
  self.instance
}

///|
pub fn HostWgpuSurface::surface(self : HostWgpuSurface) -> @wgpu_mbt.Surface {
  self.surface
}

///|
pub fn SurfaceHostInfo::platform(self : SurfaceHostInfo) -> String {
  self.platform
}

///|
pub fn SurfaceHostInfo::owns_instance(self : SurfaceHostInfo) -> Bool {
  self.owns_instance
}

///|
pub fn SurfaceHostInfo::description(self : SurfaceHostInfo) -> String {
  self.description
}
