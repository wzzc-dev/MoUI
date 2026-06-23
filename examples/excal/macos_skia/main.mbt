///|
fn main {
  @macos_skia_backend.run_app(
    "Excal",
    @runtime.new_program_with_dimensions(
      program=@excal_app.program(),
      width=1000.0,
      height=700.0,
    ),
  )
}
