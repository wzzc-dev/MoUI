///|
fn main {
  let app = @markdown_app.MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  @windows_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@windows_backend.WindowsAppOptions::new(text_engine=MoonCosmic),
  )
}
