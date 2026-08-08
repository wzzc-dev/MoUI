///|
/// Window-hosted HarmonyOS Showcase entrypoint.
fn main {
  let runtime = @showcase.runtime(
    host_summary=@harmonyos_host.harmonyos_capability_summary(),
    environment=@harmonyos_host.app_environment(),
    route="platform/mobile-service-probe",
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted harmonyos: waiting for HostCmd surface")
  @runtime.run_app("MoUI Showcase (harmonyos window-hosted)", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::HarmonyOS),
  )
  .backend(@harmonyos_host.entry())
  .run()
}
