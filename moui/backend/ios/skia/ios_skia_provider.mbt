///|
#borrow(pixels)
extern "C" fn ios_present_skia_pixels_to_view(
  view_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_ios_present_skia_pixels_to_view"

///|
extern "C" fn ios_skia_metal_layer_for_view(view_handle : UInt64) -> UInt64 = "moui_ios_skia_metal_layer_for_view"

///|
extern "C" fn ios_skia_create_metal_view(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> UInt64 = "moui_ios_skia_create_metal_view"

///|
extern "C" fn ios_skia_release_metal_view(raw_view_handle : UInt64) -> Unit = "moui_ios_skia_release_metal_view"

///|
extern "C" fn ios_skia_configure_metal_layer(
  raw_view_handle : UInt64,
  raw_layer_handle : UInt64,
  width : Int,
  height : Int,
) -> Int = "moui_ios_skia_configure_metal_layer"

///|
pub struct IosSkiaAppOptions {
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv surface_route : @render.SkiaSurfaceRoute
}

///|
pub fn IosSkiaAppOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @render.SkiaSurfaceRoute = @render.SkiaSurfaceRoute::RasterSurfaceRoute,
) -> IosSkiaAppOptions {
  { font_resolution, surface_route }
}

///|
pub fn renderer_provider(
  options? : IosSkiaAppOptions = IosSkiaAppOptions::new(),
) -> @ios_host.IosRendererProvider {
  @ios_host.IosRendererProvider::new(
    create_renderer=(view, metrics) => {
      create_renderer_from_provider_bindings(view, metrics, options)
    },
    image_loader=Some(ios_skia_async_image_loader()),
  )
}

///|
fn ios_skia_async_image_loader() -> @render.HostAsyncImageLoader {
  @render.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@skia_renderer.skia_image_load_completion(source))
    None
  })
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  view~ : @ios_host.IosViewHandle,
  metrics~ : @host.HostSurfaceMetrics,
  options? : IosSkiaAppOptions = IosSkiaAppOptions::new(),
) -> @ios_host.IosRuntimeSession? {
  @ios_host.create_session(
    runtime~,
    view~,
    metrics~,
    provider=renderer_provider(options~),
  )
}

