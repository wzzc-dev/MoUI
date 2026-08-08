///|
fn main {
  @runtime.run_app(
    "MoUI Button Freeze Probe",
    @runtime.new_program_with_dimensions(
      program=@app.program(),
      width=560.0,
      height=360.0,
    ),
  )
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(@macos_backend.entry())
  .run()
}
