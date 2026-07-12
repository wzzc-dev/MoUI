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
pub struct IosSkiaAppOptions {
  priv font_resolution : @skia_renderer.SkiaFontResolution
}

///|
pub fn IosSkiaAppOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
) -> IosSkiaAppOptions {
  { font_resolution, }
}

///|
pub fn renderer_provider(
  options? : IosSkiaAppOptions = IosSkiaAppOptions::new(),
) -> @ios_host.IosRendererProvider {
  @ios_host.IosRendererProvider::new(
    create_renderer=(view, metrics) => create_renderer(view, metrics, options),
    image_loader=Some(ios_skia_async_image_loader()),
  )
}

///|
fn ios_skia_async_image_loader() -> @host.HostAsyncImageLoader {
  @host.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
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
  "iOS Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; presenter=\{ios_skia_presenter_description()}; gpu_presenter=\{ios_skia_gpu_presenter_description()}; gpu_runtime_available=\{gpu_runtime_available}; metal_view_factory=available; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=ios-simulator-smoke-required; runtime_status=experimental-scaffold; unavailable=\"\{ios_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SkiaRasterRenderer.render_frame; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  view : @ios_host.IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
  options : IosSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !ios_skia_provider_ready() {
    println(ios_skia_unavailable_message())
    return None
  }
  // Probe the Metal GPU route: when the native Skia build links Ganesh Metal
  // and the host view backs a CAMetalLayer, wire HostGpuPresentTarget to
  // eliminate read_pixels + memcpy + CGImage + UIImage.
  let layer_ptr = ios_skia_metal_layer_for_view(view.raw())
  let gpu_available = @skia_native.Surface::metal_gpu_context_runtime_available()
  if gpu_available && layer_ptr != 0UL {
    Some(
      host_renderer_from_skia(
        @skia_renderer.create_with_present_target_and_route(
          renderer_metrics_from_host(metrics),
          ios_skia_present_target(view),
          surface_route=@skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute,
          gpu_target=Some(ios_skia_gpu_present_target(view.raw(), layer_ptr)),
          font_resolution=options.font_resolution,
          async_image_loading=true,
        ),
      ),
    ) catch {
      err => {
        println(
          "error creating iOS Skia Metal GPU renderer, falling back to raster: \{err.message()}",
        )
        create_raster_renderer(view, metrics, options)
      }
    }
  } else {
    create_raster_renderer(view, metrics, options)
  }
}

///|
fn create_raster_renderer(
  view : @ios_host.IosViewHandle,
  metrics : @host.HostSurfaceMetrics,
  options : IosSkiaAppOptions,
) -> @host.HostWindowRenderer? {
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
/// Build the `HostGpuPresentTarget` for the Metal direct-present path.
///
/// `view_raw` is the raw `UIView*` handle; `layer_ptr` is the `CAMetalLayer*`
/// obtained via `ios_skia_metal_layer_for_view`. Both are captured by the
/// closures and reused on every frame. The `create_window_surface` callback is
/// invoked once at renderer creation and on each resize; it wraps the layer's
/// next `CAMetalDrawable` as a Skia `Surface`. The `present_gpu` callback is
/// invoked after each `flush_and_submit`; it presents the current drawable and
/// acquires the next one — no `read_pixels`, no `memcpy`, no `CGImage`, no
/// `UIImage`.
fn ios_skia_gpu_present_target(
  view_raw : UInt64,
  layer_ptr : UInt64,
) -> @skia_renderer.HostGpuPresentTarget {
  let _ = view_raw
  @skia_renderer.HostGpuPresentTarget::new(
    description=ios_skia_gpu_presenter_description(),
    create_window_surface=(gpu_context, metrics) => {
      match gpu_context {
        None => None
        Some(context) =>
          @skia_native.Surface::metal_window_surface(
            context,
            layer_ptr,
            ios_skia_metal_surface_descriptor(metrics),
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
          let outcome = @skia_native.Surface::metal_present_and_acquire_next(
            surface, context, layer_ptr,
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
fn host_renderer_from_skia(
  renderer : @skia_renderer.SkiaRasterRenderer,
) -> @host.HostWindowRenderer {
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
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
