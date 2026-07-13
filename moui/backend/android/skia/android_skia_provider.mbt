///|
#borrow(pixels)
extern "C" fn android_present_skia_pixels_to_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_android_present_skia_pixels_to_surface"

///|
pub struct AndroidSkiaAppOptions {
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv surface_route : @render.SkiaSurfaceRoute
}

///|
pub fn AndroidSkiaAppOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @render.SkiaSurfaceRoute = @render.SkiaSurfaceRoute::RasterSurfaceRoute,
) -> AndroidSkiaAppOptions {
  { font_resolution, surface_route }
}

///|
pub fn renderer_provider(
  options? : AndroidSkiaAppOptions = AndroidSkiaAppOptions::new(),
) -> @android_host.AndroidRendererProvider {
  @android_host.AndroidRendererProvider::new(
    create_renderer=(surface, metrics) => {
      create_renderer(surface, metrics, options)
    },
    image_loader=Some(android_skia_async_image_loader()),
  )
}

///|
fn android_skia_async_image_loader() -> @host.HostAsyncImageLoader {
  @host.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@skia_renderer.skia_image_load_completion(source))
    None
  })
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : @android_host.AndroidSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  options? : AndroidSkiaAppOptions = AndroidSkiaAppOptions::new(),
) -> @android_host.AndroidRuntimeSession? {
  @android_host.create_session(
    runtime~,
    surface~,
    metrics~,
    provider=renderer_provider(options~),
  )
}

///|
pub fn android_skia_provider_preflight_summary(
  options? : AndroidSkiaAppOptions = AndroidSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if android_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let surface_route = options.surface_route.label()
  let vulkan_runtime_available = @skia_native.Surface::vulkan_gpu_context_runtime_available()
  let egl_runtime_available = @skia_native.Surface::egl_gpu_context_runtime_available()
  let host_preflight = @android_host.android_capability_summary().preflight_fields()
  "Android Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; surface_route=\{surface_route}; presenter=\{android_skia_presenter_description()}; gpu_presenter=\{android_skia_gpu_presenter_description()}; vulkan_runtime_available=\{vulkan_runtime_available}; egl_runtime_available=\{egl_runtime_available}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=android-device-smoke-required; runtime_status=experimental-scaffold; unavailable=\"\{android_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SkiaRasterRenderer.render_frame; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  surface : @android_host.AndroidSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : AndroidSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !android_skia_provider_ready() {
    println(android_skia_unavailable_message())
    return None
  }
  let anw = surface.raw()
  if options.surface_route.is_gpu() &&
    anw != 0UL &&
    android_skia_gpu_available() {
    create_gpu_worker_renderer(surface, anw, metrics, options)
  } else {
    create_raster_renderer(surface, metrics, options)
  }
}

///|
fn create_gpu_worker_renderer(
  surface : @android_host.AndroidSurfaceHandle,
  anw : UInt64,
  metrics : @host.HostSurfaceMetrics,
  options : AndroidSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  try {
    let renderer = @skia_renderer.create_with_present_target(
      renderer_metrics_from_host(metrics),
      android_skia_present_target(surface),
      font_resolution=options.font_resolution,
      async_image_loading=true,
    )
    match @skia_native.NativeGpuRenderWorker::new() {
      None => create_raster_renderer(surface, metrics, options)
      Some(worker) => {
        let dimensions = android_skia_vulkan_surface_descriptor(
          renderer_metrics_from_host(metrics),
        ).dimensions()
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Attach(anw),
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
          "Android Skia renderer route diagnostics: surface_route=vulkan-or-egl-gpu; surface_gpu=true; gpu_context=worker-owned; present_kind=host-gpu-surface; dimensions=\{dimensions.width}x\{dimensions.height}",
        )
        Some(host_renderer_from_native_gpu_worker(renderer, worker))
      }
    }
  } catch {
    err => {
      println(
        "error creating Android GPU worker renderer, falling back to raster: \{err.message()}",
      )
      create_raster_renderer(surface, metrics, options)
    }
  }
}

///|
fn create_raster_renderer(
  surface : @android_host.AndroidSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : AndroidSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  try {
    let renderer = @skia_renderer.create_with_present_target_and_route(
      renderer_metrics_from_host(metrics),
      android_skia_present_target(surface),
      surface_route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
      font_resolution=options.font_resolution,
      async_image_loading=true,
    )
    Some(host_renderer_from_skia(renderer))
  } catch {
    err => {
      println("error creating Android Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn android_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
pub fn android_skia_gpu_available() -> Bool {
  @skia_native.Surface::vulkan_gpu_context_runtime_available() ||
  @skia_native.Surface::egl_gpu_context_runtime_available()
}

///|
fn android_skia_unavailable_message() -> String {
  "Android Skia renderer selected, but moui_skia/native is unavailable; configure MOUI_SKIA_PLATFORM=android and Android NDK link flags before selecting Android Skia"
}

///|
fn android_skia_presenter_description() -> String {
  "Android ANativeWindow RGBA8888 Skia pixel presenter"
}

///|
fn android_skia_gpu_presenter_description() -> String {
  "Android Vulkan with EGL/GLES fallback Skia direct GPU presenter"
}

///|
fn android_skia_vulkan_surface_descriptor(
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
fn android_native_gpu_completion_to_render(
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
) -> @host.HostWindowRenderer {
  let pending_completions : Array[@render.RenderPresentCompletion] = []
  let presented_count = Ref(0)
  let fallback_to_raster = Ref(false)
  let disposed = Ref(false)
  let collect_completions = () => {
    for completion in worker.drain_completions() {
      match android_native_gpu_completion_to_render(completion) {
        Some(render_completion) => {
          match render_completion.status() {
            @render.RenderPresentStatus::Presented =>
              presented_count.val = presented_count.val + 1
            @render.RenderPresentStatus::FallbackToRaster =>
              fallback_to_raster.val = true
            _ => ()
          }
          pending_completions.push(render_completion)
        }
        None => ()
      }
    }
  }
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
        err => println("error resizing Android Skia producer: \{err.message()}")
      }
      if !fallback_to_raster.val {
        let dimensions = android_skia_vulkan_surface_descriptor(
          renderer_metrics_from_host(metrics),
        ).dimensions()
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Resize(
              dimensions.width,
              dimensions.height,
            ),
          ),
        )
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Android Skia frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => {
      collect_completions()
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
      collect_completions()
      let completions = pending_completions.copy()
      pending_completions.clear()
      completions
    }),
    text_system=() => renderer.text_system(),
    image_resources=() => renderer.image_resources(),
    image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
    apply_image_resource_load_completion=Some(completion => {
      renderer.apply_image_resource_load_completion(completion)
    }),
    set_image_resource_change_callback=callback => {
      renderer.set_image_resource_change_callback(callback)
    },
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
  )
}

///|
fn android_skia_present_target(
  surface : @android_host.AndroidSurfaceHandle,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=android_skia_presenter_description(),
    present=frame => {
      let pixels = frame.pixels()
      android_present_skia_pixels_to_surface(
        surface.raw(),
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
fn host_renderer_from_skia(
  renderer : @skia_renderer.SkiaRasterRenderer,
) -> @host.HostWindowRenderer {
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
        err => println("error resizing Android Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Android Skia frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => renderer.render_frame(frame)),
    text_system=() => renderer.text_system(),
    image_resources=() => renderer.image_resources(),
    image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
    apply_image_resource_load_completion=Some(completion => {
      renderer.apply_image_resource_load_completion(completion)
    }),
    set_image_resource_change_callback=callback => {
      renderer.set_image_resource_change_callback(callback)
    },
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
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
