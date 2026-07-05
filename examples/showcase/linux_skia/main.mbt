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
  @linux_skia_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
