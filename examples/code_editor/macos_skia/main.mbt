///|
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@code_editor.program(),
    width=1180.0,
    height=760.0,
  )
  @runtime.run_app("MoUI Code Editor", runtime)
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(@macos_backend.entry())
  .run()
}
