///|
fn main {
  let host = @webview_host.WebViewHost::new()
  let controller = @app.create_controller(host)
  let plugin = @windows_webview.create_windows_webview_plugin(host)
  let capabilities = @windows_webview.windows_webview_capabilities()
  let environment = @windows_backend.app_environment()
  let program = @app.runtime(capabilities~, controller~, environment~)
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=1280.0,
    height=820.0,
  )
  @runtime.run_app("DSH Desktop", runtime)
  .render(@render_skia.raster())
  .backend(
    @windows_backend.entry(
      options=@windows_backend.WindowsHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
