///|
fn main {
  let services = @web.web_app_services()
  let event_sources = @host.HostPlatformEventSources::new()
  // Web has no HostTimerSource adapter yet; timer/anim cards stay idle unless
  // a future browser timer source is wired. Clipboard/file use async host services.
  let runtime = @runtime.new_program_with_dimensions(
    program=@platform_lab_app.program(
      services~,
      window_events=Some(event_sources.window_events()),
    ),
    width=720.0,
    height=780.0,
  )
  runtime.set_action_commands(@platform_lab_app.action_command_map())
  @web.run_app_with_options(
    "MoUI Platform Lab",
    runtime,
    options=@web.WebAppOptions::new(event_sources=Some(event_sources)),
  )
}
