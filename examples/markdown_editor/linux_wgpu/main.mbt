///|
/// Optional command-line argument: `linux_wgpu <document.md>` opens that
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
    environment=@linux_backend.app_environment(),
    initial_document_path=initial_document_from_args(),
  )
  @runtime.run_app("MoUI Markdown Editor (WGPU)", runtime)
  .render(
    @render_wgpu.native(
      platform=@render_wgpu.WgpuNativePlatform::Linux,
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_fontconfig.fontconfig_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(@linux_backend.entry())
  .run()
}
