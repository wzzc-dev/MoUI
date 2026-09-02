///|
pub(all) suberror SkiaRendererError {
  SkiaUnavailable
  SurfaceUnavailable
  CanvasUnavailable
  ReadPixelsUnavailable
  GpuContextUnavailable(String)
  PresentFailed(String)
} derive(Eq, Debug, ToJson)

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
pub struct SkiaUnsupportedCommandDiagnostic {
  priv command : String
  priv reason : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SkiaFontResolution {
  SystemFontMgr
  EmptyTypeface
} derive(Eq, Debug, ToJson)

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
  priv image_cache : Map[String, @skia_native.Image]
  priv failed_images : Map[String, String]
  priv image_lifecycle : @render_common.ImageResourceLifecycle
  // Renderer-owned image pixels can change without a runtime tree/content
  // revision change (async decode completion).  Retained-layer keys include
  // this generation so placeholders are never replayed after an image is
  // ready.
  priv mut image_cache_generation : Int
  // Generation last committed to the host surface. A completion can arrive
  // between runtime paints, leaving the runtime's damage region stale; the
  // next frame must therefore use full damage until the new pixels present.
  priv mut presented_image_cache_generation : Int
  priv async_image_loading : Bool
  priv mut present_count : Int
  priv mut unsupported_command_count : Int
  priv unsupported_command_diagnostics : Array[SkiaUnsupportedCommandDiagnostic]
  priv mut last_frame : SkiaPixelFrame?
  priv layer_cache : Map[String, SkiaCachedLayerImageEntry]
  priv layer_cache_identity_index : Map[String, String]
  priv picture_layer_cache : Map[String, SkiaCachedLayerPictureEntry]
  priv picture_layer_cache_identity_index : Map[String, String]
  priv layer_cache_admissions : Map[String, SkiaCachedLayerAdmissionRecord]
  priv mut layer_cache_total_bytes : Int64
  priv mut picture_layer_cache_total_bytes : Int64
  priv mut layer_cache_tick : Int
  priv mut platform_view_draw_fn : (() -> Unit)?
  priv mut platform_view_recording_canvas : @skia_native.Canvas?
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
    backend=@render.RendererBackendKind::SkiaRasterNative,
    status=if available {
      @render.RendererCapabilityStatus::Supported
    } else {
      @render.RendererCapabilityStatus::Unavailable
    },
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
    backend=@render.RendererBackendKind::SkiaRasterNative,
    family=@render.RendererFamily::Skia,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=skia_provider_capabilities(
      provider_id="skia-raster",
      backend=@render.RendererBackendKind::SkiaRasterNative,
    ),
    description="Native Skia raster renderer that presents copied RGBA premultiplied pixel frames to the host.",
  )
}

///|
pub fn skia_gpu_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::SkiaGpuNative,
    family=@render.RendererFamily::Skia,
    presentation=@render.RendererPresentationModel::HostGpuSurface,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=skia_provider_capabilities(
      provider_id="skia-hybrid",
      backend=@render.RendererBackendKind::SkiaGpuNative,
    ),
    description="Native Skia GPU renderer identity for direct host GPU surfaces. Providers must prove a matching Metal, Vulkan, EGL/GLES, or Direct3D surface before selecting it; resolve_surface_route picks the platform-appropriate SurfaceRoute (metal/vulkan/egl/direct3d) and the matching HostGpuPresentTarget wiring. Auto prefers SkiaGpuNative when the host exposes a usable GPU surface; SkiaRasterNative remains the explicit mode and sticky recovery fallback.",
  )
}

///|
pub fn create_with_present_target(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
  async_image_loading? : Bool = false,
) -> SkiaRasterRenderer raise SkiaRendererError {
  create_with_present_target_and_route(
    metrics,
    target,
    surface_route=RasterSurfaceRoute,
    font_resolution~,
    async_image_loading~,
  )
}

