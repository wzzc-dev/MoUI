///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@windows_host.windows_service_bridge(),
  )
  let app = @markdown_app.MarkdownEditorApp::new_with_services(services)
  let timer_source = @windows_host.windows_timer_source()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services, timer_source=Some(timer_source)),
    width=980.0,
    height=640.0,
  )
  runtime.set_action_commands(app.action_commands(services~))
  @windows_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(),
  )
}
