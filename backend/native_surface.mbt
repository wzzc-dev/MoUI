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
