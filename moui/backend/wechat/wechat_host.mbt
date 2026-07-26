///|
/// WeChat Mini Program Canvas host constraints and helpers.
/// Analogous to the web host's canvas host, adapted for Mini Program constraints.

///|
pub(all) struct CanvasHostConstraints {
  requires_focusable_canvas : Bool
  disallow_css_transform : Bool
  disallow_canvas_border_padding : Bool
  coordinates_are_logical_pixels : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn canvas_host_constraints() -> CanvasHostConstraints {
  {
    requires_focusable_canvas: true,
    disallow_css_transform: true,
    disallow_canvas_border_padding: true,
    coordinates_are_logical_pixels: true,
    description: "The WeChat Mini Program host owns canvas focus, DPR mapping, and raw pointer coordinates.",
  }
}

///|
pub fn wechat_host_info() -> @host.HostAppInfo {
  @host.HostAppInfo::new(
    backend=@host.HostBackendKind::Wechat,
    description="window/wechat canvas + wasm-gc WeChat Mini Program Skyline host",
  )
}
