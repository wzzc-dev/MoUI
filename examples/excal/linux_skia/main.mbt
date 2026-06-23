///|
fn main {
  @linux_skia_backend.run_app_with_options(
    "Excal",
    @runtime.new_program_with_dimensions(
      program=@excal_app.program(),
      width=1000.0,
      height=700.0,
    ),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
