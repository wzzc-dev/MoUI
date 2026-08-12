///|
fn main {
  let runtime = @showcase.runtime(
    host_summary=@windows_backend.windows_capability_summary(),
    environment=@windows_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(@render_skia.raster())
  // .render_all(
  //   @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Windows),
  // )
  .backend(
    @windows_backend.entry(
      smoke_options=@windows_backend.WindowsHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@showcase.env_flag("MOUI_FIRST_FRAME_EXIT"),
      ),
    ),
  )
  .run()
}
