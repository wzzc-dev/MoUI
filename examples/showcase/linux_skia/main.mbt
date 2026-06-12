///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(
    @linux_backend.linux_capability_summary(),
  )
  @linux_skia_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
