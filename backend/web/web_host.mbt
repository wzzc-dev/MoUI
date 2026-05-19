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
pub fn web_host_info() -> @host.HostAppInfo {
  @host.HostAppInfo::new(
    backend=@host.HostBackendKind::Web,
    description="window/web canvas + wasm-gc browser WebGPU host",
  )
}

///|
pub fn canvas_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.SurfaceHostState {
  @host.SurfaceHostState::new(
    metrics=canvas_metrics(logical_width~, logical_height~, scale_factor~),
    owns_surface=false,
    can_reconfigure=true,
  )
}

///|
pub fn canvas_input_host() -> @host.InputHostState {
  @host.InputHostState::new(
    focused=false,
    contract=@host.HostInputContract::new(
      capabilities=@host.HostInputCapabilities::new(
        pointer=true,
        scroll=true,
        keyboard=true,
        focus=true,
        text_input=true,
        ime=false,
        clipboard=false,
      ),
      coordinates=@host.HostCoordinatePolicy::logical(
        description="Web canvas host reports logical event coordinates after DPR mapping.",
      ),
    ),
  )
}

///|
pub fn request_animation_frame_event() -> @host.HostEvent {
  @host.HostEvent::RedrawRequested
}
