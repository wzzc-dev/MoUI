///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host_summary(
      @linux_backend.linux_capability_summary(),
    ),
    width=1100.0,
    height=680.0,
  )
  let exit_after_first_present = @env.get_env_var(
      "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  if exit_after_first_present {
    @linux_skia_backend.run_smoke_app_with_options(
      "MoUI Showcase",
      runtime,
      options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
      smoke_options=@linux_skia_backend.LinuxSkiaSmokeOptions::new(
        first_frame_smoke_auto_exit=true,
      ),
    )
  } else {
    @linux_skia_backend.run_app_with_options(
      "MoUI Showcase",
      runtime,
      options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
    )
  }
}
