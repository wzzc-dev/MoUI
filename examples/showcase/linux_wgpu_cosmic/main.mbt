///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime_with_host_summary(
    @linux_backend.linux_capability_summary(),
  )
  @linux_wgpu_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@linux_wgpu_backend.LinuxWgpuAppOptions::new(
      text_engine=@wgpu_renderer.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
