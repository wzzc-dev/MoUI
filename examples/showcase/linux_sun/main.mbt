///|
fn main {
  let runtime = @composition.runtime(
    host_summary=@linux_backend.linux_capability_summary(),
    environment=@linux_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(@render_sun.raster())
  .backend(
    @linux_backend.entry(
      smoke_options=@linux_backend.LinuxHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@composition.env_flag(
          "MOUI_LINUX_SUN_EXIT_AFTER_FIRST_PRESENT",
        ),
      ),
    ),
  )
  .run()
}
