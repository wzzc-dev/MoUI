///|
/// Window-hosted iOS Showcase entrypoint.
fn main {
  let app = @ios_host.IosWindowHostedApp::new(
    title="MoUI Showcase (ios window-hosted)",
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@app.ShowcaseApp::new().program_with_initial_route("platform/mobile-service-probe"),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => @ios_skia_backend.renderer_provider(),
    auto_exit_after_frames=None,
  )
  println("moui-window-hosted ios: waiting for HostCmd surface")
  let event_loop = @window_ios.EventLoop::new()
  event_loop.run_app(app)
}
