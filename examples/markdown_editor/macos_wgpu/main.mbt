///|
fn main {
  let app = @app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services),
    width=1200.0,
    height=640.0,
  )
  runtime.set_action_commands(app.action_commands(services~))
  @macos_wgpu_backend.run_app("MoUI Markdown Editor", runtime)
}
