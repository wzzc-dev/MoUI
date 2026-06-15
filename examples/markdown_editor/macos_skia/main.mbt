///|
fn main {
  let app = @app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services),
    width=980.0,
    height=640.0,
  )
  runtime.set_action_commands(app.action_commands(services~))
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  @macos_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(surface_route~),
  )
}
