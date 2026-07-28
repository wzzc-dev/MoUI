///|
/// Build a Sun raster `RendererProvider` that creates `SunRasterRenderer`
/// instances via the given `create_sun` factory.
///
/// The `create_sun` closure receives metrics and returns a live Sun
/// raster renderer with its present target already wired. This lets the
/// platform entrypoint (macos, linux, windows, …) capture its own
/// `SunPresentTarget` without the provider needing to know the platform.
///
/// Capabilities are declared locally via `sun_feature_capabilities()`
/// (ADR 0019 Phase E) instead of the central `renderer_backend_capabilities`
/// matrix.
pub fn create_sun_provider(
  create_sun~ : (@render.RendererSurfaceMetrics) -> SunRasterRenderer,
) -> @render.RendererProvider {
  let caps = sun_feature_capabilities()
  @render.RendererProvider::{
    id: "sun-raster",
    descriptor: sun_raster_native_descriptor(),
    capabilities: () => caps,
    negotiate: sun_negotiate_surface,
    create: (metrics, _bound) => sun_create_instance(metrics, create_sun~),
  }
}

///|
/// Sun raster surface negotiation: only accepts `CpuRaster` surfaces
/// (CPU pixel frames).
fn sun_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  match surface {
    @render.SurfaceDescriptor::CpuRaster(width, height, scale) =>
      if width >= 1.0 && height >= 1.0 && scale > 0.0 {
        @render.SurfaceNegotiationResult::SurfaceAccepted(
          @render.BoundSurface::new(
            kind=@render.RendererPresentationModel::CpuPixelFrame,
            route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
            metrics=@render.RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor=scale,
            ),
          ),
        )
      } else {
        @render.SurfaceNegotiationResult::SurfaceRejected(
          "invalid Sun raster surface dimensions: \\{width}x\\{height} @ \\{scale}x",
        )
      }
    @render.SurfaceDescriptor::GpuSurface(_, _, _, _) =>
      @render.SurfaceNegotiationResult::SurfaceRejected(
        "sun-raster provider does not accept GPU surfaces",
      )
  }
}

///|
fn sun_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_sun~ : (@render.RendererSurfaceMetrics) -> SunRasterRenderer,
) -> @render.RendererInstance {
  let renderer = create_sun(metrics)
  let disposed = Ref(false)
  @render.RendererInstance::{
    render_frame: frame => {
      if disposed.val {
        return @render.RenderFrameResult::new(presented=false)
      }
      // SunRasterRenderer::render raises SunRendererError on failure.
      // Catch it and return a non-presented result.
      renderer.render(frame.commands) catch {
        _ => return @render.RenderFrameResult::new(presented=false)
      }
      @render.RenderFrameResult::new(presented=true)
    },
    recover: reason => {
      let _ = reason
      if disposed.val {
        return @render.RecoveryResult::RecoveryFailed("renderer is disposed")
      }
      @render.RecoveryResult::FallbackToCpu
    },
    dispose: () => {
      if !disposed.val {
        disposed.val = true
        renderer.dispose()
      }
    },
  }
}
