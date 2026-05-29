///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(@macos_backend.macos_capability_summary())
  @macos_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@macos_backend.MacosAppOptions::new(
      text_engine=@wgpu.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
