///|
extern "C" fn linux_surface_host_ptr_from_u64(
  handle : UInt64,
) -> @wgpu_c.OpaquePtr = "moui_linux_surface_host_ptr_from_u64"

///|
pub struct LinuxWgpuAppOptions {
  priv text_engine : @wgpu_renderer.NativeTextEngineSetting
  priv scene_resolver : @host.HostWindowSceneResolver
}

///|
pub fn LinuxWgpuAppOptions::new(
  text_engine? : @wgpu_renderer.NativeTextEngineSetting = @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
) -> LinuxWgpuAppOptions {
  { text_engine, scene_resolver }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=LinuxWgpuAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : LinuxWgpuAppOptions,
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
pub fn renderer_provider(
  options? : LinuxWgpuAppOptions = LinuxWgpuAppOptions::new(),
) -> @linux_host.LinuxRendererProvider {
  @linux_host.LinuxRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(wgpu_native_image_loader()),
  )
}

///|
fn wgpu_native_image_loader() -> @host.HostAsyncImageLoader {
  @host.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@wgpu_renderer.native_image_load_completion(source))
    None
  })
}

///|
fn create_linux_host_surface(
  display : UInt64,
  surface : UInt64,
) -> @wgpu_renderer.HostWgpuSurface raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let wgpu_surface = instance.create_surface_wayland(
    linux_surface_host_ptr_from_u64(display),
    linux_surface_host_ptr_from_u64(surface),
  )
  @wgpu_renderer.HostWgpuSurface::new(instance~, surface=wgpu_surface)
}

///|
fn create_renderer(
  window : @window_linux.Window,
  metrics : @host.HostSurfaceMetrics,
  options : LinuxWgpuAppOptions,
) -> @host.HostWindowRenderer? {
  Some(
    host_renderer_from_wgpu(
      @wgpu_renderer.create_with_host_surface_and_text_engine(
        renderer_metrics_from_host(metrics),
        create_linux_host_surface(window.wl_display(), window.wl_surface()),
        text_engine=linux_text_engine(options.text_engine),
      ),
    ),
  ) catch {
    err => {
      println("error creating Linux WGPU renderer: \{err.message()}")
      None
    }
  }
}

///|
fn linux_text_engine(
  setting : @wgpu_renderer.NativeTextEngineSetting,
) -> @wgpu_renderer.NativeTextEngine {
  match setting {
    @wgpu_renderer.NativeTextEngineSetting::MoonCosmic =>
      @wgpu_cosmic_text.cosmic_text_engine()
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault =>
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @wgpu_fontconfig.fontconfig_text_provider(),
        fallback=@wgpu_cosmic_text.cosmic_text_engine(),
      )
  }
}

///|
fn host_renderer_from_wgpu(
  renderer : @wgpu_renderer.WgpuRenderer,
) -> @host.HostWindowRenderer {
  @host.HostWindowRenderer::new(
    resize=metrics => renderer.resize(renderer_metrics_from_host(metrics)),
    render=commands => renderer.render(commands),
    text_system=() => renderer.text_system(),
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
    image=@host.HostRendererImageCapability::new(
      image_resources=() => renderer.image_resources(),
      image_resource_snapshot=Some(() => renderer.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        renderer.apply_image_resource_load_completion(completion)
      }),
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
