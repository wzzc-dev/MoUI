///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime()
  @linux_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@linux_backend.LinuxAppOptions::new(
      text_engine=@wgpu.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
