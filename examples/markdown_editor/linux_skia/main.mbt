///|
fn main {
  let app = @markdown_app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@linux_host.linux_service_bridge(),
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)
  @linux_skia_backend.run_app_with_options(
    "MoUI Markdown Editor",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
