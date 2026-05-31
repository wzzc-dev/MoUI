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
  priv exit_after_first_present : Bool
}

///|
pub fn MacosSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::EmptyTypeface,
  exit_after_first_present? : Bool = false,
) -> MacosSkiaAppOptions {
  { scene_resolver, font_resolution, exit_after_first_present }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
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
  runtime : @core.AppRuntime,
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
      exit_after_first_present=options.exit_after_first_present,
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : MacosSkiaAppOptions = MacosSkiaAppOptions::new(),
) -> @macos_host.MacosRendererProvider {
  @macos_host.MacosRendererProvider::new(create_renderer=(window, metrics) => {
    create_renderer(window, metrics, options)
  })
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
      Some(
        host_renderer_from_skia(
          @skia_renderer.create_with_present_target(
            renderer_metrics_from_host(metrics),
            macos_skia_present_target(raw_content_view_handle),
            font_resolution=options.font_resolution,
          ),
        ),
      ) catch {
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
  "macOS Skia renderer selected, but skia_mbt/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
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
    description="macOS NSImageView Skia pixel presenter",
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
