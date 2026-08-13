///|
fn main {
  let runtime = @showcase.runtime(
    host_summary=@macos_backend.macos_capability_summary(),
    environment=@macos_backend.app_environment(),
    initial_section_code=if @showcase.env_flag("MOUI_ACCESSIBILITY_PROBE") {
      2
    } else {
      0
    },
  )
  @runtime.run_app("MoUI Showcase", runtime)
  // .render(@render_skia.raster())
  .render(@render_skia.gpu(platform=@render_skia.NativeGpuPlatform::MacOS))
  .backend(
    @macos_backend.entry(
      smoke_options=@macos_backend.MacosHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@showcase.env_flag("MOUI_FIRST_FRAME_EXIT"),
      ),
    ),
  )
  .run()
}
