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
  @ios_host.IosRendererProvider::new(create_renderer=(view, metrics) => {
    create_renderer(view, metrics, options)
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
  "iOS Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; presenter=\{ios_skia_presenter_description()}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=ios-simulator-smoke-required; runtime_status=experimental-scaffold; unavailable=\"\{ios_skia_unavailable_message()}\""
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
  Some(
    host_renderer_from_skia(
      @skia_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        ios_skia_present_target(view),
        font_resolution=options.font_resolution,
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
      ios_present_skia_pixels_to_view(
        view.raw(),
        frame.width,
        frame.height,
        frame.row_bytes,
        frame.pixels,
        frame.pixels.length(),
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
