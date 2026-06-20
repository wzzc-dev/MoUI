///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@linux_host.linux_service_bridge(),
  )
  let app = @markdown_app.MarkdownEditorApp::new_with_services(services)
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services),
    width=980.0,
    height=640.0,
  )
  runtime.set_action_commands(app.action_commands(services~))
  @linux_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
