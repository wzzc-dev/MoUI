///|
/// Build a Canvas 2D provider around a surface-aware session factory.
pub fn create_canvas2d_provider(
  bind~ : (@render.HostSurface) -> @render.RendererBindResult,
) -> @render.RendererProvider {
  let caps = canvas2d_provider_capabilities(
    provider_id="wxCanvas2d",
    backend=@render.RendererBackendKind::Canvas2DWasm,
  )
  @render.RendererProvider::new(
    id="wxCanvas2d",
    descriptor=canvas2d_descriptor(),
    capabilities=() => caps,
    bind~,
  )
}

///|
pub fn canvas2d_provider_capabilities(
  provider_id~ : String,
  backend~ : @render.RendererBackendKind,
) -> Array[@render.RendererBackendFeatureCapability] {
  @render_common.renderer_provider_capabilities(provider_id~, backend~, capability_for=feature => {
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
