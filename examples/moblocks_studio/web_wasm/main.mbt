///|
fn main {
  @runtime.run_app(
    "MoBlocks Studio",
    @runtime.new_program_with_dimensions(
      program=@moblocks_app.program(environment=@web.app_environment()),
      width=1280.0,
      height=800.0,
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
