///|
fn main {
  @runtime.run_app(
    "MoUI Counter",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
