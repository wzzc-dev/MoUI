///|
fn main {
  let (host, controller) = @webview_demo.create_controller()
  let plugin = @macos_webview.create_macos_webview_plugin(host)
  let capabilities = @webview_host.HostWebViewCapabilities::native_available(
    description="macOS WKWebView native embedding is available.",
  )
  @runtime.run_app(
    "MoUI WebView Demo",
    @webview_demo.runtime(controller~, capabilities~),
  )
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