///|
pub fn ios_skia_provider_preflight_summary(
  options? : IosSkiaAppOptions = IosSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if ios_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let host_preflight = @ios_host.ios_capability_summary().preflight_fields()
  let gpu_runtime_available = @skia_native.Surface::metal_gpu_context_runtime_available()
  "iOS Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; surface_route=\{options.surface_route.label()}; presenter=\{ios_skia_presenter_description()}; gpu_presenter=\{ios_skia_gpu_presenter_description()}; gpu_runtime_available=\{gpu_runtime_available}; metal_view_factory=available; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=ios-simulator-smoke-required; runtime_status=runtime_partial; unavailable=\"\{ios_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SkiaRasterRenderer.render_frame; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
/// iOS creates bindings at the UIKit surface-attach boundary. A valid
/// CAMetalLayer negotiates the GPU binding first; the raster binding remains
/// the explicit recovery route without leaking UIKit handles into `render`.
fn create_renderer_from_provider_bindings(
  view : @ios_host.IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
  options : IosSkiaAppOptions,
) -> @render.HostWindowRenderer? {
  if !ios_skia_provider_ready() {
    println(ios_skia_unavailable_message())
    return None
  }
  let raster_binding = @skia_renderer.create_skia_raster_host_binding(create_host_renderer=(
    _renderer_metrics,
    _bound_surface,
  ) => {
    require_host_renderer(
      create_raster_renderer(view, metrics, options),
      "iOS Skia raster binding could not create a host renderer",
    )
  })
  let raster_surface = @render.SurfaceDescriptor::cpu_raster(
    width=metrics.logical_size.width,
    height=metrics.logical_size.height,
    scale_factor=metrics.scale_factor,
  )
  let layer_ptr = ios_skia_metal_layer_for_view(view.raw())
  if options.surface_route.is_gpu() && ios_skia_gpu_available() {
    match @render.GpuHostSurfaceDescriptor::metal_layer(layer_ptr) {
      Some(handle) => {
        let gpu_binding = @skia_renderer.create_skia_hybrid_host_binding(create_host_renderer=(
          _renderer_metrics,
          _bound_surface,
        ) => {
          require_host_renderer(
            create_gpu_worker_renderer(view, layer_ptr, metrics, options),
            "iOS Skia GPU binding could not create a host renderer",
          )
        })
        create_host_renderer_from_binding(
          [gpu_binding, raster_binding],
          @render.SurfaceDescriptor::gpu_surface(
            handle~,
            width=metrics.logical_size.width,
            height=metrics.logical_size.height,
            scale_factor=metrics.scale_factor,
          ),
          metrics,
        )
      }
      None =>
        create_host_renderer_from_binding(
          [raster_binding],
          raster_surface,
          metrics,
        )
    }
  } else {
    create_host_renderer_from_binding([raster_binding], raster_surface, metrics)
  }
}

///|
fn create_host_renderer_from_binding(
  bindings : Array[@render.RendererProviderBinding],
  surface : @render.SurfaceDescriptor,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostWindowRenderer? {
  match @render.select_renderer_provider_binding(bindings, surface) {
    Some((binding, bound_surface)) =>
      Some(
        (binding.create_host_renderer)(
          renderer_metrics_from_host(metrics),
          bound_surface,
        ),
      )
    None => None
  }
}

///|
fn require_host_renderer(
  renderer : @render.HostWindowRenderer?,
  message : String,
) -> @render.HostWindowRenderer {
  match renderer {
    Some(renderer) => renderer
    None => abort(message)
  }
}

///|
fn create_gpu_worker_renderer(
  view : @ios_host.IosViewHandle,
  layer_ptr : UInt64,
  metrics : @host.HostSurfaceMetrics,
  options : IosSkiaAppOptions,
) -> @render.HostWindowRenderer? {
  try {
    let renderer = @skia_renderer.create_with_present_target(
      renderer_metrics_from_host(metrics),
      ios_skia_present_target(view),
      font_resolution=options.font_resolution,
      async_image_loading=true,
    )
    match @skia_native.NativeGpuRenderWorker::new() {
      None => create_raster_renderer(view, metrics, options)
      Some(worker) => {
        let descriptor = ios_skia_metal_surface_descriptor(
          renderer_metrics_from_host(metrics),
        )
        let dimensions = descriptor.dimensions()
        if ios_skia_configure_metal_layer(
            view.raw(),
            layer_ptr,
            dimensions.width,
            dimensions.height,
          ) ==
          0 {
          worker.shutdown()
          return create_raster_renderer(view, metrics, options)
        }
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Attach(layer_ptr),
          ),
        )
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Resize(
              dimensions.width,
              dimensions.height,
            ),
          ),
        )
        ignore(worker.wait_completion(timeout_ms=1000))
        ignore(worker.drain_completions())
        println(
          "iOS Skia renderer route diagnostics: surface_route=metal-gpu; surface_gpu=true; gpu_context=worker-owned; present_kind=host-gpu-surface; dimensions=\{dimensions.width}x\{dimensions.height}",
        )
        Some(
          host_renderer_from_native_gpu_worker(
            renderer, worker, view, layer_ptr,
          ),
        )
      }
    }
  } catch {
    err => {
      println(
        "error creating iOS Skia Metal GPU worker renderer, falling back to raster: \{err.message()}",
      )
      create_raster_renderer(view, metrics, options)
    }
  }
}

