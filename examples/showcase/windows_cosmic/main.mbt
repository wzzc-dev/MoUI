///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(
    @windows_backend.windows_capability_summary(),
  )
  @windows_wgpu.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@windows_wgpu.WindowsWgpuAppOptions::new(
      text_engine=@wgpu_renderer.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
