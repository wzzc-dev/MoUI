///|
fn main {
  let commands = @host.HostWebViewCommandQueue::new()
  @windows_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @webview_demo.runtime(
      commands~,
      capabilities=@windows_backend.windows_webview_capabilities(),
    ),
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(
      web_view_commands=Some(commands),
    ),
  )
}
