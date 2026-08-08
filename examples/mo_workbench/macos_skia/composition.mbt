///|
async fn run_workbench() -> Unit {
  let app_options = @macos_host.MacosHostAppOptions::new(
    transparent_titlebar=true,
  )
  let environment = @macos_host.app_environment()

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
  let bundle = match settings_file {
    Some(file) =>
      @openseek_transport.openseek_backend_bundle_from_settings(file)
    None => None
  }
  let bundle = match bundle {
    Some(value) => Some(value)
    None => @openseek_transport.openseek_backend_bundle_from_env()
  }
  let model_detect = fn(
    base_url : String,
    api_key : String,
    on_result : (Array[String]?) -> Unit,
  ) -> Unit {
    match bundle {
      Some(value) =>
        @openseek_transport.openseek_enqueue_detect(
          value.owner,
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
    Some(value) => {
      let runtime = @runtime.new_program_with_dimensions(
        program=@app.program_with_backend(
          backend=value.runtime,
          settings_load=Some(settings_load),
          settings_persist=Some(settings_persist),
          model_detect=None,
          environment~,
        ),
        width=1300.0,
        height=680.0,
      )
      let window_task : async () -> Unit = async fn() {
        @runtime.run_app("Mo Workbench", runtime)
        .render_all(
          @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
        )
        .backend(@macos_host.entry(options=app_options))
        .run_async_pump()
      }
      let worker_task : async () -> Unit = async fn() {
        @acp_transport.acp_worker_loop(value.owner)
      }
      try {
        let _ = @async.all([window_task, worker_task])
      } catch {
        err => println("App exited with error: \{err}")
      }
    }
    None =>
      match bundle {
        Some(value) => {
          let runtime = @runtime.new_program_with_dimensions(
            program=@app.program_with_backend(
              backend=value.runtime,
              settings_load=Some(settings_load),
              settings_persist=Some(settings_persist),
              model_detect=Some(model_detect),
              environment~,
            ),
            width=1300.0,
            height=680.0,
          )
          let window_task : async () -> Unit = async fn() {
            @runtime.run_app("Mo Workbench", runtime)
            .render_all(
              @render_skia.from_env(
                platform=@render_skia.NativeGpuPlatform::MacOS,
              ),
            )
            .backend(@macos_host.entry(options=app_options))
            .run_async_pump()
          }
          let worker_task : async () -> Unit = async fn() {
            @openseek_transport.openseek_worker_loop(value.owner)
          }
          try {
            let _ = @async.all([window_task, worker_task])
          } catch {
            err => println("App exited with error: \{err}")
          }
        }
        None => {
          println(
            "No API key - using stub backend. " +
            "Edit .mo_workbench/settings.json (created on first run) and add a provider with an API key.",
          )
          let runtime = @runtime.new_program_with_dimensions(
            program=@app.program_with_backend(
              backend=@app.AgentBackendRuntime::stub(),
              settings_load=Some(settings_load),
              settings_persist=Some(settings_persist),
              model_detect=Some(model_detect),
              environment~,
            ),
            width=1300.0,
            height=680.0,
          )
          @runtime.run_app("Mo Workbench", runtime)
          .render_all(
            @render_skia.from_env(
              platform=@render_skia.NativeGpuPlatform::MacOS,
            ),
          )
          .backend(@macos_host.entry(options=app_options))
          .run_async_pump() catch {
            err => println("App exited with error: \{err}")
          }
        }
      }
  }
}
