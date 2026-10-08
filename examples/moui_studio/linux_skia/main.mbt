///|
/// MoUI Studio Linux Skia entry (composition root, momark template).
/// Differences from the macOS entry are platform capability gaps with
/// explicit degradation (see plan G6): no PTY terminal, no webview
/// preview, no wall-clock FFI, no immersive titlebar / window drag.
/// provider worker / compile track / build / persistence / MCP all reuse
/// the cross-platform async + x/fs machinery; missing capabilities are
/// presented structurally by the app (no crash, no hiding).

///|
fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
}

///|
async fn main {
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let owner = @provider.ProviderOwner::new()
  let compile_owner = @compile.CompileOwner::new()
  let launch_owner = @launch.LaunchOwner::new()
  let build_owner = @build_native.BuildOwner::new()
  let raw_config = @provider.load_provider_config(
    "examples/moui_studio/.config.json",
  ).unwrap_or(@provider.ProviderConfig::{
    endpoint: "",
    model: "",
    api_key: "",
  })
  let provider_config : @studio_app.ProviderConfig = {
    endpoint: raw_config.endpoint,
    model: raw_config.model,
    api_key: raw_config.api_key,
  }
  let focus_terminal = fn() {
    match runtime_ref.val {
      Some(runtime) => ignore(runtime.focus_key("terminal-input"))
      None => ()
    }
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=@studio_app.program(
      environment=@linux_backend.app_environment(),
      focus_terminal~,
      provider_config~,
      compile_track_available=true,
      export_available=true,
      sessions_store_path=".studio/ai_sessions.json",
      projects_store_path=".studio/projects.json",
      apply_locale=tag => {
        match runtime_ref.val {
          Some(runtime) =>
            runtime.set_environment(runtime.environment().with_locale(tag))
          None => ()
        }
      },
      provider_submit=(spec, on_result) => {
        @provider.provider_submit_prompt(
          owner,
          spec.endpoint,
          spec.key,
          spec.model,
          spec.system,
          spec.prompt,
          history=spec.history,
          json_mode=spec.json_mode,
          on_chunk=spec.on_chunk,
          on_result,
        )
      },
      compile_submit=(project_json, app_name, on_progress, on_result) => {
        @compile.compile_submit(compile_owner, @compile.CompileJob::{
          project_json,
          app_name,
          work_root: @compile.default_work_root(),
          on_progress,
          on_result,
        })
      },
      compile_cancel=fn() { @compile.compile_cancel(compile_owner) },
      launch_submit=(path, on_result) => {
        @launch.launch_submit(launch_owner, @launch.LaunchJob::{
          path,
          on_result,
        })
      },
      build_submit=(kind, root, entry_rel, on_result) => {
        @build_native.build_submit(build_owner, @build.BuildRequest::{
          kind,
          root,
          entry_rel,
          on_result,
        })
      },
      runtime_snapshot=() => {
        match runtime_ref.val {
          Some(runtime) => {
            let snapshot = runtime.inspector_snapshot()
            Some({
              summary: @devtools.snapshot_summary(snapshot).text(),
              report: @devtools.inspector_report_text(snapshot),
            })
          }
          None => None
        }
      },
    ),
    width=1280.0,
    height=800.0,
  )
  runtime_ref.val = Some(runtime)
  let host = @agent.RuntimeAgentHost::new(runtime)
  // The window is the primary task and workers are followers: when the
  // window returns, return_immediately cancels the followers (the same
  // shape as macOS's run_window_with_workers helper).
  @async.with_task_group(group => {
    group.spawn_bg(async fn() { @provider.provider_worker_loop(owner) })
    group.spawn_bg(async fn() { @compile.compile_worker_loop(compile_owner) })
    group.spawn_bg(async fn() { @launch.launch_worker_loop(launch_owner) })
    group.spawn_bg(async fn() { @build_native.build_worker_loop(build_owner) })
    group.spawn_bg(async fn() { @mcp_stdio.serve_with_diagnostics(host) })
    @runtime.run_app("MoUI Studio", runtime)
    .render_all(
      @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Linux),
    )
    .backend(
      @linux_backend.entry(
        smoke_options=@linux_backend.LinuxHostSmokeOptions::new(
          first_frame_smoke_auto_exit=env_flag("MOUI_FIRST_FRAME_EXIT"),
        ),
      ),
    )
    .run_async_pump()
    group.return_immediately(())
  })
}
