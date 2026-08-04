///|
fn main {
  let runtime = @composition.runtime(
    host_summary=@windows_backend.windows_capability_summary(),
    environment=@windows_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(@render_sun.raster())
  .backend(
    @windows_backend.entry(
      smoke_options=@windows_backend.WindowsHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@composition.env_flag(
          "MOUI_WINDOWS_SUN_EXIT_AFTER_FIRST_PRESENT",
        ),
      ),
    ),
  )
  .run()
}
