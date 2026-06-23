///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let plugin = @macos_webview.create_macos_webview_plugin(commands)
  let capabilities = @webview_host.HostWebViewCapabilities::native_available(
    description="macOS WKWebView native embedding is available.",
  )
  @macos_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(commands~, capabilities~),
      width=1120.0,
      height=760.0,
    ),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      webview_plugin=Some(plugin),
    ),
  )
}
