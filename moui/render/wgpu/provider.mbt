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
  let caps = wgpu_provider_capabilities(
    provider_id="wgpu",
    backend=@render.RendererBackendKind::NativeWgpu,
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
pub fn wgpu_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let status = match feature {
      // Kept in line with the capability report's evidence gate: gradient and
      // transform support exists in the native WGPU visual pipeline, but the
      // diagnostic smoke has not yet recorded the required pixel markers, so
      // the self-report stays `Partial` until that evidence lands.
      @render.RendererFeature::Gradient | @render.RendererFeature::Transform =>
        @render.RendererFeatureStatus::Partial
      _ => @render.RendererFeatureStatus::Supported
    }
    (status, "Native WGPU provider declares \{feature.label()} support.")
  })
}

///|
/// WGPU surface negotiation: accepts `GpuSurface` descriptors when the
/// handle can be mapped to a WGPU-compatible platform surface.
fn wgpu_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  @render.negotiate_gpu_surface(surface, label="WGPU", id="wgpu", route_for=_handle => {
    @render.SurfaceRoute::RasterSurfaceRoute
  })
}

///|
fn wgpu_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_wgpu~ : (@render.RendererSurfaceMetrics) -> WgpuRenderer,
) -> @render.RendererInstance {
  let renderer = create_wgpu(metrics)
  @render.new_provider_instance(
    render_frame=frame => {
      renderer.render(frame.commands)
      @render.RenderFrameResult::new(presented=true)
    },
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => renderer.dispose(),
  )
}
