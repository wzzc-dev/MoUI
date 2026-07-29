///|
/// Canonical feature ordering for a provider report. This is a feature
/// catalogue, not a renderer/backend selection matrix.
pub fn renderer_features() -> Array[RendererFeature] {
  [
    RendererFeature::Rect,
    RendererFeature::RoundedRect,
    RendererFeature::Gradient,
    RendererFeature::Shadow,
    RendererFeature::Text,
    RendererFeature::Image,
    RendererFeature::Clip,
    RendererFeature::Transform,
    RendererFeature::Opacity,
    RendererFeature::LayerCompositing,
    RendererFeature::BlendMode,
    RendererFeature::FilterEffect,
    RendererFeature::PathVector,
    RendererFeature::ShaderEffect,
    RendererFeature::TextShaping,
    RendererFeature::EmojiText,
    RendererFeature::AsyncImage,
  ]
}

///|
/// Build one provider-owned capability row per renderer feature. Providers
/// supply the status and note functions; `render` only preserves the common
/// feature ordering and carries the provider id into the report.
pub fn renderer_provider_capabilities(
  provider_id~ : String,
  backend~ : RendererBackendKind,
  capability_for~ : (RendererFeature) -> (RendererFeatureStatus, String),
) -> Array[RendererBackendFeatureCapability] {
  renderer_features().map(feature => {
    let (status, note) = capability_for(feature)
    RendererBackendFeatureCapability::new(
      provider_id~,
      feature~,
      backend~,
      status~,
      note~,
    )
  })
}

///|
pub fn RendererFeatureCapability::needs_follow_up(
  self : RendererFeatureCapability,
) -> Bool {
  self.providers.any(capability => capability.status.needs_follow_up())
}
