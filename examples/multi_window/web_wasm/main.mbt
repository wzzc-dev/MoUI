///|
fn main {
  let (runtime, resolver, queue) = @multi_window.runtime_and_host()
  @runtime.run_app("MoUI Multi-Window", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry(options=@web.WebAppOptions::new(scene_resolver=resolver)))
  .window_requests(queue.requests())
  .run()
}
