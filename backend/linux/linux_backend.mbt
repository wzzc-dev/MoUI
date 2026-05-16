///|
pub(all) struct LinuxBackendInfo {
  host_info : @host.HostAppInfo
  window_backend_available : Bool
  renderer_ready : Bool
  capabilities : LinuxBackendCapabilities
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinuxBackendCapabilities {
  window : Bool
  renderer : Bool
  pointer : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  accessibility : Bool
  scale_factor : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn capability_matrix() -> LinuxBackendCapabilities {
  {
    window: false,
    renderer: false,
    pointer: false,
    keyboard: false,
    text_input: false,
    ime: false,
    clipboard: false,
    accessibility: false,
    scale_factor: false,
  }
}

///|
pub fn backend_info() -> LinuxBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="Linux window host scaffold",
    ),
    window_backend_available: false,
    renderer_ready: false,
    capabilities: capability_matrix(),
    description: "Linux backend is a scaffold. The local window dependency does not expose a window/linux package yet.",
  }
}

///|
pub fn scaffold_surface_host(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.SurfaceHostState {
  @host.SurfaceHostState::new(
    metrics=@host.HostSurfaceMetrics::from_logical(
      size=@core.Size::new(width=logical_width, height=logical_height),
      scale_factor~,
    ),
    owns_surface=false,
    can_reconfigure=false,
  )
}

///|
pub fn scaffold_input_host() -> @host.InputHostState {
  @host.InputHostState::new(
    focused=false,
    text_input_supported=false,
    ime_supported=false,
    clipboard_supported=false,
  )
}

///|
pub fn run_app(_title : String, _runtime : @core.AppRuntime) -> Unit {
  println("backend/linux is a scaffold: window/linux is not available yet")
}
