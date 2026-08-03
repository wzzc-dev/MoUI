///|
/// Window-hosted HarmonyOS Showcase entrypoint.
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.ShowcaseApp::new().program_with_initial_route(
      "platform/mobile-service-probe",
    ),
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted harmonyos: waiting for HostCmd surface")
  @moui.run_app("MoUI Showcase (harmonyos window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(@harmonyos_host.entry())
  .run()
}
