///|
fn main {
  @runtime.run_app(
    "MoUI Browser",
    @browser.runtime(environment=@macos_backend.app_environment()),
  )
  .render_all(@render_skia.from_env(platform=MacOS))
  .backend(@macos_backend.entry())
  .run()
}
