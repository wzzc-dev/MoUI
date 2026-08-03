///|
/// Canvas2D renderer factory for hosts that expose a canvas identity through
/// `HostSurfaceKit.surface_id`.
pub fn canvas() -> @render.RendererBindingFactory {
  @render.RendererBindingFactory::new(id="canvas2d", bind=kit => {
    let canvas_id = kit.surface_id()
    let create = (metrics : @render.RendererSurfaceMetrics) => {
      canvas2d_create_renderer(canvas_id~, metrics~)
    }
    @render.RendererBindingPlan::new(
      binding=@render.RendererProviderBinding::new(
        provider=create_canvas2d_provider(create_canvas2d=create),
        create_host_renderer=(metrics, _bound) => {
          create(metrics).to_host_window_renderer()
        },
      ),
    )
  })
}

///|
pub fn Canvas2DRenderer::to_host_window_renderer(
  self : Canvas2DRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => self.resize(metrics),
    render=commands => self.render(commands),
    render_frame=Some(frame => self.render_frame(frame)),
    text_system=() => self.text_system(),
    dispose=() => self.dispose(),
    image=@render.HostRendererImageCapability::new(
      image_resources=() => self.image_resources(),
      image_resource_snapshot=Some(() => self.image_resource_snapshot()),
    ),
  )
}
