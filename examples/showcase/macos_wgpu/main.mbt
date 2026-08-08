///|
fn main {
  let runtime = @showcase.runtime(
    host_summary=@macos_backend.macos_capability_summary(),
    environment=@macos_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(
    @render_wgpu.native(
      platform=@render_wgpu.WgpuNativePlatform::MacOS,
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_coretext.coretext_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(@macos_backend.entry())
  .run()
}
