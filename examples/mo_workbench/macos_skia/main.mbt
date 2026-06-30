///|
fn main {
  // Stub backend: echoes a canned assistant reply so the UI is fully
  // interactive without an LLM. Replace with the openseek backend once the
  // upstream mooncakes resolution bug is fixed.
  let backend = @app.AgentBackendRuntime::stub()
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program_with_backend(backend~),
    width=980.0,
    height=680.0,
  )
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  @macos_skia_backend.run_app_with_options(
    "Mo Workbench",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(surface_route~),
  )
}
