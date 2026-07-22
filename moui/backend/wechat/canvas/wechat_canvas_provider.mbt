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
  let renderer = @canvas2d.canvas2d_create_renderer(canvas_id~, metrics=renderer_metrics)
  { canvas_id, renderer, }
}

///|
pub fn WechatCanvasRendererProvider::create_host_renderer(
  self : WechatCanvasRendererProvider,
) -> @host.HostWindowRenderer {
  let renderer = self.renderer
  @host.HostWindowRenderer::new(
    resize=fn(metrics : @host.HostSurfaceMetrics) {
      renderer.resize(
        @render.RendererSurfaceMetrics::new(
          logical_size=metrics.logical_size,
          physical_size=metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      )
    },
    render=fn(commands : Array[@core.DrawCommand]) {
      renderer.render(commands)
    },
    render_frame=Some(fn(frame : @core.DrawFrame) -> @render.RenderFrameResult {
      renderer.render_frame(frame)
    }),
    text_system=fn() -> @core.TextSystem {
      renderer.text_system()
    },
    dispose=fn() {
      renderer.dispose()
    },
    image=@host.HostRendererImageCapability::new(
      image_resources=fn() -> Array[@render.ImageResourceRecord] {
        renderer.image_resources()
      },
      image_resource_snapshot=Some(fn() -> @render.ImageResourceSnapshot {
        renderer.image_resource_snapshot()
      }),
    ),
    platform_view=@host.HostRendererPlatformViewCapability::new(),
    gpu_recovery=@host.HostRendererGpuRecoveryCapability::new(),
  )
}

///|
/// Create a HostWindowRenderer for the WeChat Mini Program Canvas.
/// This is the entry point called from the window-hosted app.
pub fn wechat_canvas_create_renderer(
  canvas_id~ : String,
  metrics~ : @host.HostSurfaceMetrics,
) -> @host.HostWindowRenderer {
  let provider = WechatCanvasRendererProvider::new(canvas_id~, metrics~)
  provider.create_host_renderer()
}