///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime()
  @windows_backend.run_app("MoUI Showcase", runtime)
}
