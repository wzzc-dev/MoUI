///|
/// Result of a renderer recovery attempt after a context or presentation
/// failure.
pub(all) enum RecoveryResult {
  RecoverySucceeded
  RecoveryFailed(String)
  FallbackToCpu
}

///|
/// Result of asking one provider to bind a host surface. Rejection must be
/// inspection-only: a provider may not retain renderer or native-surface
/// resources unless it returns `Bound`.
pub(all) enum RendererBindResult {
  Bound(RendererSession)
  Rejected(String)
}

///|
/// Static renderer registration. The composition root registers providers in
/// preference order; `moui/render/common` invokes `bind` after the platform
/// window has produced an opaque `HostSurface`.
pub(all) struct RendererProvider {
  id : String
  descriptor : RendererDescriptor
  capabilities : () -> Array[RendererBackendFeatureCapability]
  bind : (HostSurface) -> RendererBindResult
}

///|
pub fn RendererProvider::new(
  id~ : String,
  descriptor~ : RendererDescriptor,
  capabilities~ : () -> Array[RendererBackendFeatureCapability],
  bind~ : (HostSurface) -> RendererBindResult,
) -> RendererProvider {
  { id, descriptor, capabilities, bind }
}

///|
pub fn RendererProvider::id(self : RendererProvider) -> String {
  self.id
}

///|
pub fn RendererProvider::descriptor(
  self : RendererProvider,
) -> RendererDescriptor {
  self.descriptor
}

///|
pub fn RendererProvider::capability_report(
  self : RendererProvider,
) -> Array[RendererBackendFeatureCapability] {
  (self.capabilities)()
}

///|
pub fn RendererProvider::bind_surface(
  self : RendererProvider,
  surface : HostSurface,
) -> RendererBindResult {
  (self.bind)(surface)
}
