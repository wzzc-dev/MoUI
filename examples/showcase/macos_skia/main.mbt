///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime()
  let exit_after_first_present = @env.get_env_var(
      "MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @macos_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@macos_backend.MacosAppOptions::new(
      renderer=@render.RendererSelection::Family(@render.RendererFamily::Skia),
      exit_after_first_present~,
    ),
  )
}
