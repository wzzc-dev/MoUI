///|
/// Neutral surface descriptor for renderer-provider surface negotiation.
/// Replaces ad-hoc platform surface handling with a typed contract so host
/// and runtime stay renderer-agnostic.
pub(all) enum SurfaceDescriptor {
  /// CPU raster surface: width (logical), height (logical), scale_factor.
  CpuRaster(Double, Double, Double)
  /// GPU surface backed by a native window handle.
  GpuSurface(GpuHostSurfaceDescriptor, Double, Double, Double)
}

///|
/// Result of renderer-provider surface negotiation. `SurfaceAccepted` carries
/// a bound surface that the provider's `create` function can use to produce a
/// `RendererInstance`.
pub(all) enum SurfaceNegotiationResult {
  SurfaceAccepted(BoundSurface)
  SurfaceRejected(String)
}

///|
/// A bound render surface ready for rendering. Carries the presentation model,
/// Skia surface route (for Skia-family renderers), and metrics.
pub(all) struct BoundSurface {
  kind : RendererPresentationModel
  route : SkiaSurfaceRoute
  metrics : RendererSurfaceMetrics
}

///|
/// Result of a GPU recovery attempt after context loss.
pub(all) enum RecoveryResult {
  RecoverySucceeded
  RecoveryFailed(String)
  FallbackToCpu
}

///|
/// A live renderer instance produced by a `RendererProvider::create`. The
/// instance is bound to a specific surface and metrics, ready to render
/// frames, recover from GPU errors, and dispose.
pub(all) struct RendererInstance {
  /// Render a DrawFrame and return the frame result with cache stats.
  render_frame : (@core.DrawFrame) -> RenderFrameResult
  /// Attempt GPU or renderer recovery after a failure. Returns success,
  /// failure with a message, or a request to fall back to CPU rendering.
  recover : (String) -> RecoveryResult
  /// Tear down the instance and free all associated resources.
  dispose : () -> Unit
}

///|
/// A renderer provider declares its identity, capabilities, surface
/// negotiation, and instance factory. Providers are registered at
/// compile time in the composition root (moui/runtime or platform
/// entrypoint). The host and runtime consume providers through this
/// contract and never branch on renderer identity.
pub(all) struct RendererProvider {
  /// Renderer identity string (e.g. "skia-raster", "skia-gpu", "wgpu").
  id : String
  /// Static descriptor: backend kind, family, presentation model,
  /// supported targets, and capability list.
  descriptor : RendererDescriptor
  /// Dynamic capability report for this provider on the current host.
  /// Returns per-feature capabilities including notes.
  capabilities : () -> Array[RendererBackendFeatureCapability]
  /// Negotiate a surface descriptor. The provider checks whether it can
  /// render on the given surface and returns an accepted `BoundSurface`
  /// or a rejection with reason.
  negotiate : (SurfaceDescriptor) -> SurfaceNegotiationResult
  /// Create a renderer instance from metrics and a negotiated
  /// bound surface. The returned instance is ready to render.
  create : (RendererSurfaceMetrics, BoundSurface) -> RendererInstance
}

///|
/// Simple provider registry. Holds a list of registered `RendererProvider`
/// values and provides query helpers.
pub(all) struct RendererProviderRegistry {
  providers : Array[RendererProvider]
}

///|
pub fn RendererProviderRegistry::new() -> RendererProviderRegistry {
  { providers: [] }
}

///|
pub fn RendererProviderRegistry::register(
  self : RendererProviderRegistry,
  provider : RendererProvider,
) -> Unit {
  self.providers.push(provider)
}

///|
pub fn RendererProviderRegistry::providers(
  self : RendererProviderRegistry,
) -> Array[RendererProvider] {
  self.providers.copy()
}

///|
pub fn RendererProviderRegistry::lookup(
  self : RendererProviderRegistry,
  id : String,
) -> RendererProvider? {
  for provider in self.providers {
    if provider.id == id {
      return Some(provider)
    }
  }
  None
}

