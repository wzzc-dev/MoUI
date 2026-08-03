///|
fn main {
  @moui.run_app(
    "MoUI Design Systems",
    @runtime.new_program_with_dimensions(
      program=@design_systems_app.program(),
      width=960.0,
      height=680.0,
    ),
  )
  .render_all(@render_skia.from_env())
  .backend(@macos_backend.entry())
  .run()
}
