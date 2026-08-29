///|
pub struct SkiaPixelFrame {
  priv width : Int
  priv height : Int
  priv row_bytes : Int
  priv scale_factor : Double
  priv pixels : Bytes
} derive(Eq, Debug)

///|
pub struct SkiaPresentTarget {
  priv description : String
  priv present : (SkiaPixelFrame) -> Bool
}

///|
/// Discriminator for which present path a `SkiaRasterRenderer` is wired to.
///
/// - `CpuPixelFrame`: the renderer reads pixels back via `Surface::read_pixels`
///   and hands a `SkiaPixelFrame` to the platform presenter. This is the only
///   path wired today on every platform and remains the default/test fallback
///   per ADR 0006.
/// - `HostGpuSurface`: the renderer is bound to a `HostGpuPresentTarget`. The
///   platform presenter owns a window-backed GPU surface (Metal drawable,
///   Vulkan swapchain, EGL surface, D3D12 swapchain) and Skia flushes the
///   drawable directly. `read_pixels` and the second CPU copy are skipped.
pub(all) enum SkiaPresentKind {
  CpuPixelFrame
  HostGpuSurface
} derive(Eq, Debug, ToJson)

///|
/// Present target for the direct host-GPU-surface route. The presenter takes a
/// flushed `@skia_native.Surface` and lets the platform present its underlying
/// drawable (Metal `CAMetalDrawable`, `VkSwapchainKHR` image, `EGLSurface`
/// backbuffer, or D3D12 swapchain backbuffer). No `SkiaPixelFrame`, no `Bytes`,
/// no `CGImage`/`UIImage`/`NSImage`/`Bitmap`/`PixelMap` intermediate.
///
/// `HostGpuPresentTarget` is a sibling of `SkiaPresentTarget`; both are
/// accepted by `create_with_present_target_and_route`. A renderer is bound to
/// exactly one of them. When `gpu_target = Some(_)`, `target_kind()` returns
/// `HostGpuSurface` and the render loop bypasses `read_frame`.
///
/// `create_window_surface` is invoked lazily immediately before the first
/// render, after the native event loop can provide a drawable, and again on
/// each resize after attachment. It receives the `GpuContext` the renderer
/// created internally (via `create_gpu_context`) and the current surface
/// metrics, and returns a window-backed `Surface` (e.g. one wrapping a Metal
/// `CAMetalDrawable`'s `MTLTexture`). When it returns `None`, the renderer
/// raises `SurfaceUnavailable`. The constructor's offscreen GPU surface is a
/// typed placeholder only; no commands are recorded into it, so the first
/// rendered frame still goes directly to the host drawable with no readback.
///
/// `present_gpu` is invoked each frame after `flush_and_submit`. It receives
/// the same `GpuContext` and the flushed `Surface`. It returns the optional
/// `Surface` to use for the *next* frame. GPU backends whose Skia `Surface` is
/// bound to a per-frame drawable (Metal `CAMetalDrawable`, Vulkan swapchain
/// image) return a fresh `Surface`; backends that reuse the same `Surface`
/// (e.g. a long-lived `EGLSurface`/D3D12 swapchain backbuffer wrapped via
/// `SkSurfaces::WrapBackendSurface`) return `None` to keep the current one.
/// Returning `Some(surface)` causes the renderer to swap `self.surface` to
/// the returned value before the next frame.
pub struct HostGpuPresentTarget {
  priv description : String
  priv create_window_surface : (@skia_native.GpuContext?, @core.SurfaceMetrics) -> @skia_native.Surface?
  priv present_gpu : (@skia_native.GpuContext?, @skia_native.Surface) -> HostGpuPresentOutcome
}

///|
/// Outcome of a `HostGpuPresentTarget::present_gpu` call.
///
/// - `succeeded`: whether the platform presented the drawable successfully.
/// - `next_surface`: `Some(surface)` to swap the renderer's surface for the
///   next frame (per-drawable GPU backends); `None` to keep the current
///   surface (long-lived GPU backends).
pub(all) struct HostGpuPresentOutcome {
  priv succeeded : Bool
  priv next_surface : @skia_native.Surface?
}

