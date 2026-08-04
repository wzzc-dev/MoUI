///|
fn main {
  @runtime.run_app(
    "Mo Desktop",
    @runtime.new_program_with_dimensions(
      program=@mo_desktop_app.program(
        environment=@macos_backend.app_environment(),
        wall_clock=macos_desktop_clock,
      ),
      width=1280.0,
      height=800.0,
    ),
  )
  .render_all(@render_skia.from_env())
  .backend(@macos_backend.entry())
  .run()
}
