///|
/// Optional command-line argument: `windows_skia <document.md>` opens that
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
  @runtime.run_app("MoUI Markdown Editor", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Windows),
  )
  .backend(
    @windows_backend.entry(
      smoke_options=@windows_backend.WindowsHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@markdown_editor.env_flag(
          "MOUI_FIRST_FRAME_EXIT",
        ),
      ),
    ),
  )
  .run()
}
