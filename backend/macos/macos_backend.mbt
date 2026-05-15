///|
pub(all) struct MacosBackendInfo {
  host_info : @host.HostAppInfo
  renderer_ready : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn backend_info() -> MacosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="macOS window host skeleton",
    ),
    renderer_ready: false,
    description: "macOS backend is a scaffold. window/macos is available, but Metal/native surface creation is not wired into MoUI yet.",
  }
}

///|
pub fn run_app(_title : String, _runtime : @core.AppRuntime) -> Unit {
  println(
    "backend/macos is a scaffold: Metal/native surface creation is not wired yet",
  )
}
