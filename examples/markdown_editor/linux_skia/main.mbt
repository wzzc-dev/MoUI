///|
fn main {
  let app = @markdown_app.MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  let exit_after_first_present = @env.get_env_var(
      "MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  @linux_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(
      font_resolution~,
      exit_after_first_present~,
    ),
  )
}
