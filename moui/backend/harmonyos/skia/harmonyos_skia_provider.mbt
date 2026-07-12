///|
#borrow(pixels)
extern "C" fn harmonyos_present_skia_pixels_to_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_harmonyos_present_skia_pixels_to_surface"

///|
pub struct HarmonyOsSkiaAppOptions {
  priv font_resolution : @skia_renderer.SkiaFontResolution
}

///|
pub fn HarmonyOsSkiaAppOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
) -> HarmonyOsSkiaAppOptions {
  { font_resolution, }
}

///|
pub fn renderer_provider(
  options? : HarmonyOsSkiaAppOptions = HarmonyOsSkiaAppOptions::new(),
) -> @harmonyos_host.HarmonyOsRendererProvider {
  @harmonyos_host.HarmonyOsRendererProvider::new(
    create_renderer=(surface, metrics) => {
      create_renderer(surface, metrics, options)
    },
    image_loader=Some(harmonyos_skia_async_image_loader()),
  )
}

///|
fn harmonyos_skia_async_image_loader() -> @host.HostAsyncImageLoader {
  @host.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@skia_renderer.skia_image_load_completion(source))
    None
  })
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  options? : HarmonyOsSkiaAppOptions = HarmonyOsSkiaAppOptions::new(),
) -> @harmonyos_host.HarmonyOsRuntimeSession? {
  @harmonyos_host.create_session(
    runtime~,
    surface~,
    metrics~,
    provider=renderer_provider(options~),
  )
}

///|
pub fn harmonyos_skia_provider_preflight_summary(
  options? : HarmonyOsSkiaAppOptions = HarmonyOsSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if harmonyos_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let host_preflight = @harmonyos_host.harmonyos_capability_summary().preflight_fields()
  "HarmonyOS Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; presenter=\{harmonyos_skia_presenter_description()}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=harmonyos-device-smoke-required; runtime_status=experimental-scaffold; unavailable=\"\{harmonyos_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SkiaRasterRenderer.render_frame; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : HarmonyOsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !harmonyos_skia_provider_ready() {
    println(harmonyos_skia_unavailable_message())
    return None
  }
  Some(
    host_renderer_from_skia(
      @skia_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        harmonyos_skia_present_target(surface),
        font_resolution=options.font_resolution,
        async_image_loading=true,
      ),
    ),
  ) catch {
    err => {
      println("error creating HarmonyOS Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn harmonyos_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
fn harmonyos_skia_unavailable_message() -> String {
  "HarmonyOS Skia renderer selected, but moui_skia/native is unavailable; configure MOUI_SKIA_PLATFORM=harmonyos, MOUI_SKIA_ARCH=arm64, MOUI_SKIA_LINK_MODE=dynamic, and HarmonyOS native link flags before selecting HarmonyOS Skia"
}

///|
fn harmonyos_skia_presenter_description() -> String {
  "HarmonyOS XComponent native window RGBA8888 Skia pixel presenter"
}

///|
fn harmonyos_skia_present_target(
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=harmonyos_skia_presenter_description(),
    present=frame => {
      let pixels = frame.pixels()
      harmonyos_present_skia_pixels_to_surface(
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
        err =>
          println("error resizing HarmonyOS Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering HarmonyOS Skia frame: \{err.message()}")
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
