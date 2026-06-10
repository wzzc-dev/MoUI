///|
fn main {
  let commands = @host.HostWebViewCommandQueue::new()
  @linux_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @webview_demo.runtime(
      commands~,
      capabilities=@linux_backend.linux_webview_capabilities(),
    ),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(
      web_view_commands=Some(commands),
    ),
  )
}
