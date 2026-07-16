///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@windows_backend.windows_service_bridge(),
  )
  let timer_source = @windows_backend.windows_timer_source()
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host(
      @windows_backend.windows_capability_summary(),
      services~,
      timer_source=Some(timer_source),
    ),
    width=1100.0,
    height=680.0,
  )
  runtime.set_action_commands(@showcase_app.action_command_map())
  @windows_skia_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(),
  )
}
