///|
/// Aggregate the capability declarations supplied by the providers registered
/// in a composition root. Reports are indexed by `RendererProvider.id`; the
/// optional backend classification inside a capability is diagnostic metadata
/// only and is never used to select or group providers.
pub fn renderer_feature_capability_report(
  providers : Array[RendererProvider],
) -> Array[RendererFeatureCapability] {
  renderer_features().map(feature => {
    let entries : Array[RendererBackendFeatureCapability] = []
    for provider in providers {
      for capability in (provider.capabilities)() {
        if capability.feature == feature &&
          capability.provider_id == provider.id {
          entries.push(capability)
        }
      }
    }
    RendererFeatureCapability::new(feature~, providers=entries)
  })
}

///|
pub fn renderer_feature_capability(
  providers : Array[RendererProvider],
  feature : RendererFeature,
) -> RendererFeatureCapability? {
  for entry in renderer_feature_capability_report(providers) {
    if entry.feature == feature {
      return Some(entry)
    }
  }
  None
}

///|
pub fn renderer_feature_follow_ups(
  providers : Array[RendererProvider],
) -> Array[RendererFeatureCapability] {
  let follow_ups : Array[RendererFeatureCapability] = []
  for entry in renderer_feature_capability_report(providers) {
    if entry.needs_follow_up() {
      follow_ups.push(entry)
    }
  }
  follow_ups
}
