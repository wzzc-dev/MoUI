///|
/// Build a Skia raster `RendererProvider` that creates `SkiaRasterRenderer`
/// instances via the given `create_raster` factory.
///
/// The `create_raster` closure receives metrics and returns a live
/// raster renderer with its present target already wired. This lets the
/// platform entrypoint (macos, linux, windows, …) capture its own
/// `SkiaPresentTarget` without the provider needing to know the platform.
pub fn create_skia_raster_provider(
  create_raster~ : (@render.RendererSurfaceMetrics) -> SkiaRasterRenderer,
) -> @render.RendererProvider {
  let caps = @render.renderer_backend_capabilities(
    @render.RendererBackendKind::SkiaRasterNative,
  )
  @render.RendererProvider::{
    id: "skia-raster",
    descriptor: skia_raster_native_descriptor(),
    capabilities: () => caps,
    negotiate: skia_negotiate_raster_surface,
    create: (metrics, _bound) => skia_create_instance(metrics, create_raster~),
  }
}

///|
/// Build a Skia hybrid (raster+GPU) `RendererProvider` that creates
/// `SkiaHybridRenderer` instances via the given `create_hybrid` factory.
///
/// The `create_hybrid` closure receives metrics and returns a hybrid
/// renderer with the platform present targets already wired.
pub fn create_skia_hybrid_provider(
  create_hybrid~ : (@render.RendererSurfaceMetrics) -> SkiaHybridRenderer,
) -> @render.RendererProvider {
  let caps = @render.renderer_backend_capabilities(
    @render.RendererBackendKind::SkiaGpuNative,
  )
  @render.RendererProvider::{
    id: "skia-hybrid",
    descriptor: skia_gpu_native_descriptor(),
    capabilities: () => caps,
    negotiate: skia_negotiate_gpu_surface,
    create: (metrics, _bound) => skia_create_hybrid_instance(
      metrics,
      create_hybrid~,
    ),
  }
}

///|
/// Default raster surface negotiation: accepts `CpuRaster` surfaces for
/// any logical size ≥ 1×1.
fn skia_negotiate_raster_surface(
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
          "invalid raster surface dimensions: \\{width}x\\{height} @ \\{scale}x",
        )
      }
    @render.SurfaceDescriptor::GpuSurface(_, _, _, _) =>
      @render.SurfaceNegotiationResult::SurfaceRejected(
        "skia-raster provider does not accept GPU surfaces",
      )
  }
}

///|
/// GPU surface negotiation: accepts GPU surfaces with a Metal, Vulkan,
/// EGL, or D3D12 handle.
fn skia_negotiate_gpu_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  match surface {
    @render.SurfaceDescriptor::GpuSurface(handle, width, height, scale) =>
      if width >= 1.0 && height >= 1.0 && scale > 0.0 {
        let route = skia_route_for_gpu_handle(handle)
        @render.SurfaceNegotiationResult::SurfaceAccepted(
          @render.BoundSurface::new(
            kind=@render.RendererPresentationModel::HostGpuSurface,
            route~,
            metrics=@render.RendererSurfaceMetrics::from_logical(
              size=@core.Size::new(width~, height~),
              scale_factor=scale,
            ),
          ),
        )
      } else {
        @render.SurfaceNegotiationResult::SurfaceRejected(
          "invalid GPU surface dimensions: \\{width}x\\{height} @ \\{scale}x",
        )
      }
    @render.SurfaceDescriptor::CpuRaster(_, _, _) =>
      @render.SurfaceNegotiationResult::SurfaceRejected(
        "skia-gpu provider does not accept CPU raster surfaces",
      )
  }
}

///|
fn skia_route_for_gpu_handle(
  handle : @render.GpuHostSurfaceDescriptor,
) -> @render.SkiaSurfaceRoute {
  match handle {
    @render.GpuHostSurfaceDescriptor::MetalLayer(_) =>
      @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(_) =>
      @render.SkiaSurfaceRoute::Direct3DGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::AndroidVulkanWindow(_) =>
      @render.SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(_, _) =>
      @render.SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::EglNativeWindow(_) =>
      @render.SkiaSurfaceRoute::EglGpuSurfaceRoute
  }
}

///|
fn skia_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_raster~ : (@render.RendererSurfaceMetrics) -> SkiaRasterRenderer,
) -> @render.RendererInstance {
  let renderer = create_raster(metrics)
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

///|
fn skia_create_hybrid_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_hybrid~ : (@render.RendererSurfaceMetrics) -> SkiaHybridRenderer,
) -> @render.RendererInstance {
  let hybrid = create_hybrid(metrics)
  let disposed = Ref(false)
  @render.RendererInstance::{
    render_frame: frame => {
      if disposed.val {
        return @render.RenderFrameResult::new(presented=false)
      }
      hybrid.render_frame(frame)
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
        let _ = hybrid.drain_present_completions()
      }
    },
  }
}
