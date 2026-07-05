///|
async fn main {
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  let app_options = @macos_skia_backend.MacosSkiaAppOptions::new(
    surface_route~,
    transparent_titlebar=true,
  )

  let settings_load = @openseek_transport.mo_workbench_load_settings_file
  let settings_persist = @openseek_transport.mo_workbench_persist_settings_file
  match settings_load() {
    Some(file) =>
      @openseek_transport.mo_workbench_apply_settings_file_to_process_env(file)
    None => ()
  }
  match @openseek_transport.openseek_backend_bundle_from_env() {
    Some(bundle) => {
      let runtime = @runtime.new_program_with_dimensions(
        program=@app.program_with_backend(
          backend=bundle.runtime,
          settings_load=Some(settings_load),
          settings_persist=Some(settings_persist),
        ),
        width=1300.0,
        height=680.0,
      )
      let window_task : async () -> Unit = async fn() {
        @macos_skia_backend.run_app_with_options_async_pump(
          "Mo Workbench",
          runtime,
          options=app_options,
        )
      }
      let worker_task : async () -> Unit = async fn() {
        @openseek_transport.openseek_worker_loop(bundle.owner)
      }
      try {
        let _ = @async.all([window_task, worker_task])
      } catch {
        err => println("App exited with error: \{err}")
      }
    }
    None => {
      println(
        "No API key — using stub backend. " +
        "Edit .mo_workbench/settings.json (created on first run) and set openai_api_key.",
      )
      let runtime = @runtime.new_program_with_dimensions(
        program=@app.program_with_backend(
          backend=@app.AgentBackendRuntime::stub(),
          settings_load=Some(settings_load),
          settings_persist=Some(settings_persist),
        ),
        width=1300.0,
        height=680.0,
      )
      try {
        @macos_skia_backend.run_app_with_options_async_pump(
          "Mo Workbench",
          runtime,
          options=app_options,
        )
      } catch {
        err => println("App exited with error: \{err}")
      }
    }
  }
}

