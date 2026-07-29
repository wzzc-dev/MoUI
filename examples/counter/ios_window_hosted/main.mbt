///|
/// Window-hosted Counter for iOS: HostCmd / ApplicationHandler only.
fn main {
  let app = @ios_host.IosEmbeddedRuntimeBackend::new(
    title="MoUI Counter (window-hosted)",
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@counter_app.program(),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => @ios_skia_backend.renderer_provider(),
    auto_exit_after_frames=None,
  )
  println("moui-window-hosted ios counter: waiting for HostCmd surface")
  let event_loop = @window_ios.EventLoop::new()
  event_loop.run_app(app)
}
