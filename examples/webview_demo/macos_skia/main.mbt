///|
fn main {
  let commands = @host.HostWebViewCommandQueue::new()
  @macos_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @webview_demo.runtime(
      commands~,
      capabilities=@macos_backend.macos_webview_capabilities(),
    ),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      web_view_commands=Some(commands),
    ),
  )
}
