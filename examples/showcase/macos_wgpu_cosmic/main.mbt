///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host_summary(
      @macos_backend.macos_capability_summary(),
    ),
    width=1100.0,
    height=680.0,
  )
  @macos_wgpu_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@macos_wgpu_backend.MacosWgpuAppOptions::new(
      text_engine=@wgpu_renderer.NativeTextEngineSetting::MoonCosmic,
    ),
  )
}
