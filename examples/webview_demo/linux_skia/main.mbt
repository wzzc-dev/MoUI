///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  @linux_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(
        commands~,
        capabilities=@linux_webview.linux_webview_capabilities(),
      ),
      width=1120.0,
      height=760.0,
    ),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(
      web_view_commands=Some(commands),
    ),
  )
}
