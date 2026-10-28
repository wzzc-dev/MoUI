///|
fn main {
  // The identity line a presentation gate greps for. The host's own marker names
  // the platform, not the renderer, so a gate that read only that line would pass
  // while any other renderer presented; this one is built from the descriptor and
  // the capability rows the module publishes, so it says which route was selected.
  let capabilities = @render_metal.metal_feature_capabilities()
  let descriptor = @render_metal.metal_renderer_descriptor(capabilities)
  println(
    "MoUI macos_metal renderer=\{descriptor.backend.short_label()} family=\{descriptor.family.label()} provider=\{capabilities[0].provider_id}",
  )
  let runtime = @showcase.runtime(
    host_summary=@macos_backend.macos_capability_summary(),
    environment=@macos_backend.app_environment(),
  )
  @runtime.run_app("MoUI Showcase", runtime)
  .render(
    @render_metal.metal(
      text_engine=@render_metal.native_platform_text_engine(
        @text_coretext.coretext_text_provider(),
      ),
    ),
  )
  .backend(
    @macos_backend.entry(
      smoke_options=@macos_backend.MacosHostSmokeOptions::new(
        first_frame_smoke_auto_exit=@showcase.env_flag(
          "MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT",
        ),
      ),
    ),
  )
  .run()
}
