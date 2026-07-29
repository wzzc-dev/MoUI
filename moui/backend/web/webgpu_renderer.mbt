///|
pub type WebRendererError = @webgpu.WebGpuHostError

///|
pub(all) struct WebRenderer {
  host_renderer : @render.HostWindowRenderer
}

///|
pub fn webgpu_renderer_backend_info() -> @render.RendererBackendInfo {
  @webgpu.backend_info()
}

///|
pub fn webgpu_canvas_surface_contract() -> @render.WgpuSurfaceContract {
  @webgpu.canvas_surface_contract()
}

///|
/// Create through the provider bindings. Browser runtime setup owns WebGPU
/// availability and lazily installs Canvas2D imports when necessary; this
/// composition root declares their preference order only.
pub fn WebRenderer::create(
  canvas_id~ : String,
  metrics~ : @host.HostSurfaceMetrics,
) -> WebRenderer raise WebRendererError {
  let renderer_metrics = @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
  let surface = @render.SurfaceDescriptor::cpu_raster(
    width=metrics.logical_size.width,
    height=metrics.logical_size.height,
    scale_factor=metrics.scale_factor,
  )
  match
    @render.select_renderer_provider_binding(
      web_renderer_provider_bindings(canvas_id~),
      surface,
    ) {
    Some((binding, bound_surface)) =>
      {
        host_renderer: (binding.create_host_renderer)(
          renderer_metrics, bound_surface,
        ),
      }
    None => raise @webgpu.WebGpuHostError::SurfaceUnavailable
  }
}

///|
/// WebGPU is registered before Canvas2D. Browser host initialization owns the
/// asynchronous availability check: it creates the Canvas2D fallback behind
/// the same WebGPU-compatible wasm import port before renderer construction.
/// This keeps Web free of the WeChat-specific `canvas2d` host-import module.
pub fn web_renderer_provider_bindings(
  canvas_id~ : String,
) -> Array[@render.RendererProviderBinding] {
  let create_browser_renderer = (
    renderer_metrics : @render.RendererSurfaceMetrics,
  ) => {
    try! @webgpu.create_webgpu_renderer(
      canvas_id~,
      logical_size=renderer_metrics.logical_size,
      scale_factor=renderer_metrics.scale_factor,
    )
  }
  let webgpu_binding = @render.RendererProviderBinding::new(
    provider=@webgpu.create_webgpu_provider(
      create_webgpu=create_browser_renderer,
    ),
    create_host_renderer=(renderer_metrics, _bound_surface) => {
      host_renderer_from_webgpu(create_browser_renderer(renderer_metrics))
    },
  )
  let canvas_binding = @render.RendererProviderBinding::new(
    provider=@webgpu.create_browser_canvas2d_fallback_provider(
      create_canvas2d=create_browser_renderer,
    ),
    create_host_renderer=(renderer_metrics, _bound_surface) => {
      host_renderer_from_webgpu(create_browser_renderer(renderer_metrics))
    },
  )
  [webgpu_binding, canvas_binding]
}

///|
pub fn WebRenderer::from_webgpu_renderer(
  renderer : @webgpu.WebGpuWasmRenderer,
) -> WebRenderer {
  { host_renderer: host_renderer_from_webgpu(renderer) }
}

///|
pub fn WebRenderer::resize(
  self : WebRenderer,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  self.host_renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=metrics.logical_size,
      physical_size=metrics.physical_size,
      scale_factor=metrics.scale_factor,
    ),
  )
}

///|
pub fn WebRenderer::render(
  self : WebRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  self.host_renderer.render(commands)
}

///|
pub fn WebRenderer::render_frame(
  self : WebRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  self.host_renderer.render_frame(frame)
}

///|
pub fn WebRenderer::text_system(self : WebRenderer) -> @core.TextSystem {
  self.host_renderer.text_system()
}

///|
pub fn WebRenderer::image_resources(
  self : WebRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.host_renderer.image_resources()
}

///|
pub fn WebRenderer::image_resource_snapshot(
  self : WebRenderer,
) -> @render.ImageResourceSnapshot {
  self.host_renderer.image_resource_snapshot()
}

///|
pub fn WebRenderer::apply_image_resource_load_completion(
  self : WebRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  self.host_renderer.apply_image_resource_load_completion(completion)
}

///|
pub fn WebRenderer::dispose(self : WebRenderer) -> Unit {
  self.host_renderer.dispose()
}

///|
fn host_renderer_from_webgpu(
  renderer : @webgpu.WebGpuWasmRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => renderer.resize(metrics) catch { _ => () },
    render=commands => renderer.render(commands) catch { _ => () },
    render_frame=Some(frame => renderer.render_frame(frame)),
    text_system=() => renderer.text_system(),
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
    image=@render.HostRendererImageCapability::new(
      image_resources=() => renderer.image_resources(),
      image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        renderer.apply_image_resource_load_completion(completion)
      }),
    ),
  )
}

///|
