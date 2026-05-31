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
}

///|
pub fn WindowsSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
) -> WindowsSkiaAppOptions {
  { scene_resolver, font_resolution }
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
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : WindowsSkiaAppOptions = WindowsSkiaAppOptions::new(),
) -> @windows_host.WindowsRendererProvider {
  @windows_host.WindowsRendererProvider::new(create_renderer=(window, metrics) => {
    create_renderer(window, metrics, options)
  })
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
  "Windows Skia renderer selected, but skia_mbt/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
}

///|
fn windows_skia_present_target(
  hwnd : UInt64,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description="Windows GDI Skia pixel presenter",
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
    text_system=() => renderer.text_system(),
    image_resources=() => renderer.image_resources(),
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
