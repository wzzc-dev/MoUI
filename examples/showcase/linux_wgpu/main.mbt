///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host_summary(
      @linux_backend.linux_capability_summary(),
    ),
    width=1100.0,
    height=680.0,
  )
  @linux_wgpu_backend.run_app("MoUI Showcase", runtime)
}
