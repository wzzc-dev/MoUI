///|
fn main {
  @moui.run_app(
    "MoUI Counter",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
  .render_all(@render_skia.from_env())
  .backend(@macos.entry())
  .run()
}
