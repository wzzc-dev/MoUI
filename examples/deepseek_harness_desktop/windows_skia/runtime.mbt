///|
fn run_windows() -> Unit {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let patch = @fs.read_file_to_string(
    "examples/deepseek_harness_desktop/patch.js",
  ) catch {
    _ => ""
  }
  let plugin = @windows_webview.create_windows_webview_plugin(commands)
  let capabilities = @windows_webview.windows_webview_capabilities()
  let environment = @windows_backend.app_environment()
  let runtime = @harness.runtime(capabilities~, environment~, on_navigation_finished=_url => {
    if !patch.is_empty() {
      commands.evaluate_javascript(id="dsh-desktop-surface", script=patch)
    }
  })
  @runtime.run_app("DSH Desktop", runtime)
  .render(@render_skia.raster())
  // .render_all(
  //   @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Windows),
  // )
  .backend(
    @windows_backend.entry(
      options=@windows_backend.WindowsHostAppOptions::new(platform_view_plugins=[
        plugin,
      ]),
    ),
  )
  .run()
}
