///|
fn main {
  @macos_skia_backend.run_app(
    "Mo Desktop",
    @runtime.new_program_with_dimensions(
      program=@mo_desktop_app.program(),
      width=1280.0,
      height=800.0,
    ),
  )
}
