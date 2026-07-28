///|
/// A renderer owner that keeps the raster factory and GPU queue model under one
/// lifecycle. `Recorded` queue completions are internal handoff signals; only
/// the window-backed presenter can produce a public `Presented` completion.
pub struct SkiaHybridRenderer {
  priv renderer : SkiaRasterRenderer
  priv worker : @render.GpuRenderWorker
  priv surface_route : @render.SkiaSurfaceRoute
  priv requested : @render.NativeRendererMode
  priv mut fallback_to_raster : Bool
  priv pending_completions : Array[@render.RenderPresentCompletion]
}

///|
pub fn create_hybrid_renderer(
  platform : @render.NativeGpuPlatform,
  requested : @render.NativeRendererMode,
  metrics : @render.RendererSurfaceMetrics,
  target : SkiaPresentTarget,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
  gpu_target? : HostGpuPresentTarget? = None,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
  async_image_loading? : Bool = false,
) -> SkiaHybridRenderer raise SkiaRendererError {
  let surface_route = @render.resolve_surface_route(
    platform,
    requested,
    gpu_available~,
    gpu_promoted~,
  )
  let gpu_target = if surface_route.is_gpu() {
    gpu_target
  } else {
    None
  }
  let renderer = create_with_present_target_and_route(
    metrics,
    target,
    surface_route~,
    gpu_target~,
    font_resolution~,
    async_image_loading~,
  )
  {
    renderer,
    worker: @render.GpuRenderWorker::new(),
    surface_route,
    requested,
    fallback_to_raster: false,
    pending_completions: [],
  }
}

///|
pub fn SkiaHybridRenderer::surface_route(
  self : SkiaHybridRenderer,
) -> @render.SkiaSurfaceRoute {
  self.surface_route
}

///|
pub fn SkiaHybridRenderer::requested_mode(
  self : SkiaHybridRenderer,
) -> @render.NativeRendererMode {
  self.requested
}

///|
pub fn SkiaHybridRenderer::render_frame(
  self : SkiaHybridRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  if self.fallback_to_raster || !(self.surface_route.is_gpu()) {
    return self.renderer.render_frame(frame)
  }
  let input = @render.RenderFrameInput::new(
    metrics=self.renderer.metrics(),
    commands=frame.commands,
    damage=frame.damage,
    clear_color=Some(frame.clear_color),
    cache_epoch=frame.cache_epoch,
  )
  let result = self.worker.submit(input)
  self.worker.poll()
  let completions = self.worker.drain_present_completions()
  if completions.any(c => {
      c.status() is @render.RenderPresentStatus::FallbackToRaster
    }) {
    self.fallback_to_raster = true
    self.pending_completions.append(
      completions.filter(c => {
        c.status() is @render.RenderPresentStatus::FallbackToRaster
      }),
    )
    return @render.RenderFrameResult::new(presented=false, queued=false)
  }
  let mut recorded_completion : @render.RenderPresentCompletion? = None
  for completion in completions {
    if completion.status() is @render.RenderPresentStatus::Recorded {
      recorded_completion = Some(completion)
      break
    }
  }
  match recorded_completion {
    Some(recorded) => {
      let presented = self.renderer.render_frame(frame)
      if presented.presented {
        self.pending_completions.push(
          @render.RenderPresentCompletion::new(
            frame_sequence=recorded.frame_sequence(),
            surface_generation=recorded.surface_generation(),
            image_resource_revision=recorded.image_resource_revision(),
            submitted_at_ms=recorded.submitted_at_ms(),
            completed_at_ms=recorded.completed_at_ms(),
            presented_at_ms=recorded.completed_at_ms(),
            status=@render.RenderPresentStatus::Presented,
            gpu_context_generation=recorded.gpu_context_generation(),
          ),
        )
      }
      presented
    }
    None => result
  }
}

///|
pub fn SkiaHybridRenderer::drain_present_completions(
  self : SkiaHybridRenderer,
) -> Array[@render.RenderPresentCompletion] {
  let completions = self.pending_completions.copy()
  self.pending_completions.clear()
  completions
}

///|
pub fn SkiaHybridRenderer::fallback_to_raster(
  self : SkiaHybridRenderer,
) -> Bool {
  self.fallback_to_raster
}

///|
pub fn SkiaRasterRenderer::metrics(
  self : SkiaRasterRenderer,
) -> @render.RendererSurfaceMetrics {
  self.metrics
}
