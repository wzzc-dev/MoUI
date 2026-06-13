///|
#borrow(pixels)
extern "C" fn windows_present_skia_pixels_to_hwnd(
  hwnd : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_windows_present_skia_pixels_to_hwnd"

///|
pub struct WindowsSkiaAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv web_view_commands : @host.HostWebViewCommandQueue?
  priv web_view_events : @host.HostWebViewEventSource?
}

///|
pub struct WindowsSkiaSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn WindowsSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  web_view_commands? : @host.HostWebViewCommandQueue? = None,
  web_view_events? : @host.HostWebViewEventSource? = None,
) -> WindowsSkiaAppOptions {
  { scene_resolver, font_resolution, web_view_commands, web_view_events }
}

///|
pub fn WindowsSkiaSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> WindowsSkiaSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=WindowsSkiaAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @core.AppRuntime,
  options~ : WindowsSkiaAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !windows_skia_provider_ready() {
    println(windows_skia_unavailable_message())
    return
  }
  @windows_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@windows_host.WindowsHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      web_view_commands=options.web_view_commands,
      web_view_events=options.web_view_events,
    ),
    window_requests~,
  )
}

///|
pub fn run_smoke_app_with_options(
  title : String,
  runtime : @core.AppRuntime,
  options~ : WindowsSkiaAppOptions,
  smoke_options? : WindowsSkiaSmokeOptions = WindowsSkiaSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !windows_skia_provider_ready() {
    println(windows_skia_unavailable_message())
    return
  }
  @windows_host.run_app_with_renderer_provider_smoke(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@windows_host.WindowsHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      web_view_commands=options.web_view_commands,
      web_view_events=options.web_view_events,
    ),
    smoke_options=@windows_host.WindowsHostSmokeOptions::new(
      first_frame_smoke_auto_exit=smoke_options.first_frame_smoke_auto_exit,
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : WindowsSkiaAppOptions = WindowsSkiaAppOptions::new(),
) -> @windows_host.WindowsRendererProvider {
  @windows_host.WindowsRendererProvider::new(
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
pub fn windows_skia_provider_preflight_summary(
  options? : WindowsSkiaAppOptions = WindowsSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if windows_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let host_preflight = @windows_host.windows_capability_summary().preflight_fields()
  "Windows Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; presenter=\{windows_skia_presenter_description()}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=smoke log required; unavailable=\"\{windows_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_image_load_completion; renderer_async_image_loading=post-present; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
  options : WindowsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !windows_skia_provider_ready() {
    println(windows_skia_unavailable_message())
    return None
  }
  Some(
    host_renderer_from_skia(
      @skia_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        windows_skia_present_target(window.window_handle()),
        font_resolution=options.font_resolution,
        async_image_loading=true,
      ),
    ),
  ) catch {
    err => {
      println("error creating Windows Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn windows_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
fn windows_skia_unavailable_message() -> String {
  "Windows Skia renderer selected, but moui_skia/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
}

///|
fn windows_skia_presenter_description() -> String {
  "Windows GDI Skia pixel presenter"
}

///|
fn windows_skia_present_target(
  hwnd : UInt64,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=windows_skia_presenter_description(),
    present=frame => {
      windows_present_skia_pixels_to_hwnd(
        hwnd,
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
        err => println("error resizing Windows Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Windows Skia frame: \{err.message()}")
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
