///|
fn main {
  let app = @app.MoWorkbenchApp::new()
  let runtime = app.runtime(width=1220.0, height=780.0)
  let exit_after_first_present = @env.get_env_var(
      "MO_WORKBENCH_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @macos_skia_backend.run_app_with_options(
    "Mo Workbench",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      exit_after_first_present~,
    ),
  )
}
