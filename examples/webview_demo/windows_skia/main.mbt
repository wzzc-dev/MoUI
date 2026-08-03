///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let plugin = @windows_webview.create_windows_webview_plugin(commands)
  @moui.run_app(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(
        commands~,
        capabilities=@windows_webview.windows_webview_capabilities(),
      ),
      width=1120.0,
      height=760.0,
    ),
  )
  .render_all(@render_skia.from_env())
  .backend(
    @windows_backend.entry(
      options=@windows_backend.WindowsHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
