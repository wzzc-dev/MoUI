///|
fn main {
  @runtime.run_app(
    "MoUI Design Systems",
    @runtime.new_program_with_dimensions(
      program=@design_systems_app.program(),
      width=960.0,
      height=680.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
