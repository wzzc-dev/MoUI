///|
fn main {
  let commands = @host.HostWebViewCommandQueue::new()
  @macos_skia_backend.run_app_with_options(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(
        commands~,
        capabilities=@macos_backend.macos_webview_capabilities(),
      ),
      width=1120.0,
      height=760.0,
    ),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      web_view_commands=Some(commands),
    ),
  )
}
