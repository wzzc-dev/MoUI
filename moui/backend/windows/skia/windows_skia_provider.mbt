///|
#borrow(pixels)
extern "C" fn windows_present_skia_pixels_to_hwnd(
  hwnd : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_windows_present_skia_pixels_to_hwnd"

///|
pub struct WindowsSkiaAppOptions {
  priv scene_resolver : @host.HostWindowSceneResolver
  priv event_sources : @host.HostPlatformEventSources?
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv surface_route : @render.SkiaSurfaceRoute
  priv platform_view_plugins : Array[@host.PlatformViewPlugin]
}

///|
pub struct WindowsSkiaSmokeOptions {
  priv first_frame_smoke_auto_exit : Bool
}

///|
pub fn WindowsSkiaAppOptions::new(
  scene_resolver? : @host.HostWindowSceneResolver = @host.HostWindowSceneResolver::unavailable(),
  event_sources? : @host.HostPlatformEventSources? = None,
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @render.SkiaSurfaceRoute = windows_surface_route_from_environment(),
  platform_view_plugins? : Array[@host.PlatformViewPlugin] = [],
) -> WindowsSkiaAppOptions {
  {
    scene_resolver,
    event_sources,
    font_resolution,
    surface_route,
    platform_view_plugins,
  }
}

///|
fn windows_surface_route_from_environment() -> @render.SkiaSurfaceRoute {
  let requested = match @env.get_env_var("MOUI_SKIA_RENDERER") {
    Some(value) =>
      @render.NativeRendererMode::parse(value).unwrap_or(
        @render.NativeRendererMode::Auto,
      )
    None => @render.NativeRendererMode::Auto
  }
  @render.select_native_renderer(
    @render.NativeGpuPlatform::Windows,
    requested,
    gpu_available=@skia_native.Surface::direct3d_gpu_context_runtime_available(),
    gpu_promoted=@render.NativeGpuPlatform::Windows.gpu_promoted(),
  ).surface_route
}

///|
pub fn WindowsSkiaSmokeOptions::new(
  first_frame_smoke_auto_exit? : Bool = false,
) -> WindowsSkiaSmokeOptions {
  { first_frame_smoke_auto_exit, }
}

///|
fn WindowsSkiaSmokeOptions::from_environment() -> WindowsSkiaSmokeOptions {
  WindowsSkiaSmokeOptions::new(
    first_frame_smoke_auto_exit=env_flag(
        "MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT",
      ) ||
      env_flag("MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT"),
  )
}

///|
fn WindowsSkiaSmokeOptions::enabled(self : WindowsSkiaSmokeOptions) -> Bool {
  self.first_frame_smoke_auto_exit
}

///|
fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
}

///|
pub fn run_app(title : String, runtime : @runtime.AppRuntime) -> Unit {
  run_app_with_options(
    title,
    runtime,
    options=WindowsSkiaAppOptions::new(),
    window_requests=@host.HostWindowRequestQueue::new(),
  )
}

///|
pub fn run_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : WindowsSkiaAppOptions,
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  let smoke_options = WindowsSkiaSmokeOptions::from_environment()
  if smoke_options.enabled() {
    run_smoke_app_with_options(
      title,
      runtime,
      options~,
      smoke_options~,
      window_requests~,
    )
    return
  }
  if !windows_skia_provider_ready() {
    println(windows_skia_unavailable_message())
    return
  }
  @windows_host.run_app_with_renderer_provider(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@windows_host.WindowsHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      event_sources=options.event_sources,
      platform_view_plugins=options.platform_view_plugins,
    ),
    window_requests~,
  )
}