///|
pub fn HostGpuPresentOutcome::new(
  succeeded~ : Bool,
  next_surface? : @skia_native.Surface? = None,
) -> HostGpuPresentOutcome {
  { succeeded, next_surface }
}

///|
pub fn HostGpuPresentOutcome::succeeded(self : HostGpuPresentOutcome) -> Bool {
  self.succeeded
}

///|
pub fn HostGpuPresentOutcome::next_surface(
  self : HostGpuPresentOutcome,
) -> @skia_native.Surface? {
  self.next_surface
}

///|
pub fn HostGpuPresentTarget::new(
  description~ : String,
  create_window_surface~ : (@skia_native.GpuContext?, @core.SurfaceMetrics) -> @skia_native.Surface?,
  present_gpu~ : (@skia_native.GpuContext?, @skia_native.Surface) -> HostGpuPresentOutcome,
) -> HostGpuPresentTarget {
  { description, create_window_surface, present_gpu }
}

///|
pub fn HostGpuPresentTarget::description(self : HostGpuPresentTarget) -> String {
  self.description
}

///|
/// `SkiaSurfaceRoute` is renderer-local because it names concrete graphics
/// APIs that must not cross the root `moui/render` boundary.

///|
priv struct SkiaRasterSurfacePreflight {
  physical_width : Int
  physical_height : Int
  target_ready : Bool
  frame_ready : Bool
  finalization_ready : Bool
  submission_ready : Bool
  resource_count : Int
  cacheable_resource_count : Int
  uncacheable_resource_count : Int
  gpu_backed_resource_count : Int
  surface_resource_count : Int
  byte_size : Int64
}

///|
fn SkiaRasterSurfacePreflight::summary(
  self : SkiaRasterSurfacePreflight,
) -> String {
  let dimensions_ready = self.physical_width > 0 && self.physical_height > 0
  let ready = dimensions_ready &&
    self.target_ready &&
    self.frame_ready &&
    self.finalization_ready &&
    self.submission_ready &&
    self.resource_count ==
    self.cacheable_resource_count + self.uncacheable_resource_count &&
    self.surface_resource_count > 0 &&
    self.gpu_backed_resource_count == 0 &&
    self.byte_size > 0L
  if ready {
    "SurfaceTargetDescriptor finalization preflight ready"
  } else {
    "SurfaceTargetDescriptor finalization preflight pending"
  }
}

///|
fn skia_gpu_context_status_label(
  status : @skia_native.SkiaGpuContextSupportStatus,
) -> String {
  match status {
    @skia_native.SkiaGpuContextAvailable => "available"
    @skia_native.SkiaGpuContextSkiaUnavailable => "skia-unavailable"
    @skia_native.SkiaGpuContextAnonymous => "anonymous"
    @skia_native.SkiaGpuContextMockUnsupported => "mock-unsupported"
    @skia_native.SkiaGpuContextBackendUnsupported => "backend-unsupported"
    @skia_native.SkiaGpuContextMetalOptInDisabled => "metal-opt-in-disabled"
    @skia_native.SkiaGpuContextMetalHeadersUnavailable =>
      "metal-headers-unavailable"
    @skia_native.SkiaGpuContextMetalRuntimeUnavailable =>
      "metal-runtime-unavailable"
    @skia_native.SkiaGpuContextDirect3DOptInDisabled =>
      "direct3d-opt-in-disabled"
    @skia_native.SkiaGpuContextDirect3DHeadersUnavailable =>
      "direct3d-headers-unavailable"
    @skia_native.SkiaGpuContextDirect3DRuntimeUnavailable =>
      "direct3d-runtime-unavailable"
    @skia_native.SkiaGpuContextVulkanOptInDisabled => "vulkan-opt-in-disabled"
    @skia_native.SkiaGpuContextVulkanHeadersUnavailable =>
      "vulkan-headers-unavailable"
    @skia_native.SkiaGpuContextVulkanRuntimeUnavailable =>
      "vulkan-runtime-unavailable"
    @skia_native.SkiaGpuContextEglOptInDisabled => "egl-opt-in-disabled"
    @skia_native.SkiaGpuContextEglHeadersUnavailable =>
      "egl-headers-unavailable"
    @skia_native.SkiaGpuContextEglRuntimeUnavailable =>
      "egl-runtime-unavailable"
  }
}

