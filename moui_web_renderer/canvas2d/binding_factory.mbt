///|
/// Canvas2D renderer provider for hosts that expose a canvas identity.
pub fn canvas() -> @render.RendererProvider {
  create_canvas2d_provider(bind=surface => {
    match @render_common.host_surface_metrics_error(surface) {
      Some(message) => return @render.RendererBindResult::Rejected(message)
      None => ()
    }
    let canvas_id = surface.surface_id()
    if canvas_id.is_empty() {
      return @render.RendererBindResult::Rejected(
        "canvas2d requires a host surface id",
      )
    }
    let renderer = canvas2d_create_renderer(
      canvas_id~,
      metrics=surface.metrics(),
    )
    @render.RendererBindResult::Bound(renderer.to_renderer_session())
  })
}

///|
pub fn Canvas2DRenderer::to_renderer_session(
  self : Canvas2DRenderer,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => self.resize(metrics),
    render_frame=submission => self.render_frame(submission.frame()),
    text_system=() => self.text_system(),
    recover=_reason => @render.RecoveryResult::RecoverySucceeded,
    dispose=() => self.dispose(),
    image_records=() => self.image_resources(),
  )
}
