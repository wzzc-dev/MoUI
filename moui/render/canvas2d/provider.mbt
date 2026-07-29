///|
/// Build a Canvas 2D `RendererProvider` that creates `Canvas2DRenderer`
/// instances via the given `create_canvas2d` factory.
///
/// The `create_canvas2d` closure receives metrics and returns a live
/// Canvas 2D renderer with its canvas ID already wired. This lets the
/// platform entrypoint (WeChat Mini Program, web) capture its own canvas
/// setup without the provider needing to know the platform details.
pub fn create_canvas2d_provider(
  create_canvas2d~ : (@render.RendererSurfaceMetrics) -> Canvas2DRenderer,
) -> @render.RendererProvider {
  let caps = @render.renderer_backend_capabilities(
    @render.RendererBackendKind::Canvas2DWasm,
  )
  @render.RendererProvider::{
    id: "canvas2d",
    descriptor: canvas2d_descriptor(),
    capabilities: () => caps,
    negotiate: canvas2d_negotiate_surface,
    create: (metrics, _bound) => {
      canvas2d_create_instance(metrics, create_canvas2d~)
    },
  }
}

///|
/// Canvas 2D surface negotiation: only accepts `CpuRaster` surfaces
/// (logical size via the canvas element).
fn canvas2d_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  match surface {
    @render.SurfaceDescriptor::CpuRaster(width, height, scale) =>
      if width >= 1.0 && height >= 1.0 && scale > 0.0 {
        @render.SurfaceNegotiationResult::SurfaceAccepted(
          @render.BoundSurface::new(
            kind=@render.RendererPresentationModel::WebCanvas,
            route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
            metrics=@render.RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor=scale,
            ),
          ),
        )
      } else {
        @render.SurfaceNegotiationResult::SurfaceRejected(
          "invalid Canvas 2D surface dimensions: \\{width}x\\{height} @ \\{scale}x",
        )
      }
    @render.SurfaceDescriptor::GpuSurface(_, _, _, _) =>
      @render.SurfaceNegotiationResult::SurfaceRejected(
        "canvas2d provider does not accept GPU surfaces",
      )
  }
}

///|
fn canvas2d_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_canvas2d~ : (@render.RendererSurfaceMetrics) -> Canvas2DRenderer,
) -> @render.RendererInstance {
  let renderer = create_canvas2d(metrics)
  let disposed = Ref(false)
  @render.RendererInstance::{
    render_frame: frame => {
      if disposed.val {
        return @render.RenderFrameResult::new(presented=false)
      }
      renderer.render_frame(frame)
    },
    recover: reason => {
      let _ = reason
      if disposed.val {
        return @render.RecoveryResult::RecoveryFailed("renderer is disposed")
      }
      @render.RecoveryResult::RecoverySucceeded
    },
    dispose: () => {
      if !disposed.val {
        disposed.val = true
        renderer.dispose()
      }
    },
  }
}