///|
pub fn skia_gpu_metal_preflight_summary() -> String {
  let context = @moui_skia.GpuContextDescriptor::metal(
    b"moui-render-skia-metal-preflight",
  )
  let target = @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(1, 1),
    gpu_context_key=Some(context.resource_key()),
  )
  let plan = target.resource_plan()
  let target_plan_ready = target.has_gpu_context() &&
    plan.count_kind(@moui_skia.GpuSurfaceResource) == 1 &&
    plan.count_kind(@moui_skia.GpuContextResource) == 1 &&
    plan.gpu_backed_count == 2
  let status = @skia_native.Surface::gpu_context_support_status(context)
  let target_label = if target_plan_ready {
    "target-plan-ready"
  } else {
    "target-plan-pending"
  }
  let surface_label = if status.is_available() {
    "explicit-offscreen-surface-api-ready"
  } else {
    "explicit-offscreen-surface-api-pending"
  }
  "Metal GPU opt-in preflight: context=\{skia_gpu_context_status_label(status)}; \{target_label}; \{surface_label}; window-present=pending"
}

///|
pub fn SkiaPresentTarget::new(
  description~ : String,
  present~ : (SkiaPixelFrame) -> Bool,
) -> SkiaPresentTarget {
  { description, present }
}

///|
pub fn SkiaPixelFrame::width(self : SkiaPixelFrame) -> Int {
  self.width
}

///|
pub fn SkiaPixelFrame::height(self : SkiaPixelFrame) -> Int {
  self.height
}

///|
pub fn SkiaPixelFrame::row_bytes(self : SkiaPixelFrame) -> Int {
  self.row_bytes
}

///|
pub fn SkiaPixelFrame::scale_factor(self : SkiaPixelFrame) -> Double {
  self.scale_factor
}

///|
pub fn SkiaPixelFrame::pixels(self : SkiaPixelFrame) -> Bytes {
  self.pixels
}

///|
/// Adapt a live Skia renderer to the renderer-neutral host lifecycle.
pub fn SkiaRasterRenderer::to_renderer_session(
  self : SkiaRasterRenderer,
  image_source? : @render.HostImageSource = @render.HostImageSource::unavailable(),
  image_decoder? : @render.RendererImageDecoder? = None,
  native_surface? : @render.NativeSurface? = None,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => {
      match native_surface {
        Some(surface) => surface.resize(metrics)
        None => ()
      }
      self.resize(metrics) catch {
        err => println("error resizing Skia renderer: \{err.message()}")
      }
    },
    render_frame=submission => self.render_frame(submission.frame()),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => self.dispose(),
    image_records=() => self.image_resources(),
    apply_image_load_completion=completion => {
      self.apply_image_resource_load_completion(completion)
    },
    image_source~,
    image_decoder~,
    platform_view=@render.RendererPlatformViewCapability::new(
      draw_platform_view_pixels=fn(
        pixels,
        src_width,
        src_height,
        src_stride,
        dst_x,
        dst_y,
        dst_width,
        dst_height,
      ) {
        self.draw_platform_view_pixels(
          pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
        )
      },
      set_platform_view_draw_fn=draw_fn => {
        self.set_platform_view_draw_fn(draw_fn)
      },
    ),
    native_surface~,
  )
}

