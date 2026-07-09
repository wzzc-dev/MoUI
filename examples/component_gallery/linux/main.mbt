///|
fn main {
  @linux_skia_backend.run_app_with_options(
    "Component Gallery",
    @runtime.new_program_with_dimensions(
      program=@component_gallery_app.program(
        active_platform=@component_gallery_app.PlatformId::Linux,
      ),
      width=1040.0,
      height=720.0,
    ),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
