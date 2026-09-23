///|
/// Canonical feature ordering for a provider report. This is a feature
/// catalogue, not a renderer/backend selection matrix.
pub fn renderer_features() -> Array[@render.RendererFeature] {
  [
    Rect,
    RoundedRect,
    Gradient,
    Shadow,
    Text,
    Image,
    Clip,
    Transform,
    Opacity,
    LayerCompositing,
    BlendMode,
    FilterEffect,
    PathVector,
    ShaderEffect,
    TextShaping,
    EmojiText,
    AsyncImage,
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
