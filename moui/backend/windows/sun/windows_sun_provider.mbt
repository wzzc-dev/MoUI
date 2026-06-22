///|
pub struct WindowsSunAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
}

///|
pub struct WindowsSunSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn WindowsSunAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
) -> WindowsSunAppOptions {
  { scene_resolver, }
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
  @windows_host.WindowsRendererProvider::new(create_renderer=(window, metrics) => {
    create_renderer(window, metrics, options)
  })
}

///|
pub fn windows_sun_provider_preflight_summary(
  options? : WindowsSunAppOptions = WindowsSunAppOptions::new(),
  smoke_options? : WindowsSunSmokeOptions = WindowsSunSmokeOptions::new(),
) -> String {
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
  "Windows Sun provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; presenter=\{windows_sun_presenter_description()}; first_frame_smoke=\{first_frame}; \{sun_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=matching-host pending; unavailable=\"\{windows_sun_unavailable_message()}\""
}

///|
fn sun_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SunRasterRenderer.text_system; renderer_image_resources=none; renderer_async_image_loading=none; renderer_present_count=SunRasterRenderer.present_count; renderer_dispose=SunRasterRenderer.dispose"
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
      surface.resize(frame.width, frame.height)
      match
        surface.present_bytes(
          frame.width,
          frame.height,
          frame.row_bytes,
          frame.bytes,
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
    text_system=() => renderer.text_system(),
    image_resources=() => [],
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

///|
fn size_dim_to_int(value : Double) -> Int {
  if value != value || value <= 0.0 {
    0
  } else {
    value.ceil().to_int().max(1)
  }
}
