///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let patch = @fs.read_file_to_string(
    "examples/deepseek_harness_desktop/patch.js",
  ) catch {
    _ => ""
  }
  let plugin = @macos_webview.create_macos_webview_plugin(commands)
  let capabilities = @macos_webview.macos_webview_capabilities()
  let environment = @macos_backend.app_environment()
  let runtime = @harness.runtime(capabilities~, environment~, on_navigation_finished=_url => {
    if !patch.is_empty() {
      commands.evaluate_javascript(id="dsh-desktop-surface", script=patch)
    }
  })
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
