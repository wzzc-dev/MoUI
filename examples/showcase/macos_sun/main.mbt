///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@macos_backend.macos_service_bridge(),
  )
  let timer_source = @macos_backend.macos_timer_source()
  let app = @app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host(
      @macos_backend.macos_capability_summary(),
      services~,
      timer_source=Some(timer_source),
    ),
    width=1100.0,
    height=680.0,
  )
  runtime.set_action_commands(@app.action_command_map())
  let exit_after_first_present = @env.get_env_var(
      "MOUI_MACOS_SUN_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @macos_sun_backend.run_smoke_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@macos_sun_backend.MacosSunAppOptions::new(),
    smoke_options=@macos_sun_backend.MacosSunSmokeOptions::new(
      first_frame_smoke_auto_exit=exit_after_first_present,
    ),
  )
}
