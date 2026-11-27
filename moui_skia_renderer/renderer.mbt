///|
#derive(Eq, Debug, ToJson)
pub(all) suberror SkiaRendererError {
  SkiaUnavailable
  SurfaceUnavailable
  CanvasUnavailable
  ReadPixelsUnavailable
  GpuContextUnavailable(String)
  PresentFailed(String)
}

///|
pub extend SkiaRendererError with Debug::{to_repr}

///|
pub extend SkiaRendererError with Eq::{not_equal, equal}

///|
pub extend SkiaRendererError with ToJson::{to_json}

///|
pub fn SkiaRendererError::message(self : SkiaRendererError) -> String {
  match self {
    SkiaUnavailable => "moui_skia/native is unavailable"
    SurfaceUnavailable => "failed to create Skia surface"
    CanvasUnavailable => "failed to acquire Skia canvas"
    ReadPixelsUnavailable => "failed to read Skia surface pixels"
    GpuContextUnavailable(description) =>
      "failed to create Skia GPU context: \{description}"
    PresentFailed(description) => "Skia presenter failed: \{description}"
  }
}

///|
#derive(Eq, Debug, ToJson)
pub struct SkiaUnsupportedCommandDiagnostic {
  priv command : String
  priv reason : String
}

///|
pub fn SkiaUnsupportedCommandDiagnostic::command(
  self : SkiaUnsupportedCommandDiagnostic,
) -> String {
  self.command
}

///|
pub fn SkiaUnsupportedCommandDiagnostic::reason(
  self : SkiaUnsupportedCommandDiagnostic,
) -> String {
  self.reason
}

///|
pub extend SkiaUnsupportedCommandDiagnostic with Debug::{to_repr}

///|
pub extend SkiaUnsupportedCommandDiagnostic with Eq::{not_equal, equal}

///|
pub extend SkiaUnsupportedCommandDiagnostic with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) enum SkiaFontResolution {
  SystemFontMgr
  EmptyTypeface
}

///|
pub extend SkiaFontResolution with Debug::{to_repr}

///|
pub extend SkiaFontResolution with Eq::{not_equal, equal}

///|
pub extend SkiaFontResolution with ToJson::{to_json}

///|
pub struct SkiaRasterRenderer {
  priv mut metrics : @core.SurfaceMetrics
  priv target : SkiaPresentTarget
  priv gpu_target : HostGpuPresentTarget?
  priv font_resolution : SkiaFontResolution
  priv surface_route : SkiaSurfaceRoute
  priv gpu_context : @skia_native.GpuContext?
  priv mut surface : @skia_native.Surface
  priv mut gpu_surface_attached : Bool
  // Metal window drawables rotate every frame and do not preserve pixels.
  // Render into a context-owned offscreen surface and copy its complete
  // pixels into each fresh drawable.
  priv mut gpu_backing : @skia_native.Surface?
  // Pixels in `surface` (CPU raster) and `gpu_backing` are valid only after a
  // completed full draw. New/resize/incomplete-frame/recovery transitions
  // clear these flags so the next frame initializes the whole surface instead
  // of trusting retained pixels.
  priv mut surface_initialized : Bool
  priv mut gpu_backing_initialized : Bool
  priv mut last_damage_report : SkiaDamageReport?
  priv image_cache : Map[String, @skia_native.Image]
  priv failed_images : Map[String, String]
  priv image_lifecycle : @render_common.ImageResourceLifecycle
  // Renderer-owned image pixels can change without a runtime tree/content
  // revision change (async decode completion). Load completions invalidate
  // exactly the cached layers whose recorded command stream drew that image
  // source (renderer_cached_layer.mbt), so placeholder pixels are never
  // replayed after an image is ready and chrome layers survive.
  priv async_image_loading : Bool
  priv mut present_count : Int32
  priv mut unsupported_command_count : Int32
  priv unsupported_command_diagnostics : Array[SkiaUnsupportedCommandDiagnostic]
  priv mut last_frame : SkiaPixelFrame?
  priv layer_cache : Map[SkiaLayerCacheKey, SkiaCachedLayerImageEntry]
  priv layer_cache_identity_index : Map[SkiaLayerIdentity, SkiaLayerCacheKey]
  priv picture_layer_cache : Map[SkiaLayerCacheKey, SkiaCachedLayerPictureEntry]
  priv picture_layer_cache_identity_index : Map[
    SkiaLayerIdentity,
    SkiaLayerCacheKey,
  ]
  priv layer_cache_admissions : Map[
    SkiaLayerIdentity,
    SkiaCachedLayerAdmissionRecord,
  ]
  priv mut layer_cache_total_bytes : Int64
  priv mut picture_layer_cache_total_bytes : Int64
  priv mut layer_cache_tick : Int32
  priv mut platform_view_draw_fn : (() -> Unit)?
  priv mut platform_view_recording_canvas : @skia_native.Canvas?
  priv text_shaping_cache : SkiaTextShapingCache
  priv text_paragraph_cache : @render_common.TextParagraphCache
  // Per-frame parameter objects reused across frames: the frame stats record
  // and the canvas scope stack are reset (never reallocated) at frame start
  // by draw_frame_to_canvas. The paint memo caches immutable paints by
  // (color, style, width) within this renderer session.
  priv frame_stats : SkiaCachedLayerFrameStats
  priv frame_canvas_scopes : Array[@render_common.PlanScopeKind]
  priv paint_memo : Array[SkiaPaintMemoEntry]
  priv surface_damage : @render.SurfaceDamageCapability
}

