///|
extern "C" fn macos_surface_host_layer_from_view(
  raw_content_view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @wgpu_c.OpaquePtr = "moui_macos_surface_host_layer_from_view"

///|
pub struct MacosWgpuAppOptions {
  priv text_engine : @wgpu_renderer.NativeTextEngineSetting
  priv scene_resolver : @host.HostWindowSceneResolver
  priv exit_after_first_present : Bool
}

///|
pub fn MacosWgpuAppOptions::new(
  text_engine? : @wgpu_renderer.NativeTextEngineSetting = @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  exit_after_first_present? : Bool = false,
) -> MacosWgpuAppOptions {
  { text_engine, scene_resolver, exit_after_first_present }
}

///|
pub fn run_app(title : String, runtime : @core.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=MacosWgpuAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @core.AppRuntime,
  options~ : MacosWgpuAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  @macos_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@macos_host.MacosHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      exit_after_first_present=options.exit_after_first_present,
    ),
    window_requests~,
  )
}

///|
pub fn renderer_provider(
  options? : MacosWgpuAppOptions = MacosWgpuAppOptions::new(),
) -> @macos_host.MacosRendererProvider {
  @macos_host.MacosRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    sync_surface~,
  )
}

///|
fn create_macos_host_surface_from_layer(
  layer : @wgpu_c.OpaquePtr,
) -> @wgpu_renderer.HostWgpuSurface raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let desc = @wgpu_mbt.surface_descriptor_metal_layer_new(layer)
  let surface = instance.create_surface(desc)
  @wgpu_mbt.surface_descriptor_free(desc)
  @wgpu_renderer.HostWgpuSurface::new(instance~, surface~)
}

///|
fn create_renderer(
  window : @window_macos.Window,
  metrics : @host.HostSurfaceMetrics,
  options : MacosWgpuAppOptions,
) -> @host.HostWindowRenderer? {
  match
    content_view_handle(window, "error resolving macOS content view handle") {
    Some(raw_content_view_handle) =>
      match
        macos_surface_host_layer_from_content_view(
          raw_content_view_handle,
          metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ) {
        Some(layer) =>
          Some(
            host_renderer_from_wgpu(
              @wgpu_renderer.create_with_host_surface_and_text_engine(
                renderer_metrics_from_host(metrics),
                create_macos_host_surface_from_layer(layer),
                text_engine=macos_text_engine(options.text_engine),
              ),
            ),
          ) catch {
            err => {
              println("error creating macOS WGPU renderer: \{err.message()}")
              None
            }
          }
        None => {
          println("macOS CAMetalLayer bridge returned a null layer")
          None
        }
      }
    None => None
  }
}

///|
fn sync_surface(
  window : @window_macos.Window,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  match
    content_view_handle(window, "error resolving macOS content view handle") {
    Some(raw_content_view_handle) =>
      ignore(
        sync_macos_host_surface(
          raw_content_view_handle,
          metrics.physical_size,
          scale_factor=metrics.scale_factor,
        ),
      )
    None => ()
  }
}

///|
fn sync_macos_host_surface(
  raw_content_view_handle : UInt64,
  size : @core.Size,
  scale_factor? : Double = 1.0,
) -> Bool {
  match
    macos_surface_host_layer_from_content_view(
      raw_content_view_handle,
      size,
      scale_factor~,
    ) {
    Some(_) => true
    None => {
      println("macOS CAMetalLayer bridge returned a null layer")
      false
    }
  }
}

///|
fn macos_surface_host_layer_from_content_view(
  raw_content_view_handle : UInt64,
  size : @core.Size,
  scale_factor~ : Double,
) -> @wgpu_c.OpaquePtr? {
  let layer = macos_surface_host_layer_from_view(
    raw_content_view_handle,
    size_dim_to_int(size.width),
    size_dim_to_int(size.height),
    scale_factor,
  )
  if @wgpu_c.opaque_ptr_is_null(layer) {
    None
  } else {
    Some(layer)
  }
}

///|
fn content_view_handle(
  window : @window_macos.Window,
  message : String,
) -> UInt64? {
  Some(window.content_view_handle()) catch {
    err => {
      println("\{message}: \{err}")
      None
    }
  }
}

///|
fn macos_text_engine(
  setting : @wgpu_renderer.NativeTextEngineSetting,
) -> @wgpu_renderer.NativeTextEngine {
  match setting {
    @wgpu_renderer.NativeTextEngineSetting::MoonCosmic =>
      @wgpu_cosmic_text.cosmic_text_engine()
    @wgpu_renderer.NativeTextEngineSetting::PlatformDefault =>
      @wgpu_renderer.native_platform_text_engine_with_fallback(
        @wgpu_coretext.coretext_text_provider(),
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

///|
fn size_dim_to_int(value : Double) -> Int {
  if value < 1.0 {
    1
  } else {
    value.to_int()
  }
}
