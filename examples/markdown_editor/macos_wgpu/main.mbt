///|
fn main {
  let app = @app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let runtime = app.runtime_with_services(services, width=980.0, height=640.0)
  @macos_wgpu_backend.run_app("MoUI Markdown Editor", runtime)
}