///|
pub fn create_with_present_target_and_route(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  surface_route? : SkiaSurfaceRoute = SkiaSurfaceRoute::RasterSurfaceRoute,
  gpu_target? : HostGpuPresentTarget? = None,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
  async_image_loading? : Bool = false,
) -> SkiaRasterRenderer raise SkiaRendererError {
  if !skia_available() {
    raise SkiaRendererError::SkiaUnavailable
  }
  // The direct GPU present path requires a GPU surface route; pairing a
  // HostGpuPresentTarget with a RasterSurfaceRoute would silently present
  // a raster surface through a GPU presenter, which is a configuration error.
  if gpu_target is Some(_) && !surface_route.is_gpu() {
    raise SkiaRendererError::GpuContextUnavailable(
      "gpu-target-requires-gpu-surface-route",
    )
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
    image_cache: Map([]),
    failed_images: Map([]),
    image_lifecycle: @render_common.ImageResourceLifecycle::new(),
    image_cache_generation: 0,
    presented_image_cache_generation: 0,
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
      let plan = @render_common.lower_draw_commands(commands)
      for op in plan.ops {
        self.render_command(canvas, op, canvas_scopes)
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
        raise SkiaRendererError::SurfaceUnavailable
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
            self.presented_image_cache_generation = self.image_cache_generation
            self.last_frame = None
            match outcome.next_surface() {
              Some(next_surface) => self.surface = next_surface
              None => ()
            }
          } else {
            raise SkiaRendererError::PresentFailed(gpu_target.description)
          }
        }
        None => {
          let frame = self.read_frame()
          self.last_frame = Some(frame)
          if (self.target.present)(frame) {
            self.present_count = self.present_count + 1
            self.presented_image_cache_generation = self.image_cache_generation
          } else {
            raise SkiaRendererError::PresentFailed(self.target.description)
          }
        }
      }
    }
    None => raise SkiaRendererError::CanvasUnavailable
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
fn SkiaRasterRenderer::resolve_effective_damage(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @core.DamageRegion {
  // Image decode completion changes renderer-owned pixels without rebuilding
  // the runtime tree. Runtime damage can still describe an earlier sidebar or
  // scroll event, so painting only that stale rect would leave the newly ready
  // image (and any retained layer containing it) untouched. Force one full
  // surface pass after each image-cache generation change.
  if self.image_cache_generation != self.presented_image_cache_generation {
    return @core.DamageRegion::full("image resource completed")
  }
  // Host GPU surfaces (EGL/Metal/Vulkan/D3D window drawables) swap into a fresh
  // back buffer that does not retain prior frame pixels. Partial damage would
  // clear only the dirty rects and leave the rest white/undefined after a list
  // click or other local invalidation (seen on HarmonyOS egl-gpu as "everything
  // outside the click area goes white until a later full redraw").
  if self.gpu_target is Some(_) {
    return @core.DamageRegion::full(
      "host-gpu drawable has no preserved backbuffer",
    )
  }
  match frame.damage {
    @core.DamageRegion::Empty =>
      @core.DamageRegion::full("empty damage fallback")
    @core.DamageRegion::FullSurface(reason) =>
      @core.DamageRegion::FullSurface(reason)
    @core.DamageRegion::Rects(rects) => {
      let mut has_scope = false
      for command in frame.commands {
        match command {
          @core.DrawCommand::PushOpacity(_)
          | @core.DrawCommand::PushLayer(_)
          | @core.DrawCommand::PushFilter(_) => {
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
          Some(rect) => @core.DamageRegion::Rects([rect])
          None => @core.DamageRegion::full("empty damage rects fallback")
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
    @core.DamageRegion::Rects([rect, ..]) => canvas.clip_rect(skia_rect(rect))
    @core.DamageRegion::Empty | @core.DamageRegion::FullSurface(_) => ()
    @core.DamageRegion::Rects([]) => ()
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
    @core.DamageRegion::FullSurface(_) => canvas.clear(skia_color(clear_color))
    @core.DamageRegion::Rects(rects) =>
      // Per-rect clip + clear ensures each dirty region is independently cleared.
      for rect in rects {
        let saved = canvas.save()
        canvas.clip_rect(skia_rect(rect))
        canvas.clear(skia_color(clear_color))
        canvas.restore_to_count(saved)
      }
    @core.DamageRegion::Empty => ()
  }
}

///|
fn SkiaRasterRenderer::render_frame_inner(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult raise SkiaRendererError {
  self.ensure_gpu_window_surface()
  match self.surface.canvas() {
    Some(canvas) => {
      let (stats, complete) = self.draw_frame_to_canvas(
        canvas,
        frame,
        draw_platform_views=true,
      )
      if !complete {
        return stats.to_render_frame_result(presented=false)
      }
      if !self.surface.flush_and_submit() {
        raise SkiaRendererError::SurfaceUnavailable
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
            self.presented_image_cache_generation = self.image_cache_generation
            self.last_frame = None
            match outcome.next_surface() {
              Some(next_surface) => self.surface = next_surface
              None => ()
            }
            stats.to_render_frame_result(presented=true)
          } else {
            raise SkiaRendererError::PresentFailed(gpu_target.description)
          }
        }
        None => {
          let skia_frame = self.read_frame()
          self.last_frame = Some(skia_frame)
          if (self.target.present)(skia_frame) {
            self.present_count = self.present_count + 1
            self.presented_image_cache_generation = self.image_cache_generation
            stats.to_render_frame_result(presented=true)
          } else {
            raise SkiaRendererError::PresentFailed(self.target.description)
          }
        }
      }
    }
    None => raise SkiaRendererError::CanvasUnavailable
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
  // same damage clip so skipped cached layers retain their previous pixels.
  self.apply_damage_clip(canvas, effective_damage)
  self.apply_damage_clear(canvas, effective_damage, frame.clear_color)
  self.unsupported_command_count = 0
  self.unsupported_command_diagnostics.clear()
  let stats = SkiaCachedLayerFrameStats::new()
  let canvas_scopes : Array[@render_common.PlanScopeKind] = []
  let plan = @render_common.lower_draw_commands(frame.commands)
  let complete = self.render_cached_command_range(
    canvas,
    plan.ops,
    start_index=0,
    end_index=plan.ops.length(),
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
  @render.RendererBackendKind::SkiaRasterNative
}

///|
pub fn SkiaRasterRenderer::backend_info(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn SkiaRasterRenderer::present_count(self : SkiaRasterRenderer) -> Int {
  self.present_count
}

///|
pub fn SkiaRasterRenderer::unsupported_command_count(
  self : SkiaRasterRenderer,
) -> Int {
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
  src_width : Int,
  src_height : Int,
  src_stride : Int,
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
