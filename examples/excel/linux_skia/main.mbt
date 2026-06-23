///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@linux_host.linux_service_bridge(),
  )
  let app = @excel_app.ExcelApp::new(services)
  let runtime = @runtime.new_program_with_dimensions(
    program=@excel_app.program_with_services(app, services),
    width=@excel_app.shell_width,
    height=@excel_app.shell_height,
  )
  runtime.set_action_commands(@excel_app.action_commands(app, services~))
  @linux_skia_backend.run_app_with_options(
    "Excel",
    runtime,
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(),
  )
}
