///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let plugin = @linux_webview.create_linux_webview_plugin(commands)
  @moui.run_app(
    "MoUI WebView Demo",
    @runtime.new_program_with_dimensions(
      program=@webview_demo.program(
        commands~,
        capabilities=@linux_webview.linux_webview_capabilities(),
      ),
      width=1120.0,
      height=760.0,
    ),
  )
  .render_all(@render_skia.from_env())
  .backend(
    @linux_backend.entry(
      options=@linux_backend.LinuxHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
