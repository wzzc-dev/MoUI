///|
/// Window-hosted Android Showcase entrypoint.
fn main {
  let runtime = @showcase.runtime(
    host_summary=@android_host.android_capability_summary(),
    environment=@android_host.app_environment(),
    route="platform/mobile-service-probe",
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted android: waiting for HostCmd surface")
  @runtime.run_app("MoUI Showcase (android window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(
    @android_host.entry(
      options=@android_host.AndroidHostAppOptions::new(
        status_bar_immersive=true,
      ),
    ),
  )
  .run()
}
