///|
fn main {
  let providers = @web_renderer.from_env()
  @runtime.run_app(
    "MoUI AI-Native UI Inspector",
    @app.runtime(),
  )
  .render_all(providers)
  .backend(@web.entry())
  .run()
}
