///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(
    @linux_backend.linux_capability_summary(),
  )
  @linux_wgpu.run_app("MoUI Showcase", runtime)
}
