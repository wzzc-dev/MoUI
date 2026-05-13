///|
pub(all) struct SurfaceBridgeInfo {
  uses_external_layer : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn default_surface_bridge_info() -> SurfaceBridgeInfo {
  {
    uses_external_layer: true,
    description: "Windows HWND surface supported; macOS CAMetalLayer path retained",
  }
}