///|
pub fn run_smoke_app_with_options(
  title : String,
  runtime : @runtime.AppRuntime,
  options~ : WindowsSkiaAppOptions,
  smoke_options? : WindowsSkiaSmokeOptions = WindowsSkiaSmokeOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit {
  if !windows_skia_provider_ready() {
    println(windows_skia_unavailable_message())
    return
  }
  @windows_host.run_app_with_renderer_provider_smoke(
    title,
    runtime,
    provider=renderer_provider(options~),
    options=@windows_host.WindowsHostAppOptions::new(
      scene_resolver=options.scene_resolver,
      event_sources=options.event_sources,
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
  options? : WindowsSkiaAppOptions = WindowsSkiaAppOptions::new(),
) -> @windows_host.WindowsRendererProvider {
  @windows_host.WindowsRendererProvider::new(
    create_renderer=(window, metrics) => {
      create_renderer(window, metrics, options)
    },
    image_loader=Some(skia_async_image_loader()),
  )
}

///|
#borrow(source_bytes)
extern "C" fn moui_windows_async_image_spawn(
  window_id : Int64,
  source_bytes : Bytes,
  source_len : Int,
) -> Unit = "moui_windows_async_image_spawn"

///|
extern "C" fn moui_windows_async_image_take_result() -> Bytes = "moui_windows_async_image_take_result"

///|
fn async_image_read_i32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn skia_async_image_loader() -> @host.HostAsyncImageLoader {
  let native_source = @host.HostNativeAsyncImageSource::new()
  @host.HostNativeAsyncImageSource::loader_with_drain(
    native_source,
    spawn=(window_id, source) => {
      if source.has_prefix("data:") {
        let completion = @skia_renderer.skia_image_load_completion(source)
        ignore(native_source.complete(window_id, completion))
      } else {
        let source_bytes = @utf8.encode(source[:], bom=false)
        moui_windows_async_image_spawn(
          window_id.value.to_int64(),
          source_bytes,
          source_bytes.length(),
        )
      }
    },
    drain=() => {
      while true {
        let result = moui_windows_async_image_take_result()
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
        let decoded_width = async_image_read_i32_le(result, 24)
        let decoded_height = async_image_read_i32_le(result, 28)
        let decoded_row_bytes = async_image_read_i32_le(result, 32)
        let background_decode_raw = async_image_read_i32_le(result, 36)
        let background_io = background_io_raw != 0
        let background_decode = background_decode_raw != 0
        let header = 40
        let source = @utf8.decode_lossy(
          result[header:header + source_len],
          ignore_bom=false,
        )
        let completion = if status == 0 && bytes_len > 0 {
          let pixels = result[header + source_len:header +
          source_len +
          bytes_len].to_owned()
          @render.ImageResourceLoadCompletion::ready_decoded_rgba(
            source,
            width=decoded_width,
            height=decoded_height,
            row_bytes=decoded_row_bytes,
            pixels,
            background_io~,
            background_decode~,
          )
        } else {
          @render.ImageResourceLoadCompletion::failed(
            source,
            diagnostic="Async image decode failed",
            background_io~,
          )
        }
        ignore(native_source.complete(window_id, completion))
      }
    },
  )
}

///|
pub fn windows_skia_provider_preflight_summary(
  options? : WindowsSkiaAppOptions = WindowsSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if windows_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let surface_route = options.surface_route.label()
  let host_preflight = @windows_host.windows_capability_summary().preflight_fields()
  let gpu_runtime_available = @skia_native.Surface::direct3d_gpu_context_runtime_available()
  "Windows Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; surface_route=\{surface_route}; presenter=\{windows_skia_presenter_description()}; gpu_presenter=\{windows_skia_gpu_presenter_description()}; gpu_runtime_available=\{gpu_runtime_available}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=smoke log required; unavailable=\"\{windows_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_loader=skia_async_image_loader; renderer_async_image_loading=off-main-io; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  window : @win.Window,
  metrics : @host.HostSurfaceMetrics,
  options : WindowsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !windows_skia_provider_ready() {
    println(windows_skia_unavailable_message())
    return None
  }
  let hwnd = window.window_handle()
  if options.surface_route.is_gpu() &&
    hwnd != 0UL &&
    @skia_native.Surface::direct3d_gpu_context_runtime_available() {
    create_gpu_worker_renderer(hwnd, metrics, options)
  } else {
    create_raster_renderer(hwnd, metrics, options)
  }
}

///|
fn create_gpu_worker_renderer(
  hwnd : UInt64,
  metrics : @host.HostSurfaceMetrics,
  options : WindowsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  try {
    let renderer = @skia_renderer.create_with_present_target(
      renderer_metrics_from_host(metrics),
      windows_skia_present_target(hwnd),
      font_resolution=options.font_resolution,
      async_image_loading=true,
    )
    match @skia_native.NativeGpuRenderWorker::new() {
      None => create_raster_renderer(hwnd, metrics, options)
      Some(worker) => {
        let dimensions = windows_skia_d3d_surface_descriptor(
          renderer_metrics_from_host(metrics),
        ).dimensions()
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Attach(hwnd),
          ),
        )
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Resize(
              dimensions.width,
              dimensions.height,
            ),
          ),
        )
        ignore(worker.wait_completion(timeout_ms=1000))
        ignore(worker.drain_completions())
        println(
          "Windows Skia renderer route diagnostics: surface_route=d3d12-gpu; surface_gpu=true; gpu_context=worker-owned; present_kind=host-gpu-surface; dimensions=\{dimensions.width}x\{dimensions.height}",
        )
        Some(host_renderer_from_native_gpu_worker(renderer, worker))
      }
    }
  } catch {
    err => {
      println(
        "error creating Windows Skia D3D12 worker renderer, falling back to raster: \{err.message()}",
      )
      create_raster_renderer(hwnd, metrics, options)
    }
  }
}

