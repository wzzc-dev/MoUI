///|
fn main {
  let runtime = @showcase.runtime(
    host_summary=@linux_backend.linux_capability_summary(),
    environment=@linux_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
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
