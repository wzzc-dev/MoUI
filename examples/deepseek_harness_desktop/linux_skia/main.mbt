///|
fn main {
  let commands = @webview_host.HostWebViewCommandQueue::new()
  let patch = @fs.read_file_to_string(
    "examples/deepseek_harness_desktop/patch.js",
  ) catch {
    _ => ""
  }
  let plugin = @linux_webview.create_linux_webview_plugin(commands)
  let capabilities = @linux_webview.linux_webview_capabilities()
  let environment = @linux_backend.app_environment()
  let runtime = @harness.runtime(capabilities~, environment~, on_navigation_finished=_url => {
    if !patch.is_empty() {
      commands.evaluate_javascript(id="dsh-desktop-surface", script=patch)
    }
  })
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
