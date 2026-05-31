///|
pub struct LinuxSkiaAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv font_resolution : @skia_renderer.SkiaFontResolution
}

///|
pub fn LinuxSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
) -> LinuxSkiaAppOptions {
  { scene_resolver, font_resolution }
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
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : LinuxSkiaAppOptions = LinuxSkiaAppOptions::new(),
) -> @linux_host.LinuxRendererProvider {
  @linux_host.LinuxRendererProvider::new(create_renderer=(window, metrics) => {
    create_renderer(window, metrics, options)
  })
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
  "Linux Skia renderer selected, but skia_mbt/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
}

///|
fn linux_skia_present_target(
  window : @window_linux.Window,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description="Linux Wayland wl_shm Skia pixel presenter",
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
