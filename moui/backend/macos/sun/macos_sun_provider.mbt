///|
pub struct MacosSunAppOptions {
  priv scene_resolver : @runtime.HostWindowSceneResolver
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
  priv transparent_titlebar : Bool
  priv platform_attributes : @window_core.PlatformWindowAttributes
  priv on_ready : (() -> Unit)?
  priv min_window_size : @dpi.LogicalSize?
}

///|
pub struct MacosSunSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn MacosSunAppOptions::new(
  scene_resolver? : @runtime.HostWindowSceneResolver = @runtime.HostWindowSceneResolver::unavailable(),
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
  transparent_titlebar? : Bool = false,
  platform_attributes? : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
  on_ready? : (() -> Unit)? = None,
  min_window_size? : @dpi.LogicalSize? = None,
) -> MacosSunAppOptions {
  {
    scene_resolver,
    platform_view_plugins,
    transparent_titlebar,
    platform_attributes,
    on_ready,
    min_window_size,
  }
}

///|
pub fn MacosSunSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> MacosSunSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=MacosSunAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : MacosSunAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
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
  options~ : MacosSunAppOptions,
  smoke_options? : MacosSunSmokeOptions = MacosSunSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
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
    ),
    window_requests~,
  )
}

///|
pub async fn run_app_with_options_async_pump(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : MacosSunAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
  frame_interval_ms? : Int = 8,
) -> Unit {
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
  options? : MacosSunAppOptions = MacosSunAppOptions::new(),
) -> @macos_host.MacosRendererProvider {
  @macos_host.MacosRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(sun_native_image_loader()),
  )
}

///|
#borrow(source_bytes)
extern "C" fn moui_macos_sun_async_image_spawn(
  window_id : Int64,
  source_bytes : Bytes,
  source_len : Int,
) -> Unit = "moui_macos_sun_async_image_spawn"

///|
extern "C" fn moui_macos_sun_async_image_take_result() -> Bytes = "moui_macos_sun_async_image_take_result"

///|
fn async_image_read_i32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn sun_native_image_loader() -> @render.HostAsyncImageLoader {
  let native_source = @render.HostNativeAsyncImageSource::new()
  @render.HostNativeAsyncImageSource::loader_with_drain(
    native_source,
    spawn=(window_id, source) => {
      if source.has_prefix("data:") {
        let completion = @sun_renderer.sun_image_load_completion(source)
        ignore(native_source.complete(@render.RenderWindowId::new(window_id.value), completion))
      } else {
        let source_bytes = @utf8.encode(source[:], bom=false)
        moui_macos_sun_async_image_spawn(
          window_id.value.to_int64(),
          source_bytes,
          source_bytes.length(),
        )
      }
    },
    drain=() => {
      while true {
        let result = moui_macos_sun_async_image_take_result()
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
          @sun_renderer.sun_image_load_completion_from_bytes(
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
        ignore(native_source.complete(@render.RenderWindowId::new(window_id.value), completion))
      }
    },
  )
}

///|
pub fn macos_sun_provider_preflight_summary(
  options? : MacosSunAppOptions = MacosSunAppOptions::new(),
  smoke_options? : MacosSunSmokeOptions = MacosSunSmokeOptions::new(),
) -> String {
  ignore(options)
  let info = @sun_renderer.backend_info()
  let render_status = if macos_sun_provider_ready() {
    "experimental-ready"
  } else {
    "unavailable"
  }
  let first_frame = if smoke_options.first_frame_smoke_auto_exit {
    "enabled"
  } else {
    "disabled"
  }
  let presenter_hit_test = if @sun_softbuffer.macos_presenter_passthrough_ready() {
    "passthrough"
  } else {
    "blocking"
  }
  let host_preflight = @macos_host.macos_capability_summary().preflight_fields()
  "macOS Sun provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; renderer_preflight=\"\{info.description}\"; presenter=\{macos_sun_presenter_description()}; presenter_hit_test=\{presenter_hit_test}; first_frame_smoke=\{first_frame}; first_frame_env=MOUI_MACOS_SUN_EXIT_AFTER_FIRST_PRESENT; \{sun_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=matching-host pending; runtime_smokes=showcase-macos-sun; unavailable=\"\{macos_sun_unavailable_message()}\""
}

///|
fn sun_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SunRasterRenderer.render_frame; renderer_platform_view_pixels=SunRasterRenderer.draw_platform_view_pixels; renderer_text_system=SunRasterRenderer.text_system; renderer_image_resources=SunRasterRenderer.image_resources; renderer_image_loader=sun_image_load_completion; renderer_image_completion_source=HostNativeAsyncImageSource; renderer_async_image_loading=off-main-io; renderer_image_resource_apply=SunRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SunRasterRenderer.set_image_resource_change_callback; renderer_present_count=SunRasterRenderer.present_count; renderer_dispose=SunRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @window_macos.Window,
  metrics : @host.HostSurfaceMetrics,
  _options : MacosSunAppOptions,
) -> @render.HostWindowRenderer? {
  if !macos_sun_provider_ready() {
    println(macos_sun_unavailable_message())
    return None
  }
  match content_view_handle(window) {
    Some(raw_content_view_handle) =>
      Some(
        host_renderer_from_sun(
          @sun_renderer.create_with_present_target(
            renderer_metrics_from_host(metrics),
            macos_sun_present_target(raw_content_view_handle, metrics),
            async_image_loading=true,
          ),
        ),
      ) catch {
        err => {
          println("error creating macOS Sun renderer: \{err.message()}")
          None
        }
      }
    None => None
  }
}

