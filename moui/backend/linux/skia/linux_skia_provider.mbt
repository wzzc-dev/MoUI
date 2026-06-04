///|
pub struct LinuxSkiaAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv exit_after_first_present : Bool
}

///|
pub fn LinuxSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  exit_after_first_present? : Bool = false,
) -> LinuxSkiaAppOptions {
  { scene_resolver, font_resolution, exit_after_first_present }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
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
  runtime : @core.AppRuntime,
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
      exit_after_first_present=options.exit_after_first_present,
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
pub fn linux_skia_provider_preflight_summary(
  options? : LinuxSkiaAppOptions = LinuxSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if linux_skia_provider_ready() {
    "ready"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let first_frame = if options.exit_after_first_present {
    "enabled"
  } else {
    "disabled"
  }
  let host_preflight = @linux_host.linux_capability_summary().preflight_fields()
  "Linux Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; presenter=\{linux_skia_presenter_description()}; first_frame_smoke=\{first_frame}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=matching-host pending; unavailable=\"\{linux_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_image_load_completion; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
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
