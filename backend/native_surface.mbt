///|
pub(all) struct SurfaceBridgeInfo {
  uses_external_layer : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn default_surface_bridge_info() -> SurfaceBridgeInfo {
  {
    uses_external_layer: false,
    description: "Platform-neutral backend does not own native surfaces",
  }
}

///|
pub fn platform_surface_host_info(
  platform~ : String,
  owns_surface? : Bool = true,
) -> SurfaceBridgeInfo {
  {
    uses_external_layer: owns_surface,
    description: "\{platform} backend owns platform surface creation and passes HostWgpuSurface to render/wgpu",
  }
}