///|
fn create_gpu_context(
  surface_route : SkiaSurfaceRoute,
) -> @skia_native.GpuContext? raise SkiaRendererError {
  match surface_route {
    SkiaSurfaceRoute::RasterSurfaceRoute => None
    SkiaSurfaceRoute::MetalGpuSurfaceRoute => {
      let descriptor = @moui_skia.GpuContextDescriptor::metal(
        b"moui-render-skia-metal-gpu",
      )
      match @skia_native.GpuContext::metal(descriptor) {
        Some(context) => Some(context)
        None => {
          let status = @skia_native.Surface::gpu_context_support_status(
            descriptor,
          )
          raise SkiaRendererError::GpuContextUnavailable(
            skia_gpu_context_status_label(status),
          )
        }
      }
    }
    SkiaSurfaceRoute::Direct3DGpuSurfaceRoute => {
      let descriptor = @moui_skia.GpuContextDescriptor::direct3d12(
        b"moui-render-skia-direct3d-gpu",
      )
      match @skia_native.GpuContext::direct3d12(descriptor) {
        Some(context) => Some(context)
        None => {
          let status = @skia_native.Surface::gpu_context_support_status(
            descriptor,
          )
          raise SkiaRendererError::GpuContextUnavailable(
            skia_gpu_context_status_label(status),
          )
        }
      }
    }
    SkiaSurfaceRoute::VulkanGpuSurfaceRoute => {
      let descriptor = @moui_skia.GpuContextDescriptor::vulkan(
        b"moui-render-skia-vulkan-gpu",
      )
      match @skia_native.GpuContext::vulkan(descriptor) {
        Some(context) => Some(context)
        None => {
          let status = @skia_native.Surface::gpu_context_support_status(
            descriptor,
          )
          raise SkiaRendererError::GpuContextUnavailable(
            skia_gpu_context_status_label(status),
          )
        }
      }
    }
    SkiaSurfaceRoute::EglGpuSurfaceRoute => {
      let descriptor = @moui_skia.GpuContextDescriptor::opengl(
        b"moui-render-skia-egl-gpu",
      )
      match @skia_native.GpuContext::egl(descriptor) {
        Some(context) => Some(context)
        None => {
          let status = @skia_native.Surface::gpu_context_support_status(
            descriptor,
          )
          raise SkiaRendererError::GpuContextUnavailable(
            skia_gpu_context_status_label(status),
          )
        }
      }
    }
  }
}

///|
fn create_surface(
  metrics : @core.SurfaceMetrics,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @skia_native.Surface raise SkiaRendererError {
  let target = skia_surface_target(metrics, surface_route, gpu_context)
  match surface_route {
    SkiaSurfaceRoute::RasterSurfaceRoute =>
      match @skia_native.Surface::for_target(target) {
        Some(surface) => surface
        None => raise SkiaRendererError::SurfaceUnavailable
      }
    SkiaSurfaceRoute::MetalGpuSurfaceRoute =>
      match gpu_context {
        None =>
          raise SkiaRendererError::GpuContextUnavailable(
            "missing-metal-gpu-context",
          )
        Some(gpu_context) =>
          match
            @skia_native.Surface::for_target_with_gpu_context(
              target, gpu_context,
            ) {
            Some(surface) => surface
            None => raise SkiaRendererError::SurfaceUnavailable
          }
      }
    SkiaSurfaceRoute::Direct3DGpuSurfaceRoute =>
      match gpu_context {
        None =>
          raise SkiaRendererError::GpuContextUnavailable(
            "missing-direct3d-gpu-context",
          )
        Some(gpu_context) =>
          match
            @skia_native.Surface::for_target_with_gpu_context(
              target, gpu_context,
            ) {
            Some(surface) => surface
            None => raise SkiaRendererError::SurfaceUnavailable
          }
      }
    SkiaSurfaceRoute::VulkanGpuSurfaceRoute =>
      match gpu_context {
        None =>
          raise SkiaRendererError::GpuContextUnavailable(
            "missing-vulkan-gpu-context",
          )
        Some(gpu_context) =>
          match
            @skia_native.Surface::for_target_with_gpu_context(
              target, gpu_context,
            ) {
            Some(surface) => surface
            None => raise SkiaRendererError::SurfaceUnavailable
          }
      }
    SkiaSurfaceRoute::EglGpuSurfaceRoute =>
      match gpu_context {
        None =>
          raise SkiaRendererError::GpuContextUnavailable(
            "missing-egl-gpu-context",
          )
        Some(gpu_context) =>
          match
            @skia_native.Surface::for_target_with_gpu_context(
              target, gpu_context,
            ) {
            Some(surface) => surface
            None => raise SkiaRendererError::SurfaceUnavailable
          }
      }
  }
}

///|
fn skia_surface_target(
  metrics : @core.SurfaceMetrics,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @moui_skia.SurfaceTargetDescriptor {
  let size = @moui_skia.ISize::new(
    skia_dim_to_int(metrics.physical_size.width),
    skia_dim_to_int(metrics.physical_size.height),
  )
  skia_surface_target_for_physical_size(size, surface_route, gpu_context)
}

///|
fn skia_surface_target_for_physical_size(
  size : @moui_skia.ISize,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @moui_skia.SurfaceTargetDescriptor {
  match surface_route {
    SkiaSurfaceRoute::RasterSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(size)
    SkiaSurfaceRoute::MetalGpuSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
        size,
        gpu_context_key=match gpu_context {
          Some(gpu_context) => Some(gpu_context.resource_key())
          None => None
        },
      )
    SkiaSurfaceRoute::Direct3DGpuSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
        size,
        gpu_context_key=match gpu_context {
          Some(gpu_context) => Some(gpu_context.resource_key())
          None => None
        },
      )
    SkiaSurfaceRoute::VulkanGpuSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
        size,
        gpu_context_key=match gpu_context {
          Some(gpu_context) => Some(gpu_context.resource_key())
          None => None
        },
      )
    SkiaSurfaceRoute::EglGpuSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::gpu_n32_premul(
        size,
        gpu_context_key=match gpu_context {
          Some(gpu_context) => Some(gpu_context.resource_key())
          None => None
        },
      )
  }
}

