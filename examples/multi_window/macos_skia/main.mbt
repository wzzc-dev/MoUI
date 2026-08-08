///|
fn main {
  let (runtime, resolver, queue) = @multi_window.runtime_and_host()
  @runtime.run_app("MoUI Multi-Window", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(scene_resolver=resolver),
    ),
  )
  .window_requests(queue.requests())
  .run()
}
