///|
fn main {
  @linux_skia_backend.run_app_with_options(
    "MoUI Button Freeze Probe",
    @app.runtime(),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
