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
  let exit_after_first_present = @env.get_env_var(
      "MOUI_WINDOWS_SUN_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @moui.run_app("MoUI Showcase", runtime)
  .render(@render_sun.raster())
  .backend(
    @windows_backend.entry(
      smoke_options=@windows_backend.WindowsHostSmokeOptions::new(
        first_frame_smoke_auto_exit=exit_after_first_present,
      ),
    ),
  )
  .run()
}
