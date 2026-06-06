///|
fn main {
  let app = @app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)
  let exit_after_first_present = @env.get_env_var(
      "MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  @macos_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      font_resolution~,
      exit_after_first_present~,
    ),
  )
}
