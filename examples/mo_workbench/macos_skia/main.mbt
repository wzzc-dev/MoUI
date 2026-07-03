///|
async fn main {
  // Try to create an OpenAI-compatible backend from environment variables.
  // Falls back to the stub (offline placeholder) when OPENAI_API_KEY is unset.
  let backend = match openai_backend_from_env() {
    Some(b) => b
    None => {
      println(
        "OPENAI_API_KEY not set — using stub backend. " +
        "Set OPENAI_API_KEY (and optionally OPENAI_BASE_URL) to connect."
      )
      @app.AgentBackendRuntime::stub()
    }
  }

  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program_with_backend(backend~),
    width=1300.0,
    height=680.0,
  )
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  // Use the async-pump variant so the moonbitlang/async event loop can drive
  // HTTP I/O alongside the MoUI/AppKit run loop.
  try {
    @macos_skia_backend.run_app_with_options_async_pump(
      "Mo Workbench",
      runtime,
      options=@macos_skia_backend.MacosSkiaAppOptions::new(surface_route~, transparent_titlebar=true),
    )
  } catch {
    err => println("App exited with error: \{err}")
  }
}
