///|
pub struct MacosSunAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
}

///|
pub struct MacosSunSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn MacosSunAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
) -> MacosSunAppOptions {
  { scene_resolver, }
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
    ),
    window_requests~,
    frame_interval_ms~,
  )
}

///|
pub fn renderer_provider(
  options? : MacosSunAppOptions = MacosSunAppOptions::new(),
) -> @macos_host.MacosRendererProvider {
  ignore(options)
  @macos_host.MacosRendererProvider::new(create_renderer=(window, metrics) => {
    create_renderer(window, metrics, options)
  })
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
  let host_preflight = @macos_host.macos_capability_summary().preflight_fields()
  "macOS Sun provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; presenter=\{macos_sun_presenter_description()}; first_frame_smoke=\{first_frame}; \{sun_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=matching-host pending; unavailable=\"\{macos_sun_unavailable_message()}\""
}

///|
fn sun_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SunRasterRenderer.text_system; renderer_image_resources=SunRasterRenderer.image_resources; renderer_async_image_loading=sync; renderer_image_resource_apply=SunRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SunRasterRenderer.set_image_resource_change_callback; renderer_present_count=SunRasterRenderer.present_count; renderer_dispose=SunRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @window_macos.Window,
  metrics : @host.HostSurfaceMetrics,
  _options : MacosSunAppOptions,
) -> @host.HostWindowRenderer? {
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
      surface.resize(frame.width, frame.height)
      match
        surface.present_pixels(
          frame.width,
          frame.height,
          frame.row_bytes,
          frame.pixels,
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
) -> @host.HostWindowRenderer {
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
        err => println("error resizing macOS Sun renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering macOS Sun frame: \{err.message()}")
      }
    },
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
