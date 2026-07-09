///|
fn main {
  @macos_skia_backend.run_app_with_options(
    "MoUI Platform Showcase",
    @runtime.new_program_with_dimensions(
      program=@platform_showcase_app.program(
        active_platform=@platform_showcase_app.PlatformId::MacOS,
      ),
      width=1040.0,
      height=720.0,
    ),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(),
  )
}
