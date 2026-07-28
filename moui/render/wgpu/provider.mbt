///|
/// Build a WGPU `RendererProvider` that creates `WgpuRenderer` instances
/// via the given `create_wgpu` factory.
///
/// The `create_wgpu` closure receives metrics and returns a live WGPU
/// renderer with its `HostWgpuSurface` and optional text engine already
/// wired. The platform entrypoint captures its own surface creation in
/// the closure, so the provider stays platform-agnostic.
pub fn create_wgpu_provider(
  create_wgpu~ : (@render.RendererSurfaceMetrics) -> WgpuRenderer,
) -> @render.RendererProvider {
  let caps = @render.renderer_backend_capabilities(
    @render.RendererBackendKind::NativeWgpu,
  )
  @render.RendererProvider::{
    id: "wgpu",
    descriptor: renderer_descriptor(),
    capabilities: () => caps,
    negotiate: wgpu_negotiate_surface,
    create: (metrics, _bound) => wgpu_create_instance(metrics, create_wgpu~),
  }
}

///|
/// WGPU surface negotiation: accepts `GpuSurface` descriptors when the
/// handle can be mapped to a WGPU-compatible platform surface.
fn wgpu_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  match surface {
    @render.SurfaceDescriptor::GpuSurface(_handle, width, height, scale) =>
      if width >= 1.0 && height >= 1.0 && scale > 0.0 {
        @render.SurfaceNegotiationResult::SurfaceAccepted(
          @render.BoundSurface::new(
            kind=@render.RendererPresentationModel::HostGpuSurface,
            route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
            metrics=@render.RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor=scale,
            ),
          ),
        )
      } else {
        @render.SurfaceNegotiationResult::SurfaceRejected(
          "invalid WGPU surface dimensions: \\{width}x\\{height} @ \\{scale}x",
        )
      }
    @render.SurfaceDescriptor::CpuRaster(_, _, _) =>
      @render.SurfaceNegotiationResult::SurfaceRejected(
        "wgpu provider does not accept CPU raster surfaces",
      )
  }
}

///|
fn wgpu_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_wgpu~ : (@render.RendererSurfaceMetrics) -> WgpuRenderer,
) -> @render.RendererInstance {
  let renderer = create_wgpu(metrics)
  let disposed = Ref(false)
  @render.RendererInstance::{
    render_frame: frame => {
      if disposed.val {
        return @render.RenderFrameResult::new(presented=false)
      }
      renderer.render(frame.commands)
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
