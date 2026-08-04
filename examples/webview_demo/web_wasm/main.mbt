///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  @runtime.run_app(
    "MoUI WebView Demo",
    @webview_demo.runtime(
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
