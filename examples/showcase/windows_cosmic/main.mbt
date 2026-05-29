///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(@windows_backend.windows_capability_summary())
  @windows_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@windows_backend.WindowsAppOptions::new(text_engine=MoonCosmic),
  )
}
