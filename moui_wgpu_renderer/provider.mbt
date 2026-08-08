///|
pub fn wgpu_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render_common.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let status = match feature {
      // Kept in line with the capability report's evidence gate: gradient and
      // transform support exists in the native WGPU visual pipeline, but the
      // diagnostic smoke has not yet recorded the required pixel markers, so
      // the self-report stays `Partial` until that evidence lands.
      @render.RendererFeature::Gradient | @render.RendererFeature::Transform =>
        @render.RendererFeatureStatus::Partial
      _ => @render.RendererFeatureStatus::Supported
    }
    (status, "Native WGPU provider declares \{feature.label()} support.")
  })
}
