///|
/// Optional command-line argument: `windows_wgpu <document.md>` opens that
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
    environment=@windows_backend.app_environment(),
    initial_document_path=initial_document_from_args(),
  )
  @runtime.run_app("MoUI Markdown Editor (WGPU)", runtime)
  .render(
    @render_wgpu.native(
      platform=@render_wgpu.WgpuNativePlatform::Windows,
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_directwrite.directwrite_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(@windows_backend.entry())
  .run()
}
