///|
fn main {
  let app = @app.MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  @macos_backend.run_app("MoUI Markdown Editor", runtime)
}
