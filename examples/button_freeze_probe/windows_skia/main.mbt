///|
fn main {
  @windows_skia_backend.run_app_with_options(
    "MoUI Button Freeze Probe",
    @app.runtime(),
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(),
  )
}
