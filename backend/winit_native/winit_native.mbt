///|
pub(all) struct WinitNativeBackendInfo {
  host_info : @host.HostAppInfo
  wraps_current_windows_backend : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn backend_info() -> WinitNativeBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="winit native facade over the current native window backend",
    ),
    wraps_current_windows_backend: true,
    description: "Stable native host boundary for the future winit + wgpu renderer path; currently delegates to backend/windows on native Windows builds.",
  }
}

///|
pub fn run_counter_demo(title : String, runtime : @backend.AppRuntime) -> Unit {
  @windows.run_counter_demo(title, runtime)
}

///|
pub fn window_event_to_host(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @host.HostEvent? {
  @windows.window_event_to_host(event, last_pointer)
}

///|
pub fn window_event_to_core(
  event : @window_core.WindowEvent,
  last_pointer : @core.Point,
) -> @core.AppEvent? {
  @windows.window_event_to_core(event, last_pointer)
}
