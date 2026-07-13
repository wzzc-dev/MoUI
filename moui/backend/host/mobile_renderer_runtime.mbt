///|
let mobile_renderer_requested_mode : Ref[@render.NativeRendererMode] = Ref(
  @render.NativeRendererMode::Auto,
)

///|
/// Configure the process-wide mobile renderer preference before the first
/// surface is attached. Invalid values are rejected and leave the previous
/// preference unchanged.
pub fn mobile_renderer_configure(mode : String) -> Bool {
  match @render.NativeRendererMode::parse(mode) {
    Some(parsed) => {
      mobile_renderer_requested_mode.val = parsed
      true
    }
    None => false
  }
}

///|
pub fn mobile_renderer_requested() -> @render.NativeRendererMode {
  mobile_renderer_requested_mode.val
}

///|
pub fn mobile_renderer_selection(
  platform : @render.NativeGpuPlatform,
  gpu_available~ : Bool,
) -> @render.NativeRendererSelection {
  @render.select_native_renderer(
    platform,
    mobile_renderer_requested_mode.val,
    gpu_available~,
    gpu_promoted=platform.gpu_promoted(),
  )
}

///|
pub fn mobile_renderer_status_json(
  platform : @render.NativeGpuPlatform,
  gpu_available~ : Bool,
) -> String {
  let selection = mobile_renderer_selection(platform, gpu_available~)
  (
    {
      "platform": platform.label(),
      "requested": selection.requested.label(),
      "selected": selection.selected.label(),
      "surfaceRoute": selection.surface_route.label(),
      "gpuAvailable": selection.gpu_available,
      "gpuPromoted": selection.gpu_promoted,
      "fallbackReason": selection.fallback_reason,
    } : Json).stringify()
}
