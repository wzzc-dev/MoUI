///|
/// Optional command-line argument: `macos_wgpu <document.md>` opens that
/// document on startup instead of the sample.
fn initial_document_from_args() -> String? {
  let args = @env.args()
  if args.length() > 1 && args[1] != "" {
    Some(args[1])
  } else {
    None
  }
}

///|
fn main {
  let runtime = @markdown_editor.runtime(
    environment=@macos_backend.app_environment(),
    initial_document_path=initial_document_from_args(),
  )
  let menus = @markdown_editor.application_menus()
  @runtime.run_app("MoUI Markdown Editor (WGPU)", runtime)
  .render(
    @render_wgpu.native(
      platform=@render_wgpu.WgpuNativePlatform::MacOS,
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_coretext.coretext_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(
    @macos_backend.entry(
      options=@macos_backend.MacosHostAppOptions::new(
        transparent_titlebar=true,
        on_ready=Some(@macos_backend.application_menu_on_ready(menus, runtime)),
        min_window_size=Some(@dpi.LogicalSize::LogicalSize(816.0, 480.0)),
      ),
    ),
  )
  .run()
}
