///|
/// Window-hosted iOS Showcase entrypoint.
fn main {
  let runtime = @composition.runtime(
    host_summary=@ios_host.ios_capability_summary(),
    environment=@ios_host.app_environment(),
    route="platform/mobile-service-probe",
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted ios: waiting for HostCmd surface")
  @runtime.run_app("MoUI Showcase (ios window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(@ios_host.entry())
  .run()
}
