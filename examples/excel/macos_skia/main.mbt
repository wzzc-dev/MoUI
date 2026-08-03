///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@macos_host.macos_service_bridge(),
  )
  let app = @excel_app.ExcelApp::new(services)
  let runtime = @runtime.new_program_with_dimensions(
    program=@excel_app.program_with_services(app, services),
    width=@excel_app.shell_width,
    height=@excel_app.shell_height,
  )
  runtime.set_action_commands(@excel_app.action_commands(app, services~))
  @moui.run_app("Excel", runtime)
    .render_all(@render_skia.from_env())
    .backend(@macos_host.entry())
    .run()
}
