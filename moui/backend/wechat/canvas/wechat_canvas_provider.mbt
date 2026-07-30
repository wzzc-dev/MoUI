///|
/// WeChat Canvas 2D renderer provider.
/// Creates HostWindowRenderer instances backed by the Canvas 2D renderer.

///|
pub(all) struct WechatCanvasRendererProvider {
  canvas_id : String
  renderer : @canvas2d.Canvas2DRenderer
}

///|
pub fn WechatCanvasRendererProvider::new(
  canvas_id~ : String,
  metrics~ : @host.HostSurfaceMetrics,
) -> WechatCanvasRendererProvider {
  let renderer_metrics = @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
  let renderer = @canvas2d.canvas2d_create_renderer(
    canvas_id~,
    metrics=renderer_metrics,
  )
  { canvas_id, renderer }
}

///|
pub fn WechatCanvasRendererProvider::create_host_renderer(
  self : WechatCanvasRendererProvider,
) -> @render.HostWindowRenderer {
  let renderer = self.renderer
  @render.HostWindowRenderer::new(
    resize=fn(metrics : @render.RendererSurfaceMetrics) {
      renderer.resize(
        @render.RendererSurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      )
    },
    render=fn(commands : Array[@core.DrawCommand]) { renderer.render(commands) },
    render_frame=Some(fn(frame : @core.DrawFrame) -> @render.RenderFrameResult {
      renderer.render_frame(frame)
    }),
    text_system=fn() -> @core.TextSystem { renderer.text_system() },
    dispose=fn() { renderer.dispose() },
    image=@render.HostRendererImageCapability::new(
      image_resources=fn() -> Array[@render.ImageResourceRecord] {
        renderer.image_resources()
      },
      image_resource_snapshot=Some(fn() -> @render.ImageResourceSnapshot {
        renderer.image_resource_snapshot()
      }),
    ),
    platform_view=@render.HostRendererPlatformViewCapability::new(),
    gpu_recovery=@render.HostRendererGpuRecoveryCapability::new(),
  )
}

///|
/// Create a HostWindowRenderer for the WeChat Mini Program Canvas.
/// This is the entry point called from the window-hosted app.
pub fn wechat_canvas_create_renderer(
  canvas_id~ : String,
  metrics~ : @host.HostSurfaceMetrics,
) -> @render.HostWindowRenderer {
  let bindings = [wechat_canvas_renderer_binding(canvas_id~)]
  let surface = @render.SurfaceDescriptor::cpu_raster(
    width=metrics.logical_size.width,
    height=metrics.logical_size.height,
    scale_factor=metrics.scale_factor,
  )
  match @render.select_renderer_provider_binding(bindings, surface) {
    Some((binding, bound)) =>
      (binding.create_host_renderer)(
        @render.RendererSurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
        bound,
      )
    None => abort("WeChat Canvas2D binding rejected its canvas surface")
  }
}

///|
/// WeChat's direct Canvas callback route is not a window-hosted event route,
/// but renderer composition still follows the same binding negotiation as
/// desktop and embedded hosts.
pub fn wechat_canvas_renderer_binding(
  canvas_id~ : String,
) -> @render.RendererProviderBinding {
  let provider = @canvas2d.create_canvas2d_provider(create_canvas2d=metrics => {
    @canvas2d.canvas2d_create_renderer(canvas_id~, metrics~)
  })
  @render.RendererProviderBinding::new(provider~, create_host_renderer=(
    metrics,
    _bound,
  ) => {
    let host_metrics = @host.HostSurfaceMetrics::new(
      logical_size=metrics.logical_size,
      physical_size=metrics.physical_size,
      scale_factor=metrics.scale_factor,
    )
    WechatCanvasRendererProvider::new(canvas_id~, metrics=host_metrics).create_host_renderer()
  })
}
