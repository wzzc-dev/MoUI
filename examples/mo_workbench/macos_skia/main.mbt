///|
async fn main {
  // Surface route defaults via MacosSkiaAppOptions (auto -> GPU when available;
  // override with MOUI_SKIA_RENDERER or MOUI_MACOS_SKIA_SURFACE_ROUTE).
  let app_options = @macos_skia_backend.MacosSkiaAppOptions::new(
    transparent_titlebar=true,
  )
  let host_services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )

  let settings_load = @openseek_transport.mo_workbench_load_settings_file
  let settings_persist = @openseek_transport.mo_workbench_persist_settings_file
  let settings_file = settings_load()
  match settings_file {
    Some(file) =>
      @openseek_transport.mo_workbench_apply_settings_file_to_process_env(file)
    None => ()
  }
  let acp_bundle = match settings_file {
    Some(file) => @acp_transport.acp_backend_bundle_from_settings(file)
    None => None
  }
  // Prefer the settings file's active provider; fall back to env vars.
  let bundle = match settings_file {
    Some(file) =>
      @openseek_transport.openseek_backend_bundle_from_settings(file)
    None => None
  }
  let bundle = match bundle {
    Some(b) => Some(b)
    None => @openseek_transport.openseek_backend_bundle_from_env()
  }
  // Model detection is a sync `ModelDetectFn` that enqueues an async HTTP job
  // onto the worker's task group; the worker reports results back via the
  // `on_result` callback (which dispatches `ModelsDetected` to the app).
  let model_detect = fn(
    base_url : String,
    api_key : String,
    on_result : (Array[String]?) -> Unit,
  ) -> Unit {
    match bundle {
      Some(b) =>
        @openseek_transport.openseek_enqueue_detect(
          b.owner,
          base_url,
          api_key,
          on_result,
        ) catch {
          _ => on_result(None)
        }
      None => on_result(None)
    }
  }
  match acp_bundle {
    Some(b) => {
      let runtime = @runtime.new_program_with_dimensions(
        program=@app.program_with_backend(
          backend=b.runtime,
          settings_load=Some(settings_load),
          settings_persist=Some(settings_persist),
          model_detect=None,
          host_services~,
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
        @acp_transport.acp_worker_loop(b.owner)
      }
      try {
        let _ = @async.all([window_task, worker_task])
      } catch {
        err => println("App exited with error: \{err}")
      }
    }
    None =>
      match bundle {
        Some(b) => {
          let runtime = @runtime.new_program_with_dimensions(
            program=@app.program_with_backend(
              backend=b.runtime,
              settings_load=Some(settings_load),
              settings_persist=Some(settings_persist),
              model_detect=Some(model_detect),
              host_services~,
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
            @openseek_transport.openseek_worker_loop(b.owner)
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
            "Edit .mo_workbench/settings.json (created on first run) and add a provider with an API key.",
          )
          let runtime = @runtime.new_program_with_dimensions(
            program=@app.program_with_backend(
              backend=@app.AgentBackendRuntime::stub(),
              settings_load=Some(settings_load),
              settings_persist=Some(settings_persist),
              model_detect=Some(model_detect),
              host_services~,
            ),
            width=1300.0,
            height=680.0,
          )
          @macos_skia_backend.run_app_with_options_async_pump(
            "Mo Workbench",
            runtime,
            options=app_options,
          ) catch {
            err => println("App exited with error: \{err}")
          }
        }
      }
  }
}
