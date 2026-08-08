///|
fn main {
  let runtime = @showcase.runtime(
    host_summary=@linux_backend.linux_capability_summary(),
    environment=@linux_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Linux),
  )
  .backend(
    @linux_backend.entry(
      smoke_options=@linux_backend.LinuxHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@showcase.env_flag("MOUI_FIRST_FRAME_EXIT"),
      ),
    ),
  )
  .run()
}
