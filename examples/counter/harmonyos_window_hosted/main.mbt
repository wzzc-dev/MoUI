///|
/// Window-hosted Counter for HarmonyOS: HostCmd / ApplicationHandler only.
fn main {
  let app = @harmonyos_host.HarmonyOSEmbeddedRuntimeBackend::new(
    title="MoUI Counter (window-hosted)",
    runtime_factory=metrics => {
      @runtime.new_program(
        program=@counter_app.program(),
        size=metrics.logical_size,
      )
    },
    provider_factory=() => @harmonyos_skia_backend.renderer_provider(),
    auto_exit_after_frames=None,
  )
  println("moui-window-hosted harmonyos counter: waiting for HostCmd surface")
  let event_loop = @window_harmonyos.EventLoop::new()
  event_loop.run_app(app)
}
