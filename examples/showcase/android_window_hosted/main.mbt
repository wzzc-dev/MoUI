///|
/// Window-hosted Android Showcase entrypoint.
fn main {
  let app = @android_host.AndroidWindowHostedApp::new(
    title="MoUI Showcase (android window-hosted)",
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@app.ShowcaseApp::new().program_with_initial_route("platform/mobile-service-probe"),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => @android_skia_backend.renderer_provider(),
    auto_exit_after_frames=None,
  )
  println("moui-window-hosted android: waiting for HostCmd surface")
  let event_loop = @window_android.EventLoop::new()
  event_loop.run_app(app)
}
