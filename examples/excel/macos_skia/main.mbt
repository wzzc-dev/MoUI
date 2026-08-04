///|
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@excel_app.program(environment=@macos_host.app_environment()),
    width=@excel_app.shell_width,
    height=@excel_app.shell_height,
  )
  @runtime.run_app("Excel", runtime)
  .render_all(@render_skia.from_env())
  .backend(@macos_host.entry())
  .run()
}
