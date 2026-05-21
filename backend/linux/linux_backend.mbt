///|
pub(all) struct LinuxBackendInfo {
  host_info : @host.HostAppInfo
  window_backend_available : Bool
  renderer_ready : Bool
  capabilities : LinuxBackendCapabilities
  accessibility : LinuxAccessibilityBridgeInfo
  services : @host.HostServiceCapabilities
  readiness : LinuxBackendReadiness
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
pub(all) struct LinuxBackendReadiness {
  ready : Bool
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LinuxAccessibilityBridgeInfo {
  kind : @host.NativeAccessibilityBridgeKind
  contract_ready : Bool
  native_binding_ready : Bool
  action_roundtrip_ready : Bool
  description : String
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
pub fn service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::none()
}

///|
pub fn readiness() -> LinuxBackendReadiness {
  {
    ready: false,
    blocked_by: [
      "window/linux package is not available in the local window dependency",
      "native WGPU surface creation for Linux is not wired",
      "Linux accessibility bridge is not mapped from core semantics",
    ],
    next_steps: [
      "add or consume a window/linux package that emits shared HostEvent values",
      "create a native WGPU surface path and resize contract for Linux",
      "map clipboard, menus, file dialogs, and accessibility through host service contracts",
    ],
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
    accessibility: linux_accessibility_bridge_info(),
    services: service_capabilities(),
    readiness: readiness(),
    description: "Linux backend is a scaffold. The local window dependency does not expose a window/linux package yet.",
  }
}

///|
pub fn linux_accessibility_bridge_info() -> LinuxAccessibilityBridgeInfo {
  {
    kind: @host.NativeAccessibilityBridgeKind::ATSPI,
    contract_ready: true,
    native_binding_ready: false,
    action_roundtrip_ready: false,
    description: "Linux declares the AT-SPI accessibility bridge contract, but the backend remains unavailable until window/linux and native AT-SPI bindings exist.",
  }
}

///|
pub fn linux_accessibility_bridge() -> @host.NativeAccessibilityBridge {
  @host.NativeAccessibilityBridge::unavailable(
    kind=@host.NativeAccessibilityBridgeKind::ATSPI,
    reason="Linux AT-SPI accessibility bridge is unavailable until the Linux backend is implemented",
  )
}

///|
pub fn scaffold_service_bridge() -> @host.HostServiceBridge {
  @host.HostServiceBridge::unavailable()
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
    contract=@host.HostInputContract::new(
      capabilities=@host.HostInputCapabilities::none(),
      coordinates=@host.HostCoordinatePolicy::logical(
        description="Linux scaffold keeps the host contract shape but does not emit input events yet.",
      ),
    ),
  )
}

///|
pub fn run_app(_title : String, _runtime : @core.AppRuntime) -> Unit {
  println("backend/linux is a scaffold: window/linux is not available yet")
}
