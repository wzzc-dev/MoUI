///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime()
  @macos_backend.run_app("MoUI Showcase", runtime)
}
