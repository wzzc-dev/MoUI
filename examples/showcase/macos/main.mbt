///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime(width=760.0, height=420.0)
  @macos_backend.run_app("MoUI Showcase", runtime)
}
