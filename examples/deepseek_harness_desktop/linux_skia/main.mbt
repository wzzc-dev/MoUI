///|
fn main {
  let host = @webview_host.WebViewHost::new()
  let controller = @app.create_controller(host)
  let plugin = @linux_webview.create_linux_webview_plugin(host)
  let capabilities = @linux_webview.linux_webview_capabilities()
  let environment = @linux_backend.app_environment()
  let program = @app.runtime(capabilities~, controller~, environment~)
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=1280.0,
    height=820.0,
  )
  @runtime.run_app("DSH Desktop", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Linux),
  )
  .backend(
    @linux_backend.entry(
      options=@linux_backend.LinuxHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