///|
fn macos_sun_provider_ready() -> Bool {
  @sun_renderer.backend_info().can_render
}

///|
fn macos_sun_unavailable_message() -> String {
  "macOS Sun renderer selected, but moui_sun/native is unavailable"
}

///|
fn macos_sun_presenter_description() -> String {
  "macOS softbuffer Sun pixel presenter"
}

///|
fn content_view_handle(window : @window_macos.Window) -> UInt64? {
  Some(window.content_view_handle()) catch {
    err => {
      println("error resolving macOS content view handle for Sun: \{err}")
      None
    }
  }
}

///|
fn macos_sun_present_target(
  raw_content_view_handle : UInt64,
  metrics : @host.HostSurfaceMetrics,
) -> @sun_renderer.SunPresentTarget {
  let surface = @sun_softbuffer.NativeSurface::new(
    raw_content_view_handle,
    size_dim_to_int(metrics.physical_size.width),
    size_dim_to_int(metrics.physical_size.height),
  )
  @sun_renderer.SunPresentTarget::new(
    description=macos_sun_presenter_description(),
    present=frame => {
      surface.resize(frame.width(), frame.height())
      match
        surface.present_pixels(
          frame.width(),
          frame.height(),
          frame.row_bytes(),
          frame.pixels(),
        ) {
        Ok(_) => true
        Err(_) => {
          println("error presenting macOS Sun frame")
          false
        }
      }
    },
  )
}

///|
fn host_renderer_from_sun(
  renderer : @sun_renderer.SunRasterRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(metrics) catch {
        err => println("error resizing macOS Sun renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering macOS Sun frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => renderer.render_frame(frame)),
    text_system=() => renderer.text_system(),
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
    image=@render.HostRendererImageCapability::new(
      image_resources=() => renderer.image_resources(),
      image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        renderer.apply_image_resource_load_completion(completion)
      }),
      set_image_resource_change_callback=callback => {
        renderer.set_image_resource_change_callback(callback)
      },
    ),
    platform_view=@render.HostRendererPlatformViewCapability::new(
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
    ),
  )
}

///|
fn renderer_metrics_from_host(
  metrics : @host.HostSurfaceMetrics,
) -> @render.RendererSurfaceMetrics {
  let scale_factor = if metrics.scale_factor > 0.0 {
    metrics.scale_factor
  } else {
    1.0
  }
  let physical_size = @core.Size::new(
    width=if metrics.physical_size.width > 0.0 {
      metrics.physical_size.width
    } else {
      metrics.logical_size.width * scale_factor
    },
    height=if metrics.physical_size.height > 0.0 {
      metrics.physical_size.height
    } else {
      metrics.logical_size.height * scale_factor
    },
  )
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size~,
    scale_factor~,
  )
}

///|
fn size_dim_to_int(value : Double) -> Int {
  value.ceil().max(1.0).to_int()
}