///|
fn create_raster_renderer(
  hwnd : UInt64,
  metrics : @host.HostSurfaceMetrics,
  options : WindowsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  try {
    let renderer = @skia_renderer.create_with_present_target_and_route(
      renderer_metrics_from_host(metrics),
      windows_skia_present_target(hwnd),
      surface_route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
      font_resolution=options.font_resolution,
      async_image_loading=true,
    )
    Some(host_renderer_from_skia(renderer))
  } catch {
    err => {
      println("error creating Windows Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn windows_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
fn windows_skia_unavailable_message() -> String {
  "Windows Skia renderer selected, but moui_skia/native is unavailable; configure real Skia link flags before selecting SkiaRasterNative"
}

///|
fn windows_skia_presenter_description() -> String {
  "Windows GDI Skia pixel presenter"
}

///|
fn windows_skia_present_target(
  hwnd : UInt64,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=windows_skia_presenter_description(),
    present=frame => {
      let pixels = frame.pixels()
      windows_present_skia_pixels_to_hwnd(
        hwnd,
        frame.width(),
        frame.height(),
        frame.row_bytes(),
        pixels,
        pixels.length(),
      ) ==
      0
    },
  )
}

///|
fn windows_skia_gpu_presenter_description() -> String {
  "Windows D3D12 Skia direct GPU presenter"
}

///|
fn windows_skia_d3d_surface_descriptor(
  metrics : @render.RendererSurfaceMetrics,
) -> @moui_skia.SurfaceDescriptor {
  let physical = metrics.physical_size
  @moui_skia.SurfaceDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(
      physical.width.ceil().max(1.0).to_int(),
      physical.height.ceil().max(1.0).to_int(),
    ),
  )
}

///|
fn windows_native_gpu_completion_to_render(
  completion : @skia_native.NativeGpuWorkerCompletion,
) -> @render.RenderPresentCompletion? {
  let status = match completion.status {
    @skia_native.NativeGpuWorkerCompletionStatus::PictureRecorded =>
      @render.RenderPresentStatus::Recorded
    @skia_native.NativeGpuWorkerCompletionStatus::Presented =>
      @render.RenderPresentStatus::Presented
    @skia_native.NativeGpuWorkerCompletionStatus::Dropped =>
      @render.RenderPresentStatus::Dropped
    @skia_native.NativeGpuWorkerCompletionStatus::FallbackToRaster =>
      @render.RenderPresentStatus::FallbackToRaster
    @skia_native.NativeGpuWorkerCompletionStatus::ControlAcknowledged
    | @skia_native.NativeGpuWorkerCompletionStatus::Unknown(_) => return None
  }
  Some(
    @render.RenderPresentCompletion::new(
      frame_sequence=completion.sequence.to_int(),
      surface_generation=completion.surface_generation,
      image_resource_revision=completion.image_resource_revision,
      submitted_at_ms=completion.submitted_at_ms,
      completed_at_ms=completion.processed_at_ms,
      presented_at_ms=completion.presented_at_ms,
      status~,
      gpu_context_generation=completion.context_generation,
    ),
  )
}

///|
fn host_renderer_from_native_gpu_worker(
  renderer : @skia_renderer.SkiaRasterRenderer,
  worker : @skia_native.NativeGpuRenderWorker,
) -> @host.HostWindowRenderer {
  let pending_completions : Array[@render.RenderPresentCompletion] = []
  let presented_count = Ref(0)
  let fallback_to_raster = Ref(false)
  let disposed = Ref(false)
  let collect_completions = () => {
    for completion in worker.drain_completions() {
      match windows_native_gpu_completion_to_render(completion) {
        Some(render_completion) => {
          match render_completion.status() {
            @render.RenderPresentStatus::Presented =>
              presented_count.val = presented_count.val + 1
            @render.RenderPresentStatus::FallbackToRaster =>
              fallback_to_raster.val = true
            _ => ()
          }
          pending_completions.push(render_completion)
        }
        None => ()
      }
    }
  }
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
        err => println("error resizing Windows Skia producer: \{err.message()}")
      }
      if !fallback_to_raster.val {
        let dimensions = windows_skia_d3d_surface_descriptor(
          renderer_metrics_from_host(metrics),
        ).dimensions()
        ignore(
          worker.submit_control(
            @skia_native.GpuRenderWorkerControl::Resize(
              dimensions.width,
              dimensions.height,
            ),
          ),
        )
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Windows Skia frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => {
      collect_completions()
      if fallback_to_raster.val {
        return renderer.render_frame(frame)
      }
      match renderer.record_frame_picture(frame) {
        None => renderer.render_frame(frame)
        Some(picture) => {
          let revision = renderer.image_resource_snapshot().revision.to_int64()
          let sequence = worker.submit_picture(
            picture,
            image_resource_revision=revision,
          )
          if sequence == 0L {
            fallback_to_raster.val = true
            renderer.render_frame(frame)
          } else {
            @render.RenderFrameResult::new(presented=false, queued=true)
          }
        }
      }
    }),
    drain_present_completions=Some(() => {
      collect_completions()
      let completions = pending_completions.copy()
      pending_completions.clear()
      completions
    }),
    text_system=() => renderer.text_system(),
    present_count=() => presented_count.val + renderer.present_count(),
    dispose=() => {
      if !disposed.val {
        disposed.val = true
        ignore(
          worker.submit_control(@skia_native.GpuRenderWorkerControl::Detach),
        )
        ignore(worker.wait_completion(timeout_ms=1000))
        ignore(worker.drain_completions())
        worker.shutdown()
        renderer.dispose()
      }
    },
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
  )
}

///|
fn host_renderer_from_skia(
  renderer : @skia_renderer.SkiaRasterRenderer,
) -> @host.HostWindowRenderer {
  @host.HostWindowRenderer::new(
    resize=metrics => {
      renderer.resize(renderer_metrics_from_host(metrics)) catch {
        err => println("error resizing Windows Skia renderer: \{err.message()}")
      }
    },
    render=commands => {
      renderer.render(commands) catch {
        err => println("error rendering Windows Skia frame: \{err.message()}")
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
