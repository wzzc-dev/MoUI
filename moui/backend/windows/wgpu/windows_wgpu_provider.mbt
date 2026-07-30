///|
extern "C" fn win32_surface_host_hinstance() -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hinstance"

///|
extern "C" fn win32_surface_host_hwnd_from_u64(
  hwnd : UInt64,
) -> @wgpu_c.OpaquePtr = "moui_windows_surface_host_hwnd_from_u64"

///|
pub struct WindowsWgpuAppOptions {
  priv text_engine : @wgpu_renderer.NativeTextEngineSetting
  priv scene_resolver : @runtime.HostWindowSceneResolver
}

///|
pub fn WindowsWgpuAppOptions::new(
  text_engine? : @wgpu_renderer.NativeTextEngineSetting = @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
  scene_resolver? : @runtime.HostWindowSceneResolver = @runtime.HostWindowSceneResolver::unavailable(),
) -> WindowsWgpuAppOptions {
  { text_engine, scene_resolver }
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=WindowsWgpuAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : WindowsWgpuAppOptions,
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
pub fn renderer_provider(
  options? : WindowsWgpuAppOptions = WindowsWgpuAppOptions::new(),
) -> @windows_host.WindowsRendererProvider {
  @windows_host.WindowsRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(wgpu_native_image_loader()),
  )
}

///|
fn wgpu_native_image_loader() -> @render.HostAsyncImageLoader {
  @render.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@wgpu_renderer.native_image_load_completion(source))
    None
  })
}

///|
fn create_windows_host_surface(
  hwnd : UInt64,
) -> @wgpu_renderer.HostWgpuSurface raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let surface = instance.create_surface_windows_hwnd(
    win32_surface_host_hinstance(),
    win32_surface_host_hwnd_from_u64(hwnd),
  )
  @wgpu_renderer.HostWgpuSurface::new(instance~, surface~)
}

///|
fn create_renderer(
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
  options : WindowsWgpuAppOptions,
) -> @render.HostWindowRenderer? {
  Some(
    host_renderer_from_wgpu(
      @wgpu_renderer.create_with_host_surface_and_text_engine(
        renderer_metrics_from_host(metrics),
        create_windows_host_surface(window.native_window_handle()),
        text_engine=windows_text_engine(options.text_engine),
      ),
    ),
  ) catch {
    err => {
      println("error creating Windows WGPU renderer: \{err.message()}")
      None
    }
  }
}

///|
fn windows_text_engine(
  setting : @wgpu_renderer.NativeTextEngineSetting,
) -> @wgpu_renderer.NativeTextEngine {
  match setting {
    @wgpu_renderer.NativeTextEngineSetting::MoonCosmic =>
      @wgpu_cosmic_text.cosmic_text_engine()
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault =>
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @wgpu_directwrite.directwrite_text_provider(),
        fallback=@wgpu_cosmic_text.cosmic_text_engine(),
      )
  }
}

///|
fn host_renderer_from_wgpu(
  renderer : @wgpu_renderer.WgpuRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => renderer.resize(metrics),
    render=commands => renderer.render(commands),
    text_system=() => renderer.text_system(),
    present_count=() => renderer.present_count(),
    dispose=() => renderer.dispose(),
    image=@render.HostRendererImageCapability::new(
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
