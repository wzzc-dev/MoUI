///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let plugin = @windows_webview.create_windows_webview_plugin(commands)
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
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(platform_view_plugins=[
      plugin,
    ]),
  )
}
