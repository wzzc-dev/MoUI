///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let plugin = @macos_webview.create_macos_webview_plugin(commands)
  let capabilities = @webview_host.HostWebViewCapabilities::native_available(
    description="macOS WKWebView native embedding is available.",
  )
  @moui.run_app(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(commands~, capabilities~),
      width=1120.0,
      height=760.0,
    ),
  )
  .render_all(@render_skia.from_env())
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
