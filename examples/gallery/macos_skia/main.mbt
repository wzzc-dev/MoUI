///|
fn main {
  // Resolve through a Desktop `ThemeSpec` (not just a resolved theme) so a
  // host `ThemeChanged(Dark)` rebuild keeps the preset and its metrics.
  let environment = @moui.Environment::neutral().with_theme_spec(
    @views.desktop_theme_spec(),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=@gallery_app.program(),
    width=1080.0,
    height=820.0,
    environment~,
  )
  @apphost.run_app("MoUI Gallery", runtime)
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos.entry())
  .run()
}