///|
fn skia_raster_surface_target(
  metrics : @core.SurfaceMetrics,
) -> @moui_skia.SurfaceTargetDescriptor {
  @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(
    @moui_skia.ISize::new(
      skia_dim_to_int(metrics.physical_size.width),
      skia_dim_to_int(metrics.physical_size.height),
    ),
  )
}

///|
fn raster_surface_preflight(
  metrics : @core.SurfaceMetrics,
) -> SkiaRasterSurfacePreflight {
  let target = skia_raster_surface_target(metrics)
  let command_list = @moui_skia.RenderCommandList::for_target(target).clear(
    @moui_skia.Color::transparent(),
  )
  let frame = command_list.frame_descriptor(target)
  let finalization = frame.finalization_descriptor()
  let submission = frame.submission_descriptor()
  let resource_plan = finalization.resource_plan
  SkiaRasterSurfacePreflight::{
    physical_width: target.dimensions().width,
    physical_height: target.dimensions().height,
    target_ready: !target.resource_key().is_empty(),
    frame_ready: frame.is_ready(),
    finalization_ready: finalization.is_ready(),
    submission_ready: submission.is_ready(),
    resource_count: resource_plan.length(),
    cacheable_resource_count: resource_plan.cacheable_count,
    uncacheable_resource_count: resource_plan.uncacheable_count,
    gpu_backed_resource_count: resource_plan.gpu_backed_count,
    surface_resource_count: resource_plan.count_kind(@moui_skia.SurfaceResource),
    byte_size: resource_plan.byte_size,
  }
}

///|
pub fn SkiaRasterRenderer::resize(
  self : SkiaRasterRenderer,
  metrics : @core.SurfaceMetrics,
) -> Unit raise SkiaRendererError {
  // Skip no-op resizes that the host emits redundantly during layout
  // (e.g. duplicate SurfaceResized from viewFrameDidChange + windowDidResize).
  if self.metrics == metrics {
    return
  }
  let previous = self.metrics
  self.metrics = metrics
  self.surface = match self.gpu_target {
    Some(gpu_target) =>
      if self.gpu_surface_attached {
        match (gpu_target.create_window_surface)(self.gpu_context, metrics) {
          Some(surface) => surface
          // Keep the current surface when the host cannot produce a resized
          // window surface (Direct3D allows only one flip-model swap chain
          // per HWND, so live resizes converge through the present path's
          // ResizeBuffers instead of a recreated swap chain). Present
          // failures still fall back through render_frame.
          None => self.surface
        }
      } else {
        create_surface(metrics, self.surface_route, self.gpu_context)
      }
    None => create_surface(metrics, self.surface_route, self.gpu_context)
  }
  // Preserve cached layers during live resize. Clearing the entire cache on
  // every intermediate pixel forces a full raster of even static content
  // (e.g. floating button) each frame. Only flush when the surface grows
  // substantially or the scale factor changes – the cache key already
  // invalidates entries whose physical size no longer matches.
  let delta_w = (metrics.physical_size.width - previous.physical_size.width).abs()
  let delta_h = (metrics.physical_size.height - previous.physical_size.height).abs()
  let scale_changed = metrics.scale_factor != previous.scale_factor
  let large_resize = delta_w > 64.0 || delta_h > 64.0
  if scale_changed || large_resize {
    self.clear_layer_cache()
  }
}

