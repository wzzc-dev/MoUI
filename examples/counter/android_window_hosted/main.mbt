///|
/// Window-hosted Counter: lifecycle/surface/input from wzzc-dev/window/android.
/// On Android the native Activity loads this shared library and starts `main`
/// on a worker thread; HostCmd arrives via JNI into the window host queue.
fn main {
  let app = @android_host.AndroidEmbeddedRuntimeBackend::new(
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
  println("moui-window-hosted android counter: EventLoop starting")
  let event_loop = @window_android.EventLoop::new()
  event_loop.run_app(app)
}
