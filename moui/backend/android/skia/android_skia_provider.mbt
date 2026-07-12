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
  priv surface_route : @skia_renderer.SkiaSurfaceRoute
}

///|
pub fn AndroidSkiaAppOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @skia_renderer.SkiaSurfaceRoute = @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute,
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
  let gpu_runtime_available = @skia_native.Surface::vulkan_gpu_context_runtime_available()
  let host_preflight = @android_host.android_capability_summary().preflight_fields()
  "Android Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; surface_route=\{surface_route}; presenter=\{android_skia_presenter_description()}; gpu_presenter=\{android_skia_gpu_presenter_description()}; gpu_runtime_available=\{gpu_runtime_available}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=android-device-smoke-required; runtime_status=experimental-scaffold; unavailable=\"\{android_skia_unavailable_message()}\""
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
  match resolve_gpu_present_target(anw, options) {
    Some(gpu_target) =>
      try {
        let renderer = @skia_renderer.create_with_present_target_and_route(
          renderer_metrics_from_host(metrics),
          android_skia_present_target(surface),
          surface_route=options.surface_route,
          gpu_target=Some(gpu_target),
          font_resolution=options.font_resolution,
          async_image_loading=true,
        )
        println(
          "Android Skia renderer route diagnostics: \{renderer.surface_diagnostic_summary()}",
        )
        Some(host_renderer_from_skia(renderer))
      } catch {
        err => {
          println(
            "error creating Android Skia Vulkan GPU renderer, falling back to raster: \{err.message()}",
          )
          create_raster_renderer(surface, metrics, options)
        }
      }
    None => create_raster_renderer(surface, metrics, options)
  }
}

///|
/// Resolve the optional `HostGpuPresentTarget` for the Android Vulkan
/// direct-present path. Returns `Some` when the user selected the Vulkan GPU
/// route AND the Skia build links Ganesh Vulkan AND a valid ANativeWindow is
/// available. Returns `None` to fall back to raster.
fn resolve_gpu_present_target(
  anw : UInt64,
  options : AndroidSkiaAppOptions,
) -> @skia_renderer.HostGpuPresentTarget? {
  if !options.surface_route.is_gpu() {
    return None
  }
  if anw == 0UL {
    println(
      "Android Skia Vulkan GPU route requested but ANativeWindow is unavailable; falling back to raster",
    )
    return None
  }
  let gpu_available = @skia_native.Surface::vulkan_gpu_context_runtime_available()
  if !gpu_available {
    println(
      "Android Skia Vulkan GPU route requested but Ganesh Vulkan runtime is unavailable; falling back to raster",
    )
    return None
  }
  Some(android_skia_gpu_present_target(anw))
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
      surface_route=@skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute,
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
fn android_skia_unavailable_message() -> String {
  "Android Skia renderer selected, but moui_skia/native is unavailable; configure MOUI_SKIA_PLATFORM=android and Android NDK link flags before selecting Android Skia"
}

///|
fn android_skia_presenter_description() -> String {
  "Android ANativeWindow RGBA8888 Skia pixel presenter"
}

///|
fn android_skia_gpu_presenter_description() -> String {
  "Android Vulkan Skia direct GPU presenter"
}

///|
/// Build the `HostGpuPresentTarget` for the Android Vulkan direct-present
/// path. `anw` is the raw `ANativeWindow*` handle retained by the Android
/// host surface. `create_window_surface` is invoked at renderer creation and
/// on resize; `present_gpu` is invoked per-frame after `flush_and_submit` to
/// present the swap chain and acquire the next swap chain image.
fn android_skia_gpu_present_target(
  anw : UInt64,
) -> @skia_renderer.HostGpuPresentTarget {
  @skia_renderer.HostGpuPresentTarget::new(
    description=android_skia_gpu_presenter_description(),
    create_window_surface=(gpu_context, metrics) => {
      match gpu_context {
        None => None
        Some(context) =>
          @skia_native.Surface::vulkan_window_surface(
            context,
            anw,
            android_skia_vulkan_surface_descriptor(metrics),
          )
      }
    },
    present_gpu=(gpu_context, surface) => {
      match gpu_context {
        None =>
          @skia_renderer.HostGpuPresentOutcome::new(
            succeeded=false,
            next_surface=None,
          )
        Some(context) => {
          let outcome = @skia_native.Surface::vulkan_present_and_acquire_next(
            surface, context, anw,
          )
          match outcome {
            Some(next_surface) =>
              @skia_renderer.HostGpuPresentOutcome::new(
                succeeded=true,
                next_surface=Some(next_surface),
              )
            None =>
              @skia_renderer.HostGpuPresentOutcome::new(
                succeeded=false,
                next_surface=None,
              )
          }
        }
      }
    },
  )
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
