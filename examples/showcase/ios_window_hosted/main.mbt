///|
/// Window-hosted iOS Showcase entrypoint.
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.ShowcaseApp::new().program_with_initial_route(
      "platform/mobile-service-probe",
    ),
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted ios: waiting for HostCmd surface")
  @moui.run_app("MoUI Showcase (ios window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(@ios_host.entry())
  .run()
}
