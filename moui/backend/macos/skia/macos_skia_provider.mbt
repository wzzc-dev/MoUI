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
  priv on_ready : (() -> Unit)?
  priv min_window_size : @dpi.LogicalSize?
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
  on_ready? : (() -> Unit)? = None,
  min_window_size? : @dpi.LogicalSize? = None,
) -> MacosSkiaAppOptions {
  {
    scene_resolver,
    font_resolution,
    surface_route,
    platform_view_plugins,
    transparent_titlebar,
    platform_attributes,
    on_ready,
    min_window_size,
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
fn MacosSkiaSmokeOptions::from_environment() -> MacosSkiaSmokeOptions {
  MacosSkiaSmokeOptions::new(
    first_frame_smoke_auto_exit=env_flag(
        "MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
      ) ||
      env_flag("MOUI_MARKDOWN_EDITOR_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT"),
    native_ime_runtime_smoke=env_flag("MOUI_MACOS_NATIVE_IME_EVIDENCE"),
  )
}

///|
fn MacosSkiaSmokeOptions::enabled(self : MacosSkiaSmokeOptions) -> Bool {
  self.first_frame_smoke_auto_exit || self.native_ime_runtime_smoke
}

///|
fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
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
  let smoke_options = MacosSkiaSmokeOptions::from_environment()
  if smoke_options.enabled() {
    run_smoke_app_with_options(
      title,
      runtime,
      options~,
      smoke_options~,
      window_requests~,
    )
    return
  }
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
      on_ready=options.on_ready,
      min_window_size=options.min_window_size,
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
      on_ready=options.on_ready,
      min_window_size=options.min_window_size,
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
      on_ready=options.on_ready,
      min_window_size=options.min_window_size,
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
    image_loader=Some(skia_async_image_loader()),
  )
}

///|
#borrow(source_bytes)
extern "C" fn moui_macos_async_image_spawn(
  window_id : Int64,
  source_bytes : Bytes,
  source_len : Int,
) -> Unit = "moui_macos_async_image_spawn"

///|
extern "C" fn moui_macos_async_image_take_result() -> Bytes = "moui_macos_async_image_take_result"

///|
fn async_image_read_i32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn skia_async_image_loader() -> @host.HostAsyncImageLoader {
  let native_source = @host.HostNativeAsyncImageSource::new()
  @host.HostNativeAsyncImageSource::loader_with_drain(
    native_source,
    spawn=(window_id, source) => {
      if source.has_prefix("data:") {
        let completion = @skia_renderer.skia_image_load_completion(source)
        ignore(native_source.complete(window_id, completion))
      } else {
        let source_bytes = @utf8.encode(source[:], bom=false)
        moui_macos_async_image_spawn(
          window_id.value.to_int64(),
          source_bytes,
          source_bytes.length(),
        )
      }
    },
    drain=() => {
      while true {
        let result = moui_macos_async_image_take_result()
        if result.length() == 0 {
          break
        }
        let window_id = @host.HostWindowId::new(
          async_image_read_i32_le(result, 0),
        )
        let status = async_image_read_i32_le(result, 8)
        let source_len = async_image_read_i32_le(result, 12)
        let bytes_len = async_image_read_i32_le(result, 16)
        let background_io_raw = async_image_read_i32_le(result, 20)
        let decoded_width = async_image_read_i32_le(result, 24)
        let decoded_height = async_image_read_i32_le(result, 28)
        let decoded_row_bytes = async_image_read_i32_le(result, 32)
        let background_decode_raw = async_image_read_i32_le(result, 36)
        let background_io = background_io_raw != 0
        let background_decode = background_decode_raw != 0
        let header = 40
        let source = @utf8.decode_lossy(
          result[header:header + source_len],
          ignore_bom=false,
        )
        let completion = if status == 0 && bytes_len > 0 {
          let pixels = result[header + source_len:header +
          source_len +
          bytes_len].to_owned()
          @render.ImageResourceLoadCompletion::ready_decoded_rgba(
            source,
            width=decoded_width,
            height=decoded_height,
            row_bytes=decoded_row_bytes,
            pixels,
            background_io~,
            background_decode~,
          )
        } else {
          @render.ImageResourceLoadCompletion::failed(
            source,
            diagnostic="Async image decode failed",
            background_io~,
          )
        }
        ignore(native_source.complete(window_id, completion))
      }
    },
  )
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
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_async_image_loader; renderer_async_image_loading=off-main-io; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
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
