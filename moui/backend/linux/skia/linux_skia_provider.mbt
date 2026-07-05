///|
pub struct LinuxSkiaAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
}

///|
pub struct LinuxSkiaSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn LinuxSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
) -> LinuxSkiaAppOptions {
  { scene_resolver, font_resolution, platform_view_plugins }
}

///|
pub fn LinuxSkiaSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> LinuxSkiaSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=LinuxSkiaAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : LinuxSkiaAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !linux_skia_provider_ready() {
    println(linux_skia_unavailable_message())
    return
  }
  @linux_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@linux_host.LinuxHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      platform_view_plugins=options.platform_view_plugins,
    ),
    window_requests~,
  )
}

///|
pub fn run_smoke_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : LinuxSkiaAppOptions,
  smoke_options? : LinuxSkiaSmokeOptions = LinuxSkiaSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !linux_skia_provider_ready() {
    println(linux_skia_unavailable_message())
    return
  }
  @linux_host.run_app_with_renderer_provider_smoke(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@linux_host.LinuxHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      platform_view_plugins=options.platform_view_plugins,
    ),
    smoke_options=@linux_host.LinuxHostSmokeOptions::new(
      first_frame_smoke_auto_exit=smoke_options.first_frame_smoke_auto_exit,
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : LinuxSkiaAppOptions = LinuxSkiaAppOptions::new(),
) -> @linux_host.LinuxRendererProvider {
  @linux_host.LinuxRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(skia_async_image_loader()),
  )
}

///|
#borrow(source_bytes)
extern "C" fn moui_linux_async_image_spawn(
  window_id : Int64,
  source_bytes : Bytes,
  source_len : Int,
) -> Unit = "moui_linux_async_image_spawn"

///|
extern "C" fn moui_linux_async_image_take_result() -> Bytes = "moui_linux_async_image_take_result"

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
        moui_linux_async_image_spawn(
          window_id.value.to_int64(),
          source_bytes,
          source_bytes.length(),
        )
      }
    },
    drain=() => {
      while true {
        let result = moui_linux_async_image_take_result()
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
        let background_io = background_io_raw != 0
        let header = 24
        let source = @utf8.decode_lossy(
          result[header:header + source_len],
          ignore_bom=false,
        )
        let completion = if status == 0 && bytes_len > 0 {
          let image_bytes = result[header + source_len:header +
          source_len +
          bytes_len].to_owned()
          @skia_renderer.skia_image_load_completion_from_bytes(
            source,
            image_bytes,
            background_io~,
          )
        } else {
          @render.ImageResourceLoadCompletion::failed(
            source,
            diagnostic="Async image I/O failed",
            background_io~,
          )
        }
        ignore(native_source.complete(window_id, completion))
      }
    },
  )
}

///|
pub fn linux_skia_provider_preflight_summary(
  options? : LinuxSkiaAppOptions = LinuxSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if linux_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let host_preflight = @linux_host.linux_capability_summary().preflight_fields()
  "Linux Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; presenter=\{linux_skia_presenter_description()}; first_frame_smoke=disabled; first_frame_env=MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT|MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=smoke log required; runtime_smokes=showcase-linux-skia,markdown-editor-linux-skia,window-package-linux; service_runtime_evidence=clipboard,file-dialog,text-file,open-url,ime,drag-drop; unavailable=\"\{linux_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_async_image_loader; renderer_async_image_loading=off-main-io; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @window_linux.Window,
  metrics : @host.HostSurfaceMetrics,
  options : LinuxSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !linux_skia_provider_ready() {
    println(linux_skia_unavailable_message())
    return None
  }
  Some(
    host_renderer_from_skia(
      @skia_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        linux_skia_present_target(window),
        font_resolution=options.font_resolution,
        async_image_loading=true,
      ),
    ),
  ) catch {
    err => {
      println("error creating Linux Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn linux_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
fn linux_skia_unavailable_message() -> String {
  "Linux Skia renderer selected, but moui_skia/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
}

///|
fn linux_skia_presenter_description() -> String {
  "Linux Wayland wl_shm Skia pixel presenter"
}

///|
fn linux_skia_present_target(
  window : @window_linux.Window,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=linux_skia_presenter_description(),
    present=frame => {
      window.present_rgba_pixels(
        frame.width,
        frame.height,
        frame.row_bytes,
        frame.pixels,
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
        err => println("error resizing Linux Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Linux Skia frame: \{err.message()}")
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
