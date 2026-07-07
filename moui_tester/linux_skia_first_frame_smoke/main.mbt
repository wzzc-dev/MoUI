///|
fn main {
  @linux_skia_backend.run_smoke_app_with_options(
    "MoUI Text Input Smoke",
    @fixture.runtime(),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
    ),
    smoke_options=@linux_skia_backend.LinuxSkiaSmokeOptions::new(
      first_frame_smoke_auto_exit=true,
    ),
  )
}