///|
pub fn RendererProviderRegistry::lookup_by_backend(
  self : RendererProviderRegistry,
  backend : RendererBackendKind,
) -> RendererProvider? {
  for provider in self.providers {
    if provider.descriptor.backend == backend {
      return Some(provider)
    }
  }
  None
}

///|
/// Find the best provider for a given surface descriptor by trying each
/// registered provider's `negotiate` in registration order. Returns the
/// first provider that accepts the surface, or `None` if no provider
/// accepts it.
pub fn RendererProviderRegistry::select(
  self : RendererProviderRegistry,
  surface : SurfaceDescriptor,
) -> (RendererProvider, BoundSurface)? {
  for provider in self.providers {
    match (provider.negotiate)(surface) {
      SurfaceNegotiationResult::SurfaceAccepted(bound) =>
        return Some((provider, bound))
      SurfaceNegotiationResult::SurfaceRejected(_) => ()
    }
  }
  None
}

///|
pub fn SurfaceDescriptor::cpu_raster(
  width~ : Double,
  height~ : Double,
  scale_factor~ : Double,
) -> SurfaceDescriptor {
  SurfaceDescriptor::CpuRaster(width, height, scale_factor)
}

///|
pub fn SurfaceDescriptor::gpu_surface(
  handle~ : GpuHostSurfaceDescriptor,
  width~ : Double,
  height~ : Double,
  scale_factor~ : Double,
) -> SurfaceDescriptor {
  SurfaceDescriptor::GpuSurface(handle, width, height, scale_factor)
}

///|
/// Convenience: create a registry from an array of providers.
pub fn RendererProviderRegistry::from_providers(
  providers : Array[RendererProvider],
) -> RendererProviderRegistry {
  { providers: providers.copy() }
}

///|
/// Provider-based selection for native renderer modes. Given a requested mode,
/// GPU availability, and promotion state, this method finds the matching
/// provider in the registry.
///
/// Returns the selected provider and its corresponding backend kind. When GPU
/// is requested but unavailable or unpromoted, falls back to the Skia raster
/// provider. Returns `None` if no matching provider is registered.
pub fn RendererProviderRegistry::select_native(
  self : RendererProviderRegistry,
  requested : NativeRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
) -> (RendererProvider, RendererBackendKind)? {
  let gpu_selected = match requested {
    NativeRendererMode::SkiaRaster => None
    NativeRendererMode::SkiaGpu =>
      if gpu_available {
        Some(RendererBackendKind::SkiaGpuNative)
      } else {
        None
      }
    NativeRendererMode::Auto =>
      if gpu_available && gpu_promoted {
        Some(RendererBackendKind::SkiaGpuNative)
      } else {
        None
      }
  }
  match gpu_selected {
    Some(backend) =>
      match self.lookup_by_backend(backend) {
        Some(provider) => Some((provider, backend))
        None =>
          self
          .lookup_by_backend(RendererBackendKind::SkiaRasterNative)
          .map(provider => (provider, RendererBackendKind::SkiaRasterNative))
      }
    None =>
      self
      .lookup_by_backend(RendererBackendKind::SkiaRasterNative)
      .map(provider => (provider, RendererBackendKind::SkiaRasterNative))
  }
}

///|
pub fn BoundSurface::new(
  kind~ : RendererPresentationModel,
  route~ : SkiaSurfaceRoute,
  metrics~ : RendererSurfaceMetrics,
) -> BoundSurface {
  { kind, route, metrics }
}

///|
pub fn BoundSurface::kind(self : BoundSurface) -> RendererPresentationModel {
  self.kind
}

///|
pub fn BoundSurface::route(self : BoundSurface) -> SkiaSurfaceRoute {
  self.route
}

///|
pub fn BoundSurface::metrics(self : BoundSurface) -> RendererSurfaceMetrics {
  self.metrics
}
