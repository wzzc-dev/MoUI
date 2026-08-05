///|
/// Canonical feature ordering for a provider report. This is a feature
/// catalogue, not a renderer/backend selection matrix.
pub fn renderer_features() -> Array[@render.RendererFeature] {
  [
    @render.RendererFeature::Rect,
    @render.RendererFeature::RoundedRect,
    @render.RendererFeature::Gradient,
    @render.RendererFeature::Shadow,
    @render.RendererFeature::Text,
    @render.RendererFeature::Image,
    @render.RendererFeature::Clip,
    @render.RendererFeature::Transform,
    @render.RendererFeature::Opacity,
    @render.RendererFeature::LayerCompositing,
    @render.RendererFeature::BlendMode,
    @render.RendererFeature::FilterEffect,
    @render.RendererFeature::PathVector,
    @render.RendererFeature::ShaderEffect,
    @render.RendererFeature::TextShaping,
    @render.RendererFeature::EmojiText,
    @render.RendererFeature::AsyncImage,
  ]
}

///|
/// Build one provider-owned capability row per renderer feature. Providers
/// supply the status and note functions; `render` only preserves the common
/// feature ordering and carries the provider id into the report.
pub fn renderer_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
  capability_for~ : (@render.RendererFeature) -> (
    @render.RendererFeatureStatus,
    String,
  ),
) -> Array[@render.RendererBackendFeatureCapability] {
  renderer_features().map(feature => {
    let (status, note) = capability_for(feature)
    @render.RendererBackendFeatureCapability::new(
      provider_id~,
      feature~,
      backend~,
      status~,
      note~,
    )
  })
}
