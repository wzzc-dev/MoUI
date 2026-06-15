///|
fn main {
  @macos_skia_backend.run_app_with_options(
    "MoUI Button Freeze Probe",
    @runtime.new_program_with_dimensions(
      program=@app.program(),
      width=560.0,
      height=360.0,
    ),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(),
  )
}
