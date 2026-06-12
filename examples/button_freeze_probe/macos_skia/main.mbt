///|
fn main {
  @macos_skia_backend.run_app_with_options(
    "MoUI Button Freeze Probe",
    @app.runtime(),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(),
  )
}
