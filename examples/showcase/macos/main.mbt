///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(@macos_backend.macos_capability_summary())
  @macos_backend.run_app("MoUI Showcase", runtime)
}
