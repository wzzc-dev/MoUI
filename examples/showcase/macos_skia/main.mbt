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
    transient_transport=match @native_services.dev_transient_transport_path() {
      Some(path) => Some(@native_services.dev_transient_transport(path))
      None => None
    },
  )
  match @devtools_publish.devtools_file_path() {
    Some(path) => @devtools_publish.install_devtools_publisher(runtime, path~)
    None => ()
  }
  @apphost.run_app("MoUI Showcase", runtime)
  // .render(@render_skia.raster())
  .render(@render_skia.gpu(platform=MacOS))
  .backend(
    @macos_backend.entry(
      smoke_options=@macos_backend.MacosHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@showcase.env_flag("MOUI_FIRST_FRAME_EXIT"),
      ),
    ),
  )
  .run()
}
