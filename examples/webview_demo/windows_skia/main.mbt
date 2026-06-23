///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  @windows_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(
        commands~,
        capabilities=@windows_webview.windows_webview_capabilities(),
      ),
      width=1120.0,
      height=760.0,
    ),
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(
      web_view_commands=Some(commands),
    ),
  )
}
