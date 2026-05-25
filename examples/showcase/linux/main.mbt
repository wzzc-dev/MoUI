///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime()
  @linux_backend.run_app("MoUI Showcase", runtime)
}