///|
pub fn skia_available() -> Bool {
  @skia_native.skia_available()
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  let available = skia_available()
  let surface_preflight = raster_surface_preflight(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
  )
  let text_preflight = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=12.0, weight=400),
    "MoUI",
  )
  let text_maturity = skia_text_maturity_preflight()
  @render.RendererBackendInfo::new(
    backend=SkiaRasterNative,
    status=if available { Supported } else { Unavailable },
    can_render=available,
    can_resize=available,
    owns_surface=true,
    description="Native Skia raster renderer using moui_skia/native CPU surfaces, " +
      surface_preflight.summary() +
      ", " +
      skia_gpu_metal_preflight_summary() +
      ", " +
      text_preflight.summary() +
      ", " +
      text_maturity.summary() +
      ", flush-and-submit finalization, and platform pixel presenters.",
  )
}

///|
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  skia_raster_native_descriptor()
}

///|
pub fn skia_raster_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=SkiaRasterNative,
    family=Skia,
    presentation=CpuPixelFrame,
    supported_targets=[Native],
    capabilities=skia_provider_capabilities(
      provider_id="skia-raster",
      backend=SkiaRasterNative,
    ),
    description="Native Skia raster renderer that presents copied RGBA premultiplied pixel frames to the host.",
  )
}

///|
pub fn skia_gpu_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=SkiaGpuNative,
    family=Skia,
    presentation=HostGpuSurface,
    supported_targets=[Native],
    capabilities=skia_provider_capabilities(
      provider_id="skia-hybrid",
      backend=SkiaGpuNative,
    ),
    description="Native Skia GPU renderer identity for direct host GPU surfaces. Providers must prove a matching Metal, Vulkan, EGL/GLES, or Direct3D surface before selecting it; resolve_surface_route picks the platform-appropriate SurfaceRoute (metal/vulkan/egl/direct3d) and the matching HostGpuPresentTarget wiring. Auto prefers SkiaGpuNative when the host exposes a usable GPU surface; SkiaRasterNative remains the explicit mode and sticky recovery fallback.",
  )
}

///|
pub fn create_with_present_target(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  font_resolution~ : SkiaFontResolution = SystemFontMgr,
  async_image_loading~ : Bool = false,
  surface_damage~ : @render.SurfaceDamageCapability = FullSurfaceOnly,
) -> SkiaRasterRenderer raise SkiaRendererError {
  create_with_present_target_and_route(
    metrics,
    target,
    surface_route=RasterSurfaceRoute,
    font_resolution~,
    async_image_loading~,
    surface_damage~,
  )
}

