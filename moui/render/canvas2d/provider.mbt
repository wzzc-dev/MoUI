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
  let caps = canvas2d_provider_capabilities(
    provider_id="wxCanvas2d",
    backend=@render.RendererBackendKind::Canvas2DWasm,
  )
  @render.RendererProvider::{
    id: "wxCanvas2d",
    descriptor: canvas2d_descriptor(),
    capabilities: () => caps,
    negotiate: canvas2d_negotiate_surface,
    create: (metrics, _bound) => {
      canvas2d_create_instance(metrics, create_canvas2d~)
    },
  }
}

///|
pub fn canvas2d_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
    let status = match feature {
      @render.RendererFeature::RoundedRect
      | @render.RendererFeature::Gradient
      | @render.RendererFeature::TextShaping
      | @render.RendererFeature::EmojiText =>
        @render.RendererFeatureStatus::Partial
      @render.RendererFeature::Image
      | @render.RendererFeature::AsyncImage
      | @render.RendererFeature::LayerCompositing
      | @render.RendererFeature::BlendMode
      | @render.RendererFeature::FilterEffect
      | @render.RendererFeature::ShaderEffect =>
        @render.RendererFeatureStatus::Gap
      _ => @render.RendererFeatureStatus::Supported
    }
    (status, "WeChat Canvas2D provider declares \{feature.label()} support.")
  })
}

///|
/// Canvas 2D surface negotiation: only accepts `CpuRaster` surfaces
/// (logical size via the canvas element).
fn canvas2d_negotiate_surface(
  surface : @render.SurfaceDescriptor,
) -> @render.SurfaceNegotiationResult {
  @render.negotiate_cpu_raster_surface(
    surface,
    label="Canvas 2D",
    id="canvas2d",
    presentation_model=@render.RendererPresentationModel::WebCanvas,
  )
}

///|
fn canvas2d_create_instance(
  metrics : @render.RendererSurfaceMetrics,
  create_canvas2d~ : (@render.RendererSurfaceMetrics) -> Canvas2DRenderer,
) -> @render.RendererInstance {
  let renderer = create_canvas2d(metrics)
  @render.new_provider_instance(
    render_frame=frame => renderer.render_frame(frame),
    recover=_reason => @render.RecoveryResult::RecoverySucceeded,
    dispose=() => renderer.dispose(),
  )
}
