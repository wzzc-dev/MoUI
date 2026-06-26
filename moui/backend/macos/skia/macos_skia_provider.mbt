///|
#borrow(pixels)
extern "C" fn macos_present_skia_pixels_to_view(
  raw_content_view_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_macos_present_skia_pixels_to_view"

///|
pub struct MacosSkiaAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv surface_route : @skia_renderer.SkiaSurfaceRoute
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv platform_attributes : @window_core.PlatformWindowAttributes
}

///|
pub struct MacosSkiaSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
  priv native_ime_runtime_smoke : Bool
}

///|
pub fn MacosSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @skia_renderer.SkiaSurfaceRoute = @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
  transparent_titlebar? : Bool = false,
  platform_attributes? : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
) -> MacosSkiaAppOptions {
  {
    scene_resolver,
    font_resolution,
    surface_route,
    platform_view_plugins,
    transparent_titlebar,
    platform_attributes,
  }
}

///|
pub fn MacosSkiaSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
  native_ime_runtime_smoke? : Bool = false,
) -> MacosSkiaSmokeOptions {
  { first_frame_smoke_auto_exit, native_ime_runtime_smoke }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=MacosSkiaAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : MacosSkiaAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !macos_skia_provider_ready() {
    println(macos_skia_unavailable_message())
    return
  }
  @macos_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@macos_host.MacosHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      platform_view_plugins=options.platform_view_plugins,
      transparent_titlebar=options.transparent_titlebar,
      platform_attributes=options.platform_attributes,
    ),
    window_requests~,
  )
}

///|
pub fn run_smoke_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : MacosSkiaAppOptions,
  smoke_options? : MacosSkiaSmokeOptions = MacosSkiaSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !macos_skia_provider_ready() {
    println(macos_skia_unavailable_message())
    return
  }
  @macos_host.run_app_with_renderer_provider_smoke(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@macos_host.MacosHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      platform_view_plugins=options.platform_view_plugins,
      transparent_titlebar=options.transparent_titlebar,
      platform_attributes=options.platform_attributes,
    ),
    smoke_options=@macos_host.MacosHostSmokeOptions::new(
      first_frame_smoke_auto_exit=smoke_options.first_frame_smoke_auto_exit,
      native_ime_runtime_smoke=smoke_options.native_ime_runtime_smoke,
    ),
    window_requests~,
  )
}

///|
pub async fn run_app_with_options_async_pump(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : MacosSkiaAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
  frame_interval_ms? : Int = 8,
) -> Unit {
  if !macos_skia_provider_ready() {
    println(macos_skia_unavailable_message())
    return ()
  }
  @macos_host.run_app_with_renderer_provider_async_pump(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@macos_host.MacosHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      platform_view_plugins=options.platform_view_plugins,
      transparent_titlebar=options.transparent_titlebar,
      platform_attributes=options.platform_attributes,
    ),
    window_requests~,
    frame_interval_ms~,
  )
}

///|
pub fn renderer_provider(
  options? : MacosSkiaAppOptions = MacosSkiaAppOptions::new(),
) -> @macos_host.MacosRendererProvider {
  @macos_host.MacosRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(skia_native_image_loader()),
  )
}

///|
fn skia_native_image_loader() -> @host.HostAsyncImageLoader {
  @host.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@skia_renderer.skia_image_load_completion(source))
    None
  })
}

///|
pub fn macos_skia_provider_preflight_summary(
  options? : MacosSkiaAppOptions = MacosSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if macos_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let surface_route = options.surface_route.label()
  let host_preflight = @macos_host.macos_capability_summary().preflight_fields()
  "macOS Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; surface_route=\{surface_route}; presenter=\{macos_skia_presenter_description()}; gpu_route=\{@skia_renderer.skia_gpu_metal_preflight_summary()}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=first-frame smoke required; unavailable=\"\{macos_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_image_load_completion; renderer_async_image_loading=post-present; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @window_macos.Window,
  metrics : @host.HostSurfaceMetrics,
  options : MacosSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !macos_skia_provider_ready() {
    println(macos_skia_unavailable_message())
    return None
  }
  match content_view_handle(window) {
    Some(raw_content_view_handle) =>
      try {
        let renderer = @skia_renderer.create_with_present_target_and_route(
          renderer_metrics_from_host(metrics),
          macos_skia_present_target(raw_content_view_handle),
          surface_route=options.surface_route,
          font_resolution=options.font_resolution,
          async_image_loading=true,
        )
        if options.surface_route.is_gpu() {
          println(
            "macOS Skia renderer route diagnostics: \{renderer.surface_diagnostic_summary()}",
          )
        }
        Some(host_renderer_from_skia(renderer))
      } catch {
        err => {
          println("error creating macOS Skia renderer: \{err.message()}")
          None
        }
      }
    None => None
  }
}

///|
fn macos_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
fn macos_skia_unavailable_message() -> String {
  "macOS Skia renderer selected, but moui_skia/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
}

///|
fn macos_skia_presenter_description() -> String {
  "macOS pass-through NSImageView Skia pixel presenter"
}

///|
fn content_view_handle(window : @window_macos.Window) -> UInt64? {
  Some(window.content_view_handle()) catch {
    err => {
      println("error resolving macOS content view handle for Skia: \{err}")
      None
    }
  }
}

///|
fn macos_skia_present_target(
  raw_content_view_handle : UInt64,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=macos_skia_presenter_description(),
    present=frame => {
      macos_present_skia_pixels_to_view(
        raw_content_view_handle,
        frame.width,
        frame.height,
        frame.row_bytes,
        frame.pixels,
        frame.pixels.length(),
      ) ==
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
        err => println("error resizing macOS Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering macOS Skia frame: \{err.message()}")
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