///|
fn create_raster_renderer(
  view : @ios_host.IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
  options : IosSkiaAppOptions,
) -> @render.HostWindowRenderer? {
  Some(
    host_renderer_from_skia(
      @skia_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        ios_skia_present_target(view),
        font_resolution=options.font_resolution,
        async_image_loading=true,
      ),
    ),
  ) catch {
    err => {
      println("error creating iOS Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn ios_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
pub fn ios_skia_gpu_available() -> Bool {
  @skia_native.Surface::metal_gpu_context_runtime_available()
}

///|
fn ios_skia_unavailable_message() -> String {
  "iOS Skia renderer selected, but moui_skia/native is unavailable; configure MOUI_SKIA_PLATFORM=iosSim or ios, MOUI_SKIA_ARCH=<arch>, and iOS link flags before selecting iOS Skia"
}

///|
fn ios_skia_presenter_description() -> String {
  "iOS UIKit UIImageView Skia pixel presenter"
}

///|
fn ios_skia_present_target(
  view : @ios_host.IosViewHandle,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=ios_skia_presenter_description(),
    present=frame => {
      let pixels = frame.pixels()
      ios_present_skia_pixels_to_view(
        view.raw(),
        frame.width(),
        frame.height(),
        frame.row_bytes(),
        pixels,
        pixels.length(),
      ) !=
      0
    },
  )
}

///|
fn ios_skia_gpu_presenter_description() -> String {
  "iOS CAMetalLayer Skia Metal direct GPU presenter"
}

///|
fn ios_skia_metal_surface_descriptor(
  metrics : @render.RendererSurfaceMetrics,
) -> @moui_skia.SurfaceDescriptor {
  let physical = metrics.physical_size
  @moui_skia.SurfaceDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(
      physical.width.ceil().max(1.0).to_int(),
      physical.height.ceil().max(1.0).to_int(),
    ),
  )
}

///|
/// Create a `CAMetalLayer`-backed `UIView` for the Skia Metal direct-present
/// path. Returns `Some(IosViewHandle)` on success, or `None` when the Metal
/// view cannot be created (non-iOS, non-main-thread, or allocation failure).
/// The caller owns the reference and must call `ios_skia_release_metal_view_handle`
/// when the view is no longer needed (or add the view to a superview, which
/// retains it under standard ObjC ownership).
pub fn ios_skia_create_metal_view_handle(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @ios_host.IosViewHandle? {
  let raw = ios_skia_create_metal_view(x, y, width, height)
  if raw == 0UL {
    None
  } else {
    Some(@ios_host.IosViewHandle::new(raw~))
  }
}

///|
/// Release a Metal view previously created by `ios_skia_create_metal_view_handle`.
/// Safe to call with a handle whose raw value is 0.
pub fn ios_skia_release_metal_view_handle(
  view : @ios_host.IosViewHandle,
) -> Unit {
  ios_skia_release_metal_view(view.raw())
}

///|
fn ios_native_gpu_completion_to_render(
  completion : @skia_native.NativeGpuWorkerCompletion,
) -> @render.RenderPresentCompletion? {
  let status = match completion.status {
    @skia_native.NativeGpuWorkerCompletionStatus::PictureRecorded =>
      @render.RenderPresentStatus::Recorded
    @skia_native.NativeGpuWorkerCompletionStatus::Presented =>
      @render.RenderPresentStatus::Presented
    @skia_native.NativeGpuWorkerCompletionStatus::Dropped =>
      @render.RenderPresentStatus::Dropped
    @skia_native.NativeGpuWorkerCompletionStatus::FallbackToRaster =>
      @render.RenderPresentStatus::FallbackToRaster
    @skia_native.NativeGpuWorkerCompletionStatus::ControlAcknowledged
    | @skia_native.NativeGpuWorkerCompletionStatus::Unknown(_) => return None
  }
  Some(
    @render.RenderPresentCompletion::new(
      frame_sequence=completion.sequence.to_int(),
      surface_generation=completion.surface_generation,
      image_resource_revision=completion.image_resource_revision,
      submitted_at_ms=completion.submitted_at_ms,
      completed_at_ms=completion.processed_at_ms,
      presented_at_ms=completion.presented_at_ms,
      status~,
      gpu_context_generation=completion.context_generation,
    ),
  )
}

///|
fn host_renderer_from_native_gpu_worker(
  renderer : @skia_renderer.SkiaRasterRenderer,
  worker : @skia_native.NativeGpuRenderWorker,
  view : @ios_host.IosViewHandle,
  layer_ptr : UInt64,
) -> @render.HostWindowRenderer {
  let pending_completions : Array[@render.RenderPresentCompletion] = []
  let presented_count = Ref(0)
  let fallback_to_raster = Ref(false)
  let disposed = Ref(false)
  let collect_completions = () => {
    let presented = Ref(false)
    for completion in worker.drain_completions() {
      match ios_native_gpu_completion_to_render(completion) {
        Some(render_completion) => {
          if render_completion.status()
            is @render.RenderPresentStatus::Presented {
            presented.val = true
            presented_count.val = presented_count.val + 1
          } else if render_completion.status()
            is @render.RenderPresentStatus::FallbackToRaster {
            fallback_to_raster.val = true
          }
          pending_completions.push(render_completion)
        }
        None => ()
      }
    }
    presented.val
  }
  @render.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(metrics) catch {
        err => println("error resizing iOS Skia producer: \{err.message()}")
      }
      if !fallback_to_raster.val {
        let descriptor = ios_skia_metal_surface_descriptor(metrics)
        let dimensions = descriptor.dimensions()
        if ios_skia_configure_metal_layer(
            view.raw(),
            layer_ptr,
            dimensions.width,
            dimensions.height,
          ) ==
          0 {
          fallback_to_raster.val = true
        } else {
          ignore(
            worker.submit_control(
              @skia_native.GpuRenderWorkerControl::Resize(
                dimensions.width,
                dimensions.height,
              ),
            ),
          )
          ignore(collect_completions())
        }
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err =>
          println(
            "error rendering iOS Skia compatibility frame: \{err.message()}",
          )
      }
    },
    render_frame=Some(frame => {
      ignore(collect_completions())
      if fallback_to_raster.val {
        return renderer.render_frame(frame)
      }
      match renderer.record_frame_picture(frame) {
        None => renderer.render_frame(frame)
        Some(picture) => {
          let revision = renderer.image_resource_snapshot().revision.to_int64()
          let sequence = worker.submit_picture(
            picture,
            image_resource_revision=revision,
          )
          if sequence == 0L {
            fallback_to_raster.val = true
            renderer.render_frame(frame)
          } else {
            @render.RenderFrameResult::new(presented=false, queued=true)
          }
        }
      }
    }),
    drain_present_completions=Some(() => {
      ignore(collect_completions())
      let completions = pending_completions.copy()
      pending_completions.clear()
      completions
    }),
    text_system=() => renderer.text_system(),
    present_count=() => presented_count.val + renderer.present_count(),
    dispose=() => {
      if !disposed.val {
        disposed.val = true
        ignore(
          worker.submit_control(@skia_native.GpuRenderWorkerControl::Detach),
        )
        ignore(worker.wait_completion(timeout_ms=1000))
        ignore(worker.drain_completions())
        worker.shutdown()
        renderer.dispose()
      }
    },
    image=@render.HostRendererImageCapability::new(
      image_resources=() => renderer.image_resources(),
      image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        renderer.apply_image_resource_load_completion(completion)
      }),
      set_image_resource_change_callback=callback => {
        renderer.set_image_resource_change_callback(callback)
      },
    ),
    platform_view=@render.HostRendererPlatformViewCapability::new(
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
        renderer.draw_platform_view_pixels(
          pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
        )
      },
      set_platform_view_draw_fn=draw_fn => {
        renderer.set_platform_view_draw_fn(draw_fn)
      },
    ),
  )
}

///|
fn host_renderer_from_skia(
  renderer : @skia_renderer.SkiaRasterRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(metrics) catch {
        err => println("error resizing iOS Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering iOS Skia frame: \{err.message()}")
      }
    },
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
      set_image_resource_change_callback=callback => {
        renderer.set_image_resource_change_callback(callback)
      },
    ),
    platform_view=@render.HostRendererPlatformViewCapability::new(
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
        renderer.draw_platform_view_pixels(
          pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
        )
      },
      set_platform_view_draw_fn=draw_fn => {
        renderer.set_platform_view_draw_fn(draw_fn)
      },
    ),
  )
}

///|
fn renderer_metrics_from_host(
  metrics : @host.HostSurfaceMetrics,
) -> @render.RendererSurfaceMetrics {
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}
