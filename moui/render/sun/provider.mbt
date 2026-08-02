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
/// (ADR 0019 Phase E) instead of a central backend capability table.
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
/// (CPU pixel frames), via the shared provider shell.
fn sun_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  @render.negotiate_cpu_raster_surface(
    surface,
    label="Sun raster",
    id="sun-raster",
    presentation_model=@render.RendererPresentationModel::CpuPixelFrame,
  )
}

///|
fn sun_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_sun~ : (@render.RendererSurfaceMetrics) -> SunRasterRenderer,
) -> @render.RendererInstance {
  let renderer = create_sun(metrics)
  @render.new_provider_instance(
    render_frame=frame => {
      // SunRasterRenderer::render raises SunRendererError on failure.
      // Catch it and return a non-presented result.
      renderer.render(frame.commands) catch {
        _ => return @render.RenderFrameResult::new(presented=false)
      }
      @render.RenderFrameResult::new(presented=true)
    },
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => renderer.dispose(),
  )
}
