///|
fn main {
  let runtime = @markdown_editor.runtime(
    environment=@macos_host.app_environment(),
  )
  let menus = @markdown_editor.application_menus()
  @runtime.run_app("MoUI Markdown Editor", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(
    @macos_host.entry(
      options=@macos_host.MacosHostAppOptions::new(
        transparent_titlebar=true,
        on_ready=Some(@macos_host.application_menu_on_ready(menus, runtime)),
        min_window_size=Some(@dpi.LogicalSize::LogicalSize(816.0, 480.0)),
      ),
    ),
  )
  .run()
}
