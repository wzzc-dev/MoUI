///|
fn main {
  let app = @app.ShowcaseApp::new()
  let runtime = app.runtime()
  @macos_backend.run_app_with_options(
    "MoUI Showcase",
    runtime,
    options=@macos_backend.MacosAppOptions::new(
      renderer=@render.RendererSelection::Family(@render.RendererFamily::Skia),
    ),
  )
}
