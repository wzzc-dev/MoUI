///|
fn main {
  let runtime = @composition.runtime(
    host_summary=@macos_backend.macos_capability_summary(),
    environment=@macos_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(@render_sun.raster())
  .backend(
    @macos_backend.entry(
      smoke_options=@macos_backend.MacosHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@composition.env_flag(
          "MOUI_MACOS_SUN_EXIT_AFTER_FIRST_PRESENT",
        ),
      ),
    ),
  )
  .run()
}
