///|
pub(all) struct LinuxBackendInfo {
  host_info : @host.HostAppInfo
  window_backend_available : Bool
  renderer_ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn backend_info() -> LinuxBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="Linux window host scaffold",
    ),
    window_backend_available: false,
    renderer_ready: false,
    description: "Linux backend is a scaffold. The local window dependency does not expose a window/linux package yet.",
  }
}

///|
pub fn run_app(_title : String, _runtime : @core.AppRuntime) -> Unit {
  println("backend/linux is a scaffold: window/linux is not available yet")
}
