///|
/// Window-hosted Counter for Android: HostCmd / ApplicationHandler only (ADR 0015).
fn main {
  let app = @android_host.AndroidWindowHostedApp::new(
    title="MoUI Counter (window-hosted)",
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@counter_app.program(),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => @android_skia_backend.renderer_provider(),
    auto_exit_after_frames=None,
  )
  println("moui-window-hosted android counter: waiting for HostCmd surface")
  let event_loop = @window_android.EventLoop::new()
  event_loop.run_app(app)
}
