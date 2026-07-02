///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host_summary(
      @windows_backend.windows_capability_summary(),
    ),
    width=1100.0,
    height=680.0,
  )
  let exit_after_first_present = @env.get_env_var(
      "MOUI_WINDOWS_SUN_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @windows_sun_backend.run_smoke_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@windows_sun_backend.WindowsSunAppOptions::new(),
    smoke_options=@windows_sun_backend.WindowsSunSmokeOptions::new(
      first_frame_smoke_auto_exit=exit_after_first_present,
    ),
  )
}
