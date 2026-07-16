///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@linux_backend.linux_service_bridge(),
  )
  let timer_source = @linux_backend.linux_timer_source()
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host(
      @linux_backend.linux_capability_summary(),
      services~,
      timer_source=Some(timer_source),
    ),
    width=1100.0,
    height=680.0,
  )
  runtime.set_action_commands(@showcase_app.action_command_map())
  let exit_after_first_present = @env.get_env_var(
      "MOUI_LINUX_SUN_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @linux_sun_backend.run_smoke_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@linux_sun_backend.LinuxSunAppOptions::new(),
    smoke_options=@linux_sun_backend.LinuxSunSmokeOptions::new(
      first_frame_smoke_auto_exit=exit_after_first_present,
    ),
  )
}
