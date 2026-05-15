///|
pub(all) struct HostWgpuSurface {
  instance : @wgpu_mbt.Instance
  surface : @wgpu_mbt.Surface
}

///|
pub(all) struct SurfaceHostInfo {
  platform : String
  owns_instance : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn HostWgpuSurface::new(
  instance~ : @wgpu_mbt.Instance,
  surface~ : @wgpu_mbt.Surface,
) -> HostWgpuSurface {
  { instance, surface }
}
