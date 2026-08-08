///|
fn main {
  @runtime.run_app("MoUI PDF Workbench", pdf_workbench_runtime())
  .render_all(
    @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
  )
  .backend(@macos_host.entry())
  .run()
}
