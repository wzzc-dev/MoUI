///|
fn main {
  let app = @app.MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  let exit_after_first_present = @env.get_env_var(
      "MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  @macos_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      exit_after_first_present~,
    ),
  )
}
