///|
pub struct LinuxSunAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
}

///|
pub struct LinuxSunSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn LinuxSunAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
) -> LinuxSunAppOptions {
  { scene_resolver, }
}

///|
pub fn LinuxSunSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> LinuxSunSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=LinuxSunAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : LinuxSunAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @linux_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@linux_host.LinuxHostAppOptions::new(
      scene_resolver=options.scene_resolver,
    ),
    window_requests~,
  )
}

///|
pub fn run_smoke_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : LinuxSunAppOptions,
  smoke_options? : LinuxSunSmokeOptions = LinuxSunSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @linux_host.run_app_with_renderer_provider_smoke(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@linux_host.LinuxHostAppOptions::new(
      scene_resolver=options.scene_resolver,
    ),
    smoke_options=@linux_host.LinuxHostSmokeOptions::new(
      first_frame_smoke_auto_exit=smoke_options.first_frame_smoke_auto_exit,
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : LinuxSunAppOptions = LinuxSunAppOptions::new(),
) -> @linux_host.LinuxRendererProvider {
  ignore(options)
  @linux_host.LinuxRendererProvider::new(create_renderer=(window, metrics) => {
    create_renderer(window, metrics, options)
  })
}

///|
pub fn linux_sun_provider_preflight_summary(
  options? : LinuxSunAppOptions = LinuxSunAppOptions::new(),
  smoke_options? : LinuxSunSmokeOptions = LinuxSunSmokeOptions::new(),
) -> String {
  ignore(options)
  let info = @sun_renderer.backend_info()
  let render_status = if linux_sun_provider_ready() {
    "experimental-ready"
  } else {
    "unavailable"
  }
  let first_frame = if smoke_options.first_frame_smoke_auto_exit {
    "enabled"
  } else {
    "disabled"
  }
  let host_preflight = @linux_host.linux_capability_summary().preflight_fields()
  "Linux Sun provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; presenter=\{linux_sun_presenter_description()}; first_frame_smoke=\{first_frame}; \{sun_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=matching-host pending; unavailable=\"\{linux_sun_unavailable_message()}\""
}

///|
fn sun_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SunRasterRenderer.text_system; renderer_image_resources=SunRasterRenderer.image_resources; renderer_async_image_loading=sync; renderer_image_resource_apply=SunRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SunRasterRenderer.set_image_resource_change_callback; renderer_present_count=SunRasterRenderer.present_count; renderer_dispose=SunRasterRenderer.dispose; linux_presenter=window_linux.present_rgba_pixels"
}

///|
fn create_renderer(
  window : @window_linux.Window,
  metrics : @host.HostSurfaceMetrics,
  _options : LinuxSunAppOptions,
) -> @host.HostWindowRenderer? {
  if !linux_sun_provider_ready() {
    println(linux_sun_unavailable_message())
    return None
  }
  Some(
    host_renderer_from_sun(
      @sun_renderer.create_with_present_target(
        renderer_metrics_from_host(metrics),
        linux_sun_present_target(window),
      ),
    ),
  ) catch {
    err => {
      println("error creating Linux Sun renderer: \{err.message()}")
      None
    }
  }
}

///|
fn linux_sun_provider_ready() -> Bool {
  @sun_renderer.backend_info().can_render
}

///|
fn linux_sun_unavailable_message() -> String {
  "Linux Sun renderer selected, but moui_sun/native is unavailable"
}

///|
fn linux_sun_presenter_description() -> String {
  "Linux Wayland wl_shm Sun pixel presenter"
}

///|
fn linux_sun_present_target(
  window : @window_linux.Window,
) -> @sun_renderer.SunPresentTarget {
  @sun_renderer.SunPresentTarget::new(
    description=linux_sun_presenter_description(),
    present=frame => {
      window.present_rgba_pixels(
        frame.width,
        frame.height,
        frame.row_bytes,
        frame.bytes,
      ) ==
      0
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
        err => println("error resizing Linux Sun renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Linux Sun frame: \{err.message()}")
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
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size=metrics.physical_size,
    scale_factor=metrics.scale_factor,
  )
}
