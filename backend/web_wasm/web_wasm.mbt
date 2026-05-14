///|
pub(all) enum WebWasmBackendStatus {
  Experimental
  Ready
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebWasmBackendInfo {
  status : WebWasmBackendStatus
  uses_winit_canvas_host : Bool
  uses_wgpu_wasm_surface : Bool
  keeps_js_webgpu_fallback : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct CanvasHostConstraints {
  requires_focusable_canvas : Bool
  disallow_css_transform : Bool
  disallow_canvas_border_padding : Bool
  coordinates_are_logical_pixels : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn experimental_backend_info() -> WebWasmBackendInfo {
  {
    status: WebWasmBackendStatus::Experimental,
    uses_winit_canvas_host: true,
    uses_wgpu_wasm_surface: true,
    keeps_js_webgpu_fallback: true,
    description: "Experimental boundary for future winit canvas + wgpu wasm hosting; current JS WebGPU backend remains the default path.",
  }
}

///|
pub fn canvas_host_constraints() -> CanvasHostConstraints {
  {
    requires_focusable_canvas: true,
    disallow_css_transform: true,
    disallow_canvas_border_padding: true,
    coordinates_are_logical_pixels: true,
    description: "The web host owns canvas focus, DPR mapping, and raw pointer coordinates; CSS transforms, borders, and padding are avoided to keep resize and input coordinates stable.",
  }
}

///|
pub fn canvas_metrics(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.HostSurfaceMetrics {
  @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=logical_width, height=logical_height),
    scale_factor~,
  )
}

///|
pub fn request_animation_frame_event() -> @host.HostEvent {
  @host.HostEvent::RedrawRequested
}
