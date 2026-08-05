///|
/// Browser WebGPU factory. The canvas id is supplied by the Web host through
/// `SurfaceContext.surface_id` after each browser window is created.
pub fn webgpu() -> @render.RendererFactory {
  browser_factory(canvas_fallback=false)
}

///|
pub fn canvas2d_fallback() -> @render.RendererFactory {
  browser_factory(canvas_fallback=true)
}

///|
pub fn from_env() -> Array[@render.RendererFactory] {
  [webgpu(), canvas2d_fallback()]
}

///|
fn browser_factory(canvas_fallback~ : Bool) -> @render.RendererFactory {
  @render.RendererFactory::new(
    id=if canvas_fallback { "canvas2d" } else { "webgpu-wasm" },
    bind=kit => {
      @render.RendererBindingPlan::new(
        binding=browser_binding(kit.surface_id(), canvas_fallback),
      )
    },
  )
}

///|
/// Renderer-owned provider bindings used by application diagnostics.
pub fn provider_bindings(
  canvas_id~ : String,
) -> Array[@render.RendererProviderBinding] {
  [browser_binding(canvas_id, false), browser_binding(canvas_id, true)]
}

///|
fn browser_binding(
  canvas_id : String,
  canvas_fallback : Bool,
) -> @render.RendererProviderBinding {
  let create = (metrics : @core.SurfaceMetrics) => {
    try! create_webgpu_renderer(
      canvas_id~,
      logical_size=metrics.logical_size,
      scale_factor=metrics.scale_factor,
    )
  }
  let provider = if canvas_fallback {
    create_browser_canvas2d_fallback_provider(create_canvas2d=create)
  } else {
    create_webgpu_provider(create_webgpu=create)
  }
  @render.RendererProviderBinding::new(provider~, create_host_renderer=(
    metrics,
    _bound,
  ) => create(metrics).to_host_window_renderer())
}

///|
pub fn WebGpuWasmRenderer::to_host_window_renderer(
  self : WebGpuWasmRenderer,
) -> @render.WindowRenderer {
  @render.WindowRenderer::new(
    resize=metrics => self.resize(metrics) catch { _ => () },
    render=commands => self.render(commands) catch { _ => () },
    render_frame=Some(frame => self.render_frame(frame)),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    dispose=() => self.dispose(),
    image=@render.HostRendererImageCapability::new(
      image_resources=() => self.image_resources(),
      image_resource_snapshot=Some(() => self.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        self.apply_image_resource_load_completion(completion)
      }),
    ),
  )
}
