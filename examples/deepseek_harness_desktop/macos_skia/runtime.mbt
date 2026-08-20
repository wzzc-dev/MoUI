///|
fn run_macos() -> Unit {
  let host = @webview_host.WebViewHost::new()
  let controller = @harness.create_controller(host)
  let plugin = @macos_webview.create_macos_webview_plugin(host)
  let capabilities = @macos_webview.macos_webview_capabilities()
  let environment = @macos_backend.app_environment()
  let runtime = @harness.runtime(capabilities~, controller~, environment~)
  let menus = @harness.application_menus()
  @runtime.run_app("DSH Desktop", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(
        transparent_titlebar=true,
        platform_view_plugins=[plugin],
        on_ready=Some(@macos_backend.application_menu_on_ready(menus, runtime)),
      ),
    ),
  )
  .run()
}
