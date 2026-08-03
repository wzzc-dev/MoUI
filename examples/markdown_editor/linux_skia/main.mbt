///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@linux_host.linux_service_bridge(),
  )
  let app = @markdown_app.MarkdownEditorApp::new_with_services(services)
  let timer_source = @linux_host.linux_timer_source()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_services(services, timer_source=Some(timer_source)),
    width=1200.0,
    height=640.0,
  )
  runtime.set_action_commands(app.action_commands(services~))
  @moui.run_app("MoUI Markdown Editor", runtime)
  .render_all(@render_skia.from_env())
  .backend(@linux_host.entry())
  .run()
}
