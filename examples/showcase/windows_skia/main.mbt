///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(
    @windows_backend.windows_capability_summary(),
  )
  @windows_skia_backend.run_app("MoUI Showcase", runtime)
}
