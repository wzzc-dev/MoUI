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
  let exit_after_first_present = @env.get_env_var("MOUI_FIRST_FRAME_EXIT") ==
    Some("1")
  @moui.run_app("MoUI Showcase", runtime)
  .render_all(@render_skia.from_env())
  .backend(
    @linux_backend.entry(
      smoke_options=@linux_backend.LinuxHostSmokeOptions::new(
        first_frame_smoke_auto_exit=exit_after_first_present,
      ),
    ),
  )
  .run()
}