///|
fn SkiaRasterRenderer::ensure_gpu_window_surface(
  self : SkiaRasterRenderer,
) -> Unit raise SkiaRendererError {
  if self.gpu_surface_attached {
    return
  }
  match self.gpu_target {
    Some(gpu_target) =>
      match (gpu_target.create_window_surface)(self.gpu_context, self.metrics) {
        Some(surface) => {
          self.surface = surface
          self.gpu_surface_attached = true
        }
        None => raise SkiaRendererError::SurfaceUnavailable
      }
    None => self.gpu_surface_attached = true
  }
}

///|
pub fn SkiaRasterRenderer::surface_route(
  self : SkiaRasterRenderer,
) -> SkiaSurfaceRoute {
  self.surface_route
}

///|
pub fn SkiaRasterRenderer::surface_is_gpu(self : SkiaRasterRenderer) -> Bool {
  self.surface.descriptor().is_gpu()
}

///|
/// Returns which present path the renderer is bound to. `CpuPixelFrame` reads
/// pixels back via `Surface::read_pixels` and hands a `SkiaPixelFrame` to the
/// platform presenter; `HostGpuSurface` lets the platform present a
/// window-backed GPU drawable directly with no CPU readback.
pub fn SkiaRasterRenderer::target_kind(
  self : SkiaRasterRenderer,
) -> SkiaPresentKind {
  match self.gpu_target {
    Some(_) => SkiaPresentKind::HostGpuSurface
    None => SkiaPresentKind::CpuPixelFrame
  }
}

///|
/// Returns the bound `HostGpuPresentTarget` when the renderer is on the direct
/// GPU present path. Returns `None` for the legacy CPU pixel-frame route.
pub fn SkiaRasterRenderer::gpu_target(
  self : SkiaRasterRenderer,
) -> HostGpuPresentTarget? {
  self.gpu_target
}

///|
pub fn SkiaRasterRenderer::surface_diagnostic_summary(
  self : SkiaRasterRenderer,
) -> String {
  let context = match self.gpu_context {
    Some(gpu_context) =>
      skia_gpu_context_status_label(gpu_context.support_status())
    None => "none"
  }
  let gpu_surface = if self.surface_is_gpu() { "true" } else { "false" }
  let present_kind = match self.target_kind() {
    SkiaPresentKind::CpuPixelFrame => "cpu-pixel-frame"
    SkiaPresentKind::HostGpuSurface => "host-gpu-surface"
  }
  "surface_route=\{self.surface_route.label()}; surface_gpu=\{gpu_surface}; gpu_context=\{context}; present_kind=\{present_kind}; dimensions=\{self.surface.width()}x\{self.surface.height()}"
}

///|
fn SkiaRasterRenderer::read_frame(
  self : SkiaRasterRenderer,
) -> SkiaPixelFrame raise SkiaRendererError {
  match self.surface.read_pixels() {
    Some(pixmap) =>
      {
        width: pixmap.width(),
        height: pixmap.height(),
        row_bytes: pixmap.row_bytes(),
        scale_factor: self.metrics.scale_factor,
        pixels: pixmap.pixels,
      }
    None => raise SkiaRendererError::ReadPixelsUnavailable
  }
}
