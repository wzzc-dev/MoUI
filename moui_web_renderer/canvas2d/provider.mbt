///|
/// Build a Canvas 2D provider around a surface-aware session factory.
pub fn create_canvas2d_provider(
  bind~ : (@render.HostSurface) -> @render.RendererBindResult,
) -> @render.RendererProvider {
  let caps = canvas2d_provider_capabilities(
    provider_id="wxCanvas2d",
    backend=Canvas2DWasm,
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
      RoundedRect | Gradient | TextShaping | EmojiText =>
        @render.RendererFeatureStatus::Partial
      Image
      | AsyncImage
      | LayerCompositing
      | BlendMode
      | FilterEffect
      | ShaderEffect => Gap
      _ => Supported
    }
    (status, "WeChat Canvas2D provider declares \{feature.label()} support.")
  })
}
