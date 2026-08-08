///|
/// Browser WebGPU provider. The canvas id is supplied by the opaque host
/// surface after each browser window is created.
pub fn webgpu() -> @render.RendererProvider {
  browser_provider(canvas_fallback=false)
}

///|
pub fn canvas2d_fallback() -> @render.RendererProvider {
  browser_provider(canvas_fallback=true)
}

///|
pub fn from_env() -> Array[@render.RendererProvider] {
  [webgpu(), canvas2d_fallback()]
}

///|
fn browser_provider(canvas_fallback~ : Bool) -> @render.RendererProvider {
  let bind = (surface : @render.HostSurface) => {
    match @render_common.host_surface_metrics_error(surface) {
      Some(message) => return @render.RendererBindResult::Rejected(message)
      None => ()
    }
    let canvas_id = surface.surface_id()
    if canvas_id.is_empty() {
      return @render.RendererBindResult::Rejected(
        "browser renderer requires a canvas id",
      )
    }
    let renderer = create_webgpu_renderer(
      canvas_id~,
      logical_size=surface.metrics().logical_size,
      scale_factor=surface.metrics().scale_factor,
    ) catch {
      _err =>
        return @render.RendererBindResult::Rejected(
          "browser renderer unavailable",
        )
    }
    @render.RendererBindResult::Bound(renderer.to_renderer_session())
  }
  if canvas_fallback {
    create_browser_canvas2d_fallback_provider(bind~)
  } else {
    create_webgpu_provider(bind~)
  }
}

///|
/// Renderer-owned providers used by application diagnostics.
pub fn providers() -> Array[@render.RendererProvider] {
  from_env()
}

///|
pub fn WebGpuWasmRenderer::to_renderer_session(
  self : WebGpuWasmRenderer,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => self.resize(metrics) catch { _ => () },
    render_frame=submission => self.render_frame(submission.frame()),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    recover=_reason => @render.RecoveryResult::RecoverySucceeded,
    dispose=() => self.dispose(),
    image_records=() => self.image_resources(),
    apply_image_load_completion=completion => {
      self.apply_image_resource_load_completion(completion)
    },
  )
}
