///|
fn main {
  let app = @markdown_app.MarkdownEditorApp::new()
  let services = @host.HostAppServices::new(
    bridge=@windows_host.windows_service_bridge(),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services),
    width=1200.0,
    height=640.0,
  )
  runtime.set_action_commands(app.action_commands(services~))
  @moui.run_app("MoUI Markdown Editor", runtime)
  .render(@render_wgpu.native(text_engine=@wgpu_cosmic.cosmic_text_engine()))
  .backend(@windows_host.entry())
  .run()
}