///|
pub fn create_with_present_target_and_route(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  surface_route~ : SkiaSurfaceRoute = RasterSurfaceRoute,
  gpu_target~ : HostGpuPresentTarget? = None,
  font_resolution~ : SkiaFontResolution = SystemFontMgr,
  async_image_loading~ : Bool = false,
  surface_damage~ : @render.SurfaceDamageCapability = FullSurfaceOnly,
) -> SkiaRasterRenderer raise SkiaRendererError {
  if !skia_available() {
    raise SkiaUnavailable
  }
  // The direct GPU present path requires a GPU surface route; pairing a
  // HostGpuPresentTarget with a RasterSurfaceRoute would silently present
  // a raster surface through a GPU presenter, which is a configuration error.
  if gpu_target is Some(_) && !surface_route.is_gpu() {
    raise GpuContextUnavailable("gpu-target-requires-gpu-surface-route")
  }
  let gpu_context = create_gpu_context(surface_route)
  // Window systems such as AppKit cannot supply a drawable until control has
  // returned to the event loop. Keep an offscreen GPU surface only as a typed
  // placeholder; the first render replaces it before recording any commands.
  let surface = create_surface(metrics, surface_route, gpu_context)
  // SubRect is honest only for a retained surface: the CPU raster surface or
  // the Metal persistent backing. A direct GPU drawable without a backing has
  // no preserved pixels, so an explicit SubRect request is normalized to
  // FullSurfaceOnly rather than promising a capability the path cannot honour.
  let surface_damage = match surface_damage {
    SubRect =>
      if gpu_target is Some(_) && !(surface_route is MetalGpuSurfaceRoute) {
        @render.FullSurfaceOnly
      } else {
        @render.SubRect
      }
    FullSurfaceOnly => @render.FullSurfaceOnly
  }
  {
    metrics,
    target,
    gpu_target,
    font_resolution,
    surface_route,
    gpu_context,
    surface,
    gpu_surface_attached: gpu_target is None,
    gpu_backing: None,
    surface_initialized: false,
    gpu_backing_initialized: false,
    last_damage_report: None,
    image_cache: Map([]),
    failed_images: Map([]),
    image_lifecycle: @render_common.ImageResourceLifecycle::new(),
    async_image_loading,
    present_count: 0,
    unsupported_command_count: 0,
    unsupported_command_diagnostics: [],
    last_frame: None,
    layer_cache: Map([]),
    layer_cache_identity_index: Map([]),
    picture_layer_cache: Map([]),
    picture_layer_cache_identity_index: Map([]),
    layer_cache_admissions: Map([]),
    layer_cache_total_bytes: 0L,
    picture_layer_cache_total_bytes: 0L,
    layer_cache_tick: 0,
    platform_view_draw_fn: None,
    platform_view_recording_canvas: None,
    text_shaping_cache: SkiaTextShapingCache::new(),
    text_paragraph_cache: @render_common.TextParagraphCache::new(),
    frame_stats: SkiaCachedLayerFrameStats::new(),
    frame_canvas_scopes: [],
    paint_memo: [],
    surface_damage,
  }
}

