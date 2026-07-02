///|
fn main {
  let app = @app.ShowcaseApp::new()
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host_summary(
      @macos_backend.macos_capability_summary(),
    ),
    width=1100.0,
    height=680.0,
  )
  @macos_skia_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(surface_route~),
  )
}
