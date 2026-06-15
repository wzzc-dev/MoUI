///|
fn main {
  @linux_skia_backend.run_app(
    "MoUI Design Systems",
    @runtime.new_program_with_dimensions(
      program=@design_systems_app.program(),
      width=960.0,
      height=680.0,
    ),
  )
}
