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
/// Update the persistent backing and copy its complete pixels into the fresh
/// host drawable. The drawable is treated as uninitialized, so the copy must
/// cover it entirely. Host GPU drawables always resolve damage to a
/// full-surface overwrite because their back buffer is not preserved.
fn SkiaRasterRenderer::render_to_gpu_backing(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> SkiaCachedLayerFrameStats? {
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
  let previous_recording_canvas = self.platform_view_recording_canvas
  self.platform_view_recording_canvas = Some(canvas)
  let (stats, complete) = self.draw_frame_to_canvas(
    canvas,
    frame,
    draw_platform_views=true,
  )
  self.platform_view_recording_canvas = previous_recording_canvas
  if !complete || !backing.flush_and_submit() {
    self.invalidate_gpu_backing_surface()
    return None
  }
  if !self.surface.copy_from(backing) {
    self.invalidate_gpu_backing_surface()
    return None
  }
  Some(stats)
}

///|
/// Resolve the frame contract from the explicitly negotiated capability.
/// `FullSurfaceOnly` preserves the historical full overwrite. `SubRect` is
/// valid only for a CPU raster surface that retains prior pixels; the command
/// stream is clipped to the damage union and retained layers outside it keep
/// their previous pixels. Scope commands still fall back to full because
/// clip-scoped composition can affect pixels outside the dirty region. GPU
/// drawables always fall back because their back buffer is not preserved.
///
/// The `SubRect` path is gated by a pixel-comparison test against a
/// full-surface reference; unsupported hosts never receive the capability.
fn SkiaRasterRenderer::resolve_effective_damage(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @core.DamageRegion {
  if self.surface_damage is FullSurfaceOnly {
    return @core.DamageRegion::full("surface capability: full-surface-only")
  }
  // Host GPU drawables swap into a fresh back buffer. Even with a SubRect
  // capability the old pixels are not retained, so every frame is full.
  if self.gpu_target is Some(_) {
    return @core.DamageRegion::full(
      "host-gpu drawable has no preserved backbuffer",
    )
  }
  match frame.damage {
    Empty => Empty
    FullSurface(reason) => FullSurface(reason)
    Rects(rects) => {
      let mut has_scope = false
      for command in frame.commands {
        match command {
          PushOpacity(_) | PushLayer(_) | PushFilter(_) | PushTransform(_) => {
            has_scope = true
            break
          }
          _ => ()
        }
      }
      if has_scope {
        @core.DamageRegion::full("scope commands present with damage rects")
      } else {
        match skia_damage_rect_union(rects) {
          Some(rect) => Rects([rect])
          None => Empty
        }
      }
    }
  }
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
    frame.damage is Empty {
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
      let backing_stats = if self.platform_view_draw_fn is None &&
        self.ensure_gpu_backing_surface() {
        self.render_to_gpu_backing(frame)
      } else {
        None
      }
      let stats = match backing_stats {
        Some(stats) => {
          if !self.surface.flush_and_submit() {
            self.invalidate_gpu_backing_surface()
            raise SurfaceUnavailable
          }
          stats
        }
        None => {
          // Allocation/copy failure is an optimization failure only. Preserve
          // the existing conservative full redraw on the host drawable.
          self.invalidate_gpu_backing_surface()
          match self.surface.canvas() {
            Some(canvas) => {
              let (stats, complete) = self.draw_frame_to_canvas(
                canvas,
                frame,
                draw_platform_views=true,
              )
              if !complete {
                return self.render_frame_result(stats, presented=false)
              }
              if !self.surface.flush_and_submit() {
                raise SurfaceUnavailable
              }
              stats
            }
            None => raise CanvasUnavailable
          }
        }
      }
      let outcome = (gpu_target.present_gpu)(self.gpu_context, self.surface)
      if outcome.succeeded() {
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
          let (stats, complete) = self.draw_frame_to_canvas(
            canvas,
            frame,
            draw_platform_views=true,
          )
          if !complete {
            return self.render_frame_result(stats, presented=false)
          }
          if !self.surface.flush_and_submit() {
            raise SurfaceUnavailable
          }
          let skia_frame = self.read_frame()
          self.last_frame = Some(skia_frame)
          if (self.target.present)(skia_frame) {
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
) -> (SkiaCachedLayerFrameStats, Bool) {
  let effective_damage = self.resolve_effective_damage(frame)
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
