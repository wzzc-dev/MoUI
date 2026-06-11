///|
pub(all) struct SkiaPixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : Bytes
} derive(Eq, Debug)

///|
pub(all) struct SkiaPresentTarget {
  description : String
  present : (SkiaPixelFrame) -> Bool
}

///|
pub(all) enum SkiaSurfaceRoute {
  RasterSurfaceRoute
  MetalGpuSurfaceRoute
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaSurfaceRoute::is_gpu(self : SkiaSurfaceRoute) -> Bool {
  self is MetalGpuSurfaceRoute
}

///|
pub fn SkiaSurfaceRoute::label(self : SkiaSurfaceRoute) -> String {
  match self {
    RasterSurfaceRoute => "raster"
    MetalGpuSurfaceRoute => "metal-gpu"
  }
}

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
fn create_gpu_context(
  surface_route : SkiaSurfaceRoute,
) -> @skia_native.GpuContext? raise SkiaRendererError {
  match surface_route {
    RasterSurfaceRoute => None
    MetalGpuSurfaceRoute => {
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
  }
}

///|
fn create_surface(
  metrics : @render.RendererSurfaceMetrics,
  surface_route : SkiaSurfaceRoute,
  gpu_context : @skia_native.GpuContext?,
) -> @skia_native.Surface raise SkiaRendererError {
  let target = skia_surface_target(metrics, surface_route, gpu_context)
  match surface_route {
    RasterSurfaceRoute =>
      match @skia_native.Surface::for_target(target) {
        Some(surface) => surface
        None => raise SkiaRendererError::SurfaceUnavailable
      }
    MetalGpuSurfaceRoute =>
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
  }
}

///|
fn skia_surface_target(
  metrics : @render.RendererSurfaceMetrics,
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
    RasterSurfaceRoute =>
      @moui_skia.SurfaceTargetDescriptor::raster_n32_premul(size)
    MetalGpuSurfaceRoute =>
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
  metrics : @render.RendererSurfaceMetrics,
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
  metrics : @render.RendererSurfaceMetrics,
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

///|
pub fn SkiaRasterRenderer::resize(
  self : SkiaRasterRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit raise SkiaRendererError {
  self.metrics = metrics
  self.surface = create_surface(metrics, self.surface_route, self.gpu_context)
  self.clear_layer_cache()
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
pub fn SkiaRasterRenderer::surface_diagnostic_summary(
  self : SkiaRasterRenderer,
) -> String {
  let context = match self.gpu_context {
    Some(gpu_context) =>
      skia_gpu_context_status_label(gpu_context.support_status())
    None => "none"
  }
  let gpu_surface = if self.surface_is_gpu() { "true" } else { "false" }
  "surface_route=\{self.surface_route.label()}; surface_gpu=\{gpu_surface}; gpu_context=\{context}; dimensions=\{self.surface.width()}x\{self.surface.height()}"
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
