///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@linux_host.linux_service_bridge(),
  )
  let timer_source = @linux_host.linux_timer_source()
  let event_sources = @host.HostPlatformEventSources::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=@platform_lab_app.program(
      services~,
      timer_source=Some(timer_source),
      window_events=Some(event_sources.window_events()),
    ),
    width=720.0,
    height=780.0,
  )
  runtime.set_action_commands(@platform_lab_app.action_command_map())
  @linux_skia_backend.run_app_with_options(
    "MoUI Platform Lab",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(
      event_sources=Some(event_sources),
    ),
  )
}
