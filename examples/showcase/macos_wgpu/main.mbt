///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host_summary(
      @macos_backend.macos_capability_summary(),
    ),
    width=960.0,
    height=560.0,
  )
  @macos_wgpu_backend.run_app("MoUI Showcase", runtime)
}
