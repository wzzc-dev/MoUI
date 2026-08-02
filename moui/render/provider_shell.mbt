///|
/// Shared `RendererProvider` assembly shell (ADR 0019). Provider entrypoints
/// used to each hand-roll the same `RendererInstance` disposed wrapper and
/// surface negotiation validation. This module owns that shell once; every
/// renderer keeps only its native factory closure, recovery policy, and
/// provider identity.
///
/// `new_provider_instance` wraps a live renderer with the standard disposed
/// guard: renders after dispose return a non-presented result, recover and
/// dispose are idempotent, and the underlying native dispose runs exactly
/// once.

///|
/// Build a `RendererInstance` from native render_frame/recover/dispose
/// closures, adding the shared disposed guard and single-dispose semantics.
pub fn new_provider_instance(
  render_frame~ : (@core.DrawFrame) -> RenderFrameResult,
  recover~ : (String) -> RecoveryResult,
  dispose~ : () -> Unit,
) -> RendererInstance {
  let disposed = Ref(false)
  RendererInstance::{
    render_frame: frame => {
      if disposed.val {
        return RenderFrameResult::new(presented=false)
      }
      render_frame(frame)
    },
    recover: reason => {
      if disposed.val {
        return RecoveryResult::RecoveryFailed("renderer is disposed")
      }
      recover(reason)
    },
    dispose: () => {
      if !disposed.val {
        disposed.val = true
        dispose()
      }
    },
  }
}

///|
/// Negotiate a `CpuRaster` surface for a provider that renders into CPU
/// pixel frames (or a web canvas). `label` and `id` keep the rejection
/// messages provider-specific: "{label} surface dimensions" and
/// "{id} provider does not accept GPU surfaces".
pub fn negotiate_cpu_raster_surface(
  surface : SurfaceDescriptor,
  label~ : String,
  id~ : String,
  presentation_model~ : RendererPresentationModel,
) -> SurfaceNegotiationResult {
  match surface {
    SurfaceDescriptor::CpuRaster(width, height, scale) =>
      if width >= 1.0 && height >= 1.0 && scale > 0.0 {
        SurfaceNegotiationResult::SurfaceAccepted(
          BoundSurface::new(
            kind=presentation_model,
            route=SkiaSurfaceRoute::RasterSurfaceRoute,
            metrics=RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor=scale,
            ),
          ),
        )
      } else {
        SurfaceNegotiationResult::SurfaceRejected(
          "invalid \{label} surface dimensions: \{width}x\{height} @ \{scale}x",
        )
      }
    SurfaceDescriptor::GpuSurface(_, _, _, _) =>
      SurfaceNegotiationResult::SurfaceRejected(
        "\{id} provider does not accept GPU surfaces",
      )
  }
}

///|
/// Negotiate a `GpuSurface` descriptor for a provider that renders into a
/// host GPU drawable. `route_for` maps the host handle to the renderer's
/// surface route (constant for providers with a single GPU path, handle
/// dependent for providers that support several). `label` and `id` keep the
/// rejection messages provider-specific: "{label} surface dimensions" and
/// "{id} provider does not accept CPU raster surfaces".
pub fn negotiate_gpu_surface(
  surface : SurfaceDescriptor,
  label~ : String,
  id~ : String,
  route_for~ : (GpuHostSurfaceDescriptor) -> SkiaSurfaceRoute,
) -> SurfaceNegotiationResult {
  match surface {
    SurfaceDescriptor::GpuSurface(handle, width, height, scale) =>
      if width >= 1.0 && height >= 1.0 && scale > 0.0 {
        SurfaceNegotiationResult::SurfaceAccepted(
          BoundSurface::new(
            kind=RendererPresentationModel::HostGpuSurface,
            route=route_for(handle),
            metrics=RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor=scale,
            ),
          ),
        )
      } else {
        SurfaceNegotiationResult::SurfaceRejected(
          "invalid \{label} surface dimensions: \{width}x\{height} @ \{scale}x",
        )
      }
    SurfaceDescriptor::CpuRaster(_, _, _) =>
      SurfaceNegotiationResult::SurfaceRejected(
        "\{id} provider does not accept CPU raster surfaces",
      )
  }
}
