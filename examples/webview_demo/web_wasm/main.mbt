///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  @runtime.run_app(
    "MoUI WebView Demo",
    @composition.runtime(
      commands~,
      capabilities=@webview_host.HostWebViewCapabilities::unavailable(
        description="Web wasm does not embed native WebView.",
      ),
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
