///|
pub struct WindowsSunAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
}

///|
pub struct WindowsSunSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn WindowsSunAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
) -> WindowsSunAppOptions {
  { scene_resolver, platform_view_plugins }
}

///|
pub fn WindowsSunSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> WindowsSunSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=WindowsSunAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : WindowsSunAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @windows_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@windows_host.WindowsHostAppOptions::new(
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
  options~ : WindowsSunAppOptions,
  smoke_options? : WindowsSunSmokeOptions = WindowsSunSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @windows_host.run_app_with_renderer_provider_smoke(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@windows_host.WindowsHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      platform_view_plugins=options.platform_view_plugins,
    ),
    smoke_options=@windows_host.WindowsHostSmokeOptions::new(
      first_frame_smoke_auto_exit=smoke_options.first_frame_smoke_auto_exit,
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : WindowsSunAppOptions = WindowsSunAppOptions::new(),
) -> @windows_host.WindowsRendererProvider {
  @windows_host.WindowsRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(sun_native_image_loader()),
  )
}

///|
#borrow(source_bytes)
extern "C" fn moui_windows_sun_async_image_spawn(
  window_id : Int64,
  source_bytes : Bytes,
  source_len : Int,
) -> Unit = "moui_windows_sun_async_image_spawn"

///|
extern "C" fn moui_windows_sun_async_image_take_result() -> Bytes = "moui_windows_sun_async_image_take_result"

///|
fn async_image_read_i32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn sun_native_image_loader() -> @host.HostAsyncImageLoader {
  let native_source = @host.HostNativeAsyncImageSource::new()
  @host.HostNativeAsyncImageSource::loader_with_drain(
    native_source,
    spawn=(window_id, source) => {
      if source.has_prefix("data:") {
        let completion = @sun_renderer.sun_image_load_completion(source)
        ignore(native_source.complete(window_id, completion))
      } else {
        let source_bytes = @utf8.encode(source[:], bom=false)
        moui_windows_sun_async_image_spawn(
          window_id.value.to_int64(),
          source_bytes,
          source_bytes.length(),
        )
      }
    },
    drain=() => {
      while true {
        let result = moui_windows_sun_async_image_take_result()
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
        ignore(native_source.complete(window_id, completion))
      }
    },
  )
}

///|
pub fn windows_sun_provider_preflight_summary(
  options? : WindowsSunAppOptions = WindowsSunAppOptions::new(),
  smoke_options? : WindowsSunSmokeOptions = WindowsSunSmokeOptions::new(),
) -> String {
  ignore(options)
  let info = @sun_renderer.backend_info()
  let render_status = if windows_sun_provider_ready() {
    "experimental-ready"
  } else {
    "unavailable"
  }
  let first_frame = if smoke_options.first_frame_smoke_auto_exit {
    "enabled"
  } else {
    "disabled"
  }
  let host_preflight = @windows_host.windows_capability_summary().preflight_fields()
  "Windows Sun provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; renderer_preflight=\"\{info.description}\"; presenter=\{windows_sun_presenter_description()}; first_frame_smoke=\{first_frame}; first_frame_env=MOUI_WINDOWS_SUN_EXIT_AFTER_FIRST_PRESENT; \{sun_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=matching-host pending; runtime_smokes=showcase-windows-sun; unavailable=\"\{windows_sun_unavailable_message()}\""
}

///|
fn sun_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SunRasterRenderer.render_frame; renderer_platform_view_pixels=SunRasterRenderer.draw_platform_view_pixels; renderer_text_system=SunRasterRenderer.text_system; renderer_image_resources=SunRasterRenderer.image_resources; renderer_image_loader=sun_image_load_completion; renderer_image_completion_source=HostNativeAsyncImageSource; renderer_async_image_loading=off-main-io; renderer_image_resource_apply=SunRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SunRasterRenderer.set_image_resource_change_callback; renderer_present_count=SunRasterRenderer.present_count; renderer_dispose=SunRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
  _options : WindowsSunAppOptions,
) -> @host.HostWindowRenderer? {
  if !windows_sun_provider_ready() {
    println(windows_sun_unavailable_message())
    return None
  }
  Some(
    host_renderer_from_sun(
      @sun_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        windows_sun_present_target(window.window_handle(), metrics),
        async_image_loading=true,
      ),
    ),
  ) catch {
    err => {
      println("error creating Windows Sun renderer: \{err.message()}")
      None
    }
  }
}

///|
fn windows_sun_provider_ready() -> Bool {
  @sun_renderer.backend_info().can_render
}

///|
fn windows_sun_unavailable_message() -> String {
  "Windows Sun renderer selected, but moui_sun/native is unavailable"
}

///|
fn windows_sun_presenter_description() -> String {
  "Windows softbuffer Sun pixel presenter"
}

///|
fn windows_sun_present_target(
  hwnd : UInt64,
  metrics : @host.HostSurfaceMetrics,
) -> @sun_renderer.SunPresentTarget {
  let surface = @sun_softbuffer.NativeSurface::new(
    hwnd,
    size_dim_to_int(metrics.physical_size.width),
    size_dim_to_int(metrics.physical_size.height),
  )
  @sun_renderer.SunPresentTarget::new(
    description=windows_sun_presenter_description(),
    present=frame => {
      surface.resize(frame.width(), frame.height())
      match
        surface.present_bytes(
          frame.width(),
          frame.height(),
          frame.row_bytes(),
          frame.bytes(),
        ) {
        Ok(_) => true
        Err(_) => {
          println("error presenting Windows Sun frame")
          false
        }
      }
    },
  )
}

///|
fn host_renderer_from_sun(
  renderer : @sun_renderer.SunRasterRenderer,
) -> @host.HostWindowRenderer {
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
        err => println("error resizing Windows Sun renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Windows Sun frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => renderer.render_frame(frame)),
    text_system=() => renderer.text_system(),
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
    image=@host.HostRendererImageCapability::new(
      image_resources=() => renderer.image_resources(),
      image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        renderer.apply_image_resource_load_completion(completion)
      }),
      set_image_resource_change_callback=callback => {
        renderer.set_image_resource_change_callback(callback)
      },
    ),
    platform_view=@host.HostRendererPlatformViewCapability::new(
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
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}

///|
fn size_dim_to_int(value : Double) -> Int {
  if value != value || value <= 0.0 {
    0
  } else {
    value.ceil().to_int().max(1)
  }
}
