///|
/// Window-hosted HarmonyOS Showcase entrypoint.
fn main {
  let app = @harmonyos_host.HarmonyOsWindowHostedApp::new(
    title="MoUI Showcase (harmonyos window-hosted)",
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@app.ShowcaseApp::new().program_with_initial_route("platform/mobile-service-probe"),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => @harmonyos_skia_backend.renderer_provider(),
    auto_exit_after_frames=None,
  )
  println("moui-window-hosted harmonyos: waiting for HostCmd surface")
  let event_loop = @window_harmonyos.EventLoop::new()
  event_loop.run_app(app)
}
