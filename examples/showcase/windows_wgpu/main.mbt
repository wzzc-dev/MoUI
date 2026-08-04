///|
fn main {
  let runtime = @composition.runtime(
    host_summary=@windows_backend.windows_capability_summary(),
    environment=@windows_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(
    @render_wgpu.native(
      text_engine=@render_wgpu.native_platform_text_engine_with_fallback(
        @wgpu_directwrite.directwrite_text_provider(),
        fallback=@wgpu_cosmic.cosmic_text_engine(),
      ),
    ),
  )
  .backend(@windows_backend.entry())
  .run()
}