///|
pub fn SkiaRasterRenderer::render(
  self : SkiaRasterRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise SkiaRendererError {
  self.ensure_gpu_window_surface()
  // The legacy command-only path always draws a full surface. A persistent
  // backing from an earlier render_frame must not survive it, or the next
  // partial frame would copy stale backing pixels over this frame's output.
  self.invalidate_gpu_backing_surface()
  match self.surface.canvas() {
    Some(canvas) => {
      canvas.clear(skia_color(@render.first_clear_color(commands)))
      let saved = canvas.save()
      canvas.scale(
        @moui_skia.Size::new(
          Float::from_double(self.metrics.scale_factor),
          Float::from_double(self.metrics.scale_factor),
        ),
      )
      self.unsupported_command_count = 0
      self.unsupported_command_diagnostics.clear()
      let canvas_scopes : Array[@render_common.PlanScopeKind] = []
      // Renderers interpret `@core.DrawCommand` directly (ADR 0019 lowering
      // retired): scope balance is validated in this same traversal via the
      // canvas scope stack and the unclosed-scope report below.
      for command in commands {
        self.render_command(canvas, command, canvas_scopes)
      }
      if !canvas_scopes.is_empty() {
        for scope in canvas_scopes {
          self.record_unsupported_command(
            @render_common.plan_scope_push_command(scope),
            "command stream ended with an open \{@render_common.plan_scope_name(scope)} scope",
          )
        }
      }
      canvas.restore_to_count(saved)
      if !self.surface.flush_and_submit() {
        raise SurfaceUnavailable
      }
      if self.gpu_target is None {
        // A completed full draw makes the CPU raster surface safe for later
        // partial frames.
        self.surface_initialized = true
      }
      self.last_damage_report = None
      // Dispatch on the present target kind. When a HostGpuPresentTarget is
      // bound, the platform owns the drawable and Skia has already flushed;
      // skip `read_frame` (no CPU readback) and clear `last_frame`. The
      // presenter may return a fresh `Surface` bound to the next drawable
      // (Metal `CAMetalDrawable` pattern); swap it in for the next frame.
      match self.gpu_target {
        Some(gpu_target) => {
          let outcome = (gpu_target.present_gpu)(self.gpu_context, self.surface)
          if outcome.succeeded() {
            self.present_count = self.present_count + 1
            self.last_frame = None
            match outcome.next_surface() {
              Some(next_surface) => self.surface = next_surface
              None => ()
            }
          } else {
            raise PresentFailed(gpu_target.description)
          }
        }
        None => {
          let frame = self.read_frame()
          self.last_frame = Some(frame)
          if (self.target.present)(frame) {
            self.present_count = self.present_count + 1
          } else {
            raise PresentFailed(self.target.description)
          }
        }
      }
    }
    None => raise CanvasUnavailable
  }
}

///|
pub fn SkiaRasterRenderer::render_frame(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  self.render_frame_inner(frame) catch {
    err => {
      self.record_unsupported_command("RenderFrame", err.message())
      @render.RenderFrameResult::new(presented=false)
    }
  }
}

///|
fn SkiaRasterRenderer::invalidate_gpu_backing_surface(
  self : SkiaRasterRenderer,
) -> Unit {
  self.gpu_backing = None
  self.gpu_backing_initialized = false
}

///|
/// Allocate the stable offscreen surface used by the Metal drawable path. A
/// failed allocation leaves the renderer on its existing full-redraw path.
fn SkiaRasterRenderer::ensure_gpu_backing_surface(
  self : SkiaRasterRenderer,
) -> Bool {
  if !(self.surface_route is MetalGpuSurfaceRoute) || self.gpu_target is None {
    return false
  }
  match self.gpu_backing {
    Some(backing) =>
      if backing.descriptor() == self.surface.descriptor() {
        true
      } else {
        self.invalidate_gpu_backing_surface()
        self.ensure_gpu_backing_surface()
      }
    None => {
      let backing = create_surface(
        self.metrics,
        self.surface_route,
        self.gpu_context,
      ) catch {
        _ => return false
      }
      self.gpu_backing = Some(backing)
      true
    }
  }
}

///|
priv struct SkiaGpuBackingFrame {
  stats : SkiaCachedLayerFrameStats
  effective : @core.DamageRegion
  draw_us : Double
  copy_us : Double
}

///|
/// Update the persistent backing and copy its complete pixels into the fresh
/// host drawable. Only the backing receives damage-limited drawing; the
/// drawable is treated as uninitialized, so the copy must cover it entirely.
fn SkiaRasterRenderer::render_to_gpu_backing(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> SkiaGpuBackingFrame? {
  let backing = match self.gpu_backing {
    Some(backing) => backing
    None => return None
  }
  let canvas = match backing.canvas() {
    Some(canvas) => canvas
    None => {
      self.invalidate_gpu_backing_surface()
      return None
    }
  }
  let effective = self.resolve_gpu_backing_damage(frame)
  let previous_recording_canvas = self.platform_view_recording_canvas
  self.platform_view_recording_canvas = Some(canvas)
  let draw_start = @bench.monotonic_clock_start()
  let (stats, complete) = self.draw_frame_to_canvas(
    canvas,
    frame,
    draw_platform_views=true,
    damage=effective,
  )
  let draw_flushed = complete && backing.flush_and_submit()
  let draw_us = @bench.monotonic_clock_end(draw_start)
  self.platform_view_recording_canvas = previous_recording_canvas
  if !draw_flushed {
    self.invalidate_gpu_backing_surface()
    return None
  }
  self.gpu_backing_initialized = true
  let copy_start = @bench.monotonic_clock_start()
  let copied = self.surface.copy_from(backing)
  let copy_us = @bench.monotonic_clock_end(copy_start)
  if !copied {
    self.invalidate_gpu_backing_surface()
    return None
  }
  Some({ stats, effective, draw_us, copy_us, })
}

///|
fn skia_damage_rect_union(rects : Array[@core.Rect]) -> @core.Rect? {
  match rects {
    [] => None
    [first, .. rest] => {
      let mut bounds = first
      for rect in rest {
        bounds = bounds.union(rect)
      }
      Some(bounds)
    }
  }
}

///|
fn SkiaRasterRenderer::apply_damage_clip(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  damage : @core.DamageRegion,
) -> Unit {
  let _ = self
  match damage {
    Rects([rect, ..]) => canvas.clip_rect(skia_rect(rect))
    Empty | FullSurface(_) => ()
    Rects([]) => ()
  }
}

///|
fn SkiaRasterRenderer::apply_damage_clear(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  damage : @core.DamageRegion,
  clear_color : @core.Color,
) -> Unit {
  let _ = self
  match damage {
    FullSurface(_) => canvas.clear(skia_color(clear_color))
    Rects(rects) =>
      // Per-rect clip + clear ensures each dirty region is independently cleared.
      for rect in rects {
        let saved = canvas.save()
        canvas.clip_rect(skia_rect(rect))
        canvas.clear(skia_color(clear_color))
        canvas.restore_to_count(saved)
      }
    Empty => ()
  }
}

///|
fn SkiaRasterRenderer::render_frame_inner(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult raise SkiaRendererError {
  if self.surface_damage is SubRect &&
    self.gpu_target is None &&
    self.surface_initialized &&
    frame.damage is Empty {
    self.last_damage_report = Some(
      SkiaDamageReport::new(
        requested=frame.damage,
        effective=Empty,
        target=RetainedSurface,
        presented=false,
        draw_us=0.0,
        copy_us=0.0,
        present_us=0.0,
      ),
    )
    return @render.RenderFrameResult::new(presented=false)
  }
  self.ensure_gpu_window_surface()
  match self.gpu_target {
    Some(gpu_target) => {
      // Metal drawables rotate every frame. Update the stable backing first;
      // its complete pixels are then copied into the freshly acquired drawable.
      // Platform-view callbacks may acquire one-shot native pixels. Keep those
      // frames on the existing direct full-redraw path so an optimization
      // fallback cannot invoke the callback twice.
      let requested = frame.damage
      let mut report_target = GpuBacking
      let mut report_effective = @core.DamageRegion::empty()
      let mut report_draw_us = 0.0
      let mut report_copy_us = 0.0
      let backing_frame = if self.platform_view_draw_fn is None &&
        self.ensure_gpu_backing_surface() {
        self.render_to_gpu_backing(frame)
      } else {
        None
      }
      let stats = match backing_frame {
        Some(outcome) => {
          report_effective = outcome.effective
          report_draw_us = outcome.draw_us
          // The drawable-side flush is part of the copy/finalize phase; the
          // draw phase covers the backing only.
          let flush_start = @bench.monotonic_clock_start()
          let flushed = self.surface.flush_and_submit()
          let flush_us = @bench.monotonic_clock_end(flush_start)
          report_copy_us = outcome.copy_us + flush_us
          if !flushed {
            self.invalidate_gpu_backing_surface()
            raise SurfaceUnavailable
          }
          outcome.stats
        }
        None => {
          // Allocation/copy failure is an optimization failure only. Preserve
          // the existing conservative full redraw on the host drawable.
          self.invalidate_gpu_backing_surface()
          report_target = GpuDrawable
          let effective = self.resolve_gpu_drawable_damage(frame)
          report_effective = effective
          match self.surface.canvas() {
            Some(canvas) => {
              let draw_start = @bench.monotonic_clock_start()
              let (stats, complete) = self.draw_frame_to_canvas(
                canvas,
                frame,
                draw_platform_views=true,
                damage=effective,
              )
              let flushed = complete && self.surface.flush_and_submit()
              report_draw_us = @bench.monotonic_clock_end(draw_start)
              if !complete {
                self.last_damage_report = Some(
                  SkiaDamageReport::new(
                    requested~,
                    effective~,
                    target=GpuDrawable,
                    presented=false,
                    draw_us=report_draw_us,
                    copy_us=0.0,
                    present_us=0.0,
                  ),
                )
                return self.render_frame_result(stats, presented=false)
              }
              if !flushed {
                raise SurfaceUnavailable
              }
              stats
            }
            None => raise CanvasUnavailable
          }
        }
      }
      let present_start = @bench.monotonic_clock_start()
      let outcome = (gpu_target.present_gpu)(self.gpu_context, self.surface)
      let present_us = @bench.monotonic_clock_end(present_start)
      let completed = outcome.succeeded()
      self.last_damage_report = Some(
        SkiaDamageReport::new(
          requested~,
          effective=report_effective,
          target=report_target,
          presented=completed,
          draw_us=report_draw_us,
          copy_us=report_copy_us,
          present_us~,
        ),
      )
      if completed {
        self.present_count = self.present_count + 1
        self.last_frame = None
        match outcome.next_surface() {
          Some(next_surface) => self.surface = next_surface
          None => ()
        }
        self.render_frame_result(stats, presented=true)
      } else {
        self.invalidate_gpu_backing_surface()
        raise PresentFailed(gpu_target.description)
      }
    }
    None =>
      match self.surface.canvas() {
        Some(canvas) => {
          let requested = frame.damage
          let effective = self.resolve_retained_surface_damage(frame)
          let draw_start = @bench.monotonic_clock_start()
          let (stats, complete) = self.draw_frame_to_canvas(
            canvas,
            frame,
            draw_platform_views=true,
            damage=effective,
          )
          let flushed = complete && self.surface.flush_and_submit()
          let draw_us = @bench.monotonic_clock_end(draw_start)
          if !complete {
            // Retained pixels are no longer trustworthy after an incomplete
            // command stream, so the next frame must fully initialize.
            self.surface_initialized = false
            self.last_damage_report = Some(
              SkiaDamageReport::new(
                requested~,
                effective~,
                target=RetainedSurface,
                presented=false,
                draw_us~,
                copy_us=0.0,
                present_us=0.0,
              ),
            )
            return self.render_frame_result(stats, presented=false)
          }
          if !flushed {
            self.surface_initialized = false
            raise SurfaceUnavailable
          }
          self.surface_initialized = true
          let copy_start = @bench.monotonic_clock_start()
          let skia_frame = self.read_frame()
          let copy_us = @bench.monotonic_clock_end(copy_start)
          self.last_frame = Some(skia_frame)
          let present_start = @bench.monotonic_clock_start()
          let presented = (self.target.present)(skia_frame)
          let present_us = @bench.monotonic_clock_end(present_start)
          self.last_damage_report = Some(
            SkiaDamageReport::new(
              requested~,
              effective~,
              target=RetainedSurface,
              presented~,
              draw_us~,
              copy_us~,
              present_us~,
            ),
          )
          if presented {
            self.present_count = self.present_count + 1
            self.render_frame_result(stats, presented=true)
          } else {
            raise PresentFailed(self.target.description)
          }
        }
        None => raise CanvasUnavailable
      }
  }
}

///|
fn SkiaRasterRenderer::draw_frame_to_canvas(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  frame : @core.DrawFrame,
  draw_platform_views~ : Bool,
  damage~ : @core.DamageRegion,
) -> (SkiaCachedLayerFrameStats, Bool) {
  let effective_damage = damage
  let saved = canvas.save()
  canvas.scale(
    @moui_skia.Size::new(
      Float::from_double(self.metrics.scale_factor),
      Float::from_double(self.metrics.scale_factor),
    ),
  )
  // Damage bounds are logical coordinates. Keep every command, including
  // full-surface backgrounds and explicit compatibility Clears, inside the
  // same damage clip so clip and clear stay coherent. With FullSurfaceOnly
  // this clip is a no-op; the SubRect capability relies on it to preserve
  // every pixel outside the damage union.
  self.apply_damage_clip(canvas, effective_damage)
  self.apply_damage_clear(canvas, effective_damage, frame.clear_color)
  self.unsupported_command_count = 0
  self.unsupported_command_diagnostics.clear()
  // Reused per-frame parameter objects: reset (not reallocated) each frame.
  // The same stats object is handed down through the layer update paths, so
  // the reset at entry is the only bookkeeping needed. A fallback retry within
  // one render_frame (GPU backing unavailable -> direct canvas) resets again,
  // discarding only the aborted attempt's counts, exactly as separate locals
  // did.
  let stats = self.frame_stats
  stats.reset()
  self.text_shaping_cache.begin_frame()
  let canvas_scopes = self.frame_canvas_scopes
  canvas_scopes.clear()
  // The original command stream is rendered in place; scope balance is
  // validated inside the traversal (canvas scope stack + unclosed report).
  let complete = self.render_cached_command_range(
    canvas,
    frame.commands,
    start_index=0,
    end_index=frame.commands.length(),
    canvas_scopes,
    stats,
    damage=effective_damage,
  )
  if !canvas_scopes.is_empty() {
    for scope in canvas_scopes {
      self.record_unsupported_command(
        @render_common.plan_scope_push_command(scope),
        "command stream ended with an open \{@render_common.plan_scope_name(scope)} scope",
      )
    }
  }
  canvas.restore_to_count(saved)
  if draw_platform_views {
    match self.platform_view_draw_fn {
      Some(draw_fn) => draw_fn()
      None => ()
    }
  }
  (stats, complete)
}

///|
/// Record a frame into an immutable picture for replay by a native renderer
/// worker. No MoonBit object crosses the thread boundary.
pub fn SkiaRasterRenderer::record_frame_picture(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @skia_native.Picture? {
  match @skia_native.PictureRecorder::new() {
    None => None
    Some(recorder) => {
      let physical = self.metrics.physical_size
      let width = physical.width.ceil().max(1.0).to_int()
      let height = physical.height.ceil().max(1.0).to_int()
      match recorder.begin(width, height) {
        None => None
        Some(canvas) => {
          let complete = self.draw_frame_to_picture_canvas(canvas, frame)
          if !complete {
            None
          } else {
            match self.platform_view_draw_fn {
              Some(draw_fn) => {
                self.platform_view_recording_canvas = Some(canvas)
                draw_fn()
                self.platform_view_recording_canvas = None
              }
              None => ()
            }
            recorder.finish()
          }
        }
      }
    }
  }
}

///|
pub fn SkiaRasterRenderer::backend_kind(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  SkiaRasterNative
}

///|
pub fn SkiaRasterRenderer::backend_info(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn SkiaRasterRenderer::present_count(self : SkiaRasterRenderer) -> Int32 {
  self.present_count
}

///|
pub fn SkiaRasterRenderer::unsupported_command_count(
  self : SkiaRasterRenderer,
) -> Int32 {
  self.unsupported_command_count
}

///|
pub fn SkiaRasterRenderer::unsupported_command_diagnostics(
  self : SkiaRasterRenderer,
) -> Array[SkiaUnsupportedCommandDiagnostic] {
  self.unsupported_command_diagnostics.copy()
}

///|
/// The damage decision and phase timings of the most recent frame attempt.
/// `None` before the first `render_frame` or after the legacy `render` path.
pub fn SkiaRasterRenderer::last_damage_report(
  self : SkiaRasterRenderer,
) -> SkiaDamageReport? {
  self.last_damage_report
}

///|
/// Reports surface retention separately from drawable retention. A persistent
/// offscreen GPU backing can be updated partially even though every fresh
/// drawable receives a full-pixel copy; no partial present is attempted.
pub fn SkiaRasterRenderer::partial_repaint_report(
  self : SkiaRasterRenderer,
) -> SkiaPartialRepaintReport {
  let persistent_backing = self.gpu_target is Some(_) &&
    self.surface_route is MetalGpuSurfaceRoute
  let drawable_retained = self.gpu_target is None
  let partial_redraw = self.surface_damage is SubRect &&
    (persistent_backing || drawable_retained)
  SkiaPartialRepaintReport::new(
    surface_damage=self.surface_damage,
    drawable_retained~,
    persistent_backing~,
    partial_redraw~,
    partial_present=false,
  )
}

///|
pub fn SkiaRasterRenderer::last_frame(
  self : SkiaRasterRenderer,
) -> SkiaPixelFrame? {
  self.last_frame
}

///| Draw platform view content (e.g., offscreen webview pixels) onto the surface

///|
/// This should be called after render_frame but before the window system presents
pub fn SkiaRasterRenderer::draw_platform_view_pixels(
  self : SkiaRasterRenderer,
  pixels : Bytes,
  src_width : Int32,
  src_height : Int32,
  src_stride : Int32,
  dst_x : Double,
  dst_y : Double,
  dst_width : Double,
  dst_height : Double,
) -> Unit {
  let recording_canvas = self.platform_view_recording_canvas
  let canvas = match recording_canvas {
    Some(canvas) => Some(canvas)
    None => self.surface.canvas()
  }
  match canvas {
    Some(canvas) =>
      match
        @skia_native.Bitmap::from_pixels(
          pixels, src_width, src_height, src_stride,
        ) {
        Some(bitmap) =>
          match @skia_native.Image::from_bitmap(bitmap) {
            Some(image) => {
              let src_rect = @moui_skia.Rect::from_xywh(
                0.0,
                0.0,
                Float::from_int(src_width),
                Float::from_int(src_height),
              )
              let dst_rect = @moui_skia.Rect::from_xywh(
                Float::from_double(dst_x * self.metrics.scale_factor),
                Float::from_double(dst_y * self.metrics.scale_factor),
                Float::from_double(dst_width * self.metrics.scale_factor),
                Float::from_double(dst_height * self.metrics.scale_factor),
              )
              canvas.draw_image_rect(
                image,
                src_rect,
                dst_rect,
                @moui_skia.Paint::new(),
                sampling=@moui_skia.SamplingOptions::linear(),
              )
              if recording_canvas is None {
                ignore(self.surface.flush_and_submit())
              }
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
}

///|
/// Set a callback to draw platform view pixels after command rendering but before flush.
pub fn SkiaRasterRenderer::set_platform_view_draw_fn(
  self : SkiaRasterRenderer,
  draw_fn : (() -> Unit)?,
) -> Unit {
  self.platform_view_draw_fn = draw_fn
}
