///|
fn main {
  @apphost.run_app(
    "MoUI Web Hot Fixture",
    @runtime.new_program_with_dimensions(
      program=@web_hot_app.program_with_dev_state(),
      width=520.0,
      height=360.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
