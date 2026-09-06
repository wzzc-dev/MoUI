/// Throwaway test renderer (ADR 0007 E7): the smallest possible renderer
/// "module" — one package exporting a `RendererProvider`. Hanging it onto a
/// composition root is one registration line (`AppBuilder::render`) and
/// requires zero changes to core, host, runtime, or the existing renderers.
/// The descriptor reuses the `SkiaRasterNative` backend kind because adding
/// a new enum variant would be a core change; a real new renderer adds its
/// kind through the core RFC process instead.

///|
priv struct ThrowawayState {
  mut binds : Int
}

///|
let throwaway_state : ThrowawayState = { binds: 0 }

///|
pub fn throwaway_bind_count() -> Int {
  throwaway_state.binds
}

///|
pub fn throwaway_session() -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    present_count=() => throwaway_state.binds,
  )
}

///|
pub fn throwaway_provider() -> @render.RendererProvider {
  @render.RendererProvider::new(
    id="throwaway",
    descriptor=@render.RendererDescriptor::new(
      backend=@render.RendererBackendKind::SkiaRasterNative,
      family=@render.RendererFamily::Skia,
      presentation=@render.RendererPresentationModel::CpuPixelFrame,
      supported_targets=[@render.RendererTarget::Native],
      capabilities=[],
      description="throwaway open-extension renderer",
    ),
    capabilities=() => [],
    bind=_surface => {
      throwaway_state.binds = throwaway_state.binds + 1
      @render.RendererBindResult::Bound(throwaway_session())
    },
  )
}
