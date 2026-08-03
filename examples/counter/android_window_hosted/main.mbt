///|
/// Window-hosted Counter: lifecycle/surface/input from wzzc-dev/window/android.
/// On Android the native Activity loads this shared library and starts `main`
/// on a worker thread; HostCmd arrives via JNI into the window host queue.
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@counter_app.program(),
    width=320.0,
    height=640.0,
  )
  println("moui-window-hosted android counter: EventLoop starting")
  @moui.run_app("MoUI Counter (window-hosted)", runtime)
  .render_all(@render_skia.from_env())
  .backend(@android_host.entry())
  .run()
}
