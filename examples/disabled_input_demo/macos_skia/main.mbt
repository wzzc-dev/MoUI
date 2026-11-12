///|
fn main {
  @apphost.run_app(
    "Disabled Input Demo",
    @runtime.new_program_with_dimensions(
      program=@disabled_demo.program(),
      width=520.0,
      height=520.0,
    ),
  )
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos.entry())
  .run()
}
