///|
fn main {
  let runtime = @showcase.runtime(
    host_summary=@linux_backend.linux_capability_summary(),
    environment=@linux_backend.app_environment(),
    // Screenshot/automation hook: open a diagnostics story directly so
    // `scripts/capture-showcase-sun.sh` can capture typical pages.
    initial_section_code=if @showcase.env_flag("MOUI_SHOWCASE_SECTION_1") {
      1
    } else if @showcase.env_flag("MOUI_SHOWCASE_SECTION_2") {
      2
    } else {
      0
    },
  )
  @apphost.run_app("MoUI Showcase", runtime)
  .render(@render_sun.raster())
  .backend(
    @linux_backend.entry(
      smoke_options=@linux_backend.LinuxHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@showcase.env_flag(
          "MOUI_LINUX_SUN_EXIT_AFTER_FIRST_PRESENT",
        ),
      ),
    ),
  )
  .run()
}
