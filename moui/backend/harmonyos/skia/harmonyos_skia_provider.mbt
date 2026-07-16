///|
#borrow(pixels)
extern "C" fn harmonyos_present_skia_pixels_to_surface(
  surface_handle : UInt64,
  width : Int,
  height : Int,
  row_bytes : Int,
  pixels : Bytes,
  pixels_len : Int,
) -> Int = "moui_harmonyos_present_skia_pixels_to_surface"

///|
pub struct HarmonyOsSkiaAppOptions {
  priv font_resolution : @skia_renderer.SkiaFontResolution
  priv surface_route : @render.SkiaSurfaceRoute
}

///|
pub fn HarmonyOsSkiaAppOptions::new(
  font_resolution? : @skia_renderer.SkiaFontResolution = @skia_renderer.SkiaFontResolution::SystemFontMgr,
  surface_route? : @render.SkiaSurfaceRoute = @render.SkiaSurfaceRoute::RasterSurfaceRoute,
) -> HarmonyOsSkiaAppOptions {
  { font_resolution, surface_route }
}

///|
pub fn renderer_provider(
  options? : HarmonyOsSkiaAppOptions = HarmonyOsSkiaAppOptions::new(),
) -> @harmonyos_host.HarmonyOsRendererProvider {
  @harmonyos_host.HarmonyOsRendererProvider::new(
    create_renderer=(surface, metrics) => {
      create_renderer(surface, metrics, options)
    },
    image_loader=Some(harmonyos_skia_async_image_loader()),
  )
}

///|
fn harmonyos_skia_async_image_loader() -> @host.HostAsyncImageLoader {
  @host.HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    complete(@skia_renderer.skia_image_load_completion(source))
    None
  })
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  options? : HarmonyOsSkiaAppOptions = HarmonyOsSkiaAppOptions::new(),
) -> @harmonyos_host.HarmonyOsRuntimeSession? {
  @harmonyos_host.create_session(
    runtime~,
    surface~,
    metrics~,
    provider=renderer_provider(options~),
  )
}

///|
pub fn harmonyos_skia_provider_preflight_summary(
  options? : HarmonyOsSkiaAppOptions = HarmonyOsSkiaAppOptions::new(),
) -> String {
  let info = @skia_renderer.backend_info()
  let render_status = if harmonyos_skia_provider_ready() {
    "available"
  } else {
    "unavailable"
  }
  let font_resolution = match options.font_resolution {
    @skia_renderer.SkiaFontResolution::SystemFontMgr => "system-font-mgr"
    @skia_renderer.SkiaFontResolution::EmptyTypeface => "empty-typeface"
  }
  let surface_route = options.surface_route.label()
  let gpu_runtime_available = @skia_native.Surface::egl_gpu_context_runtime_available()
  let host_preflight = @harmonyos_host.harmonyos_capability_summary().preflight_fields()
  "HarmonyOS Skia provider preflight: renderer=\{render_status}; can_render=\{info.can_render}; skia_available=\{@skia_renderer.skia_available()}; font=\{font_resolution}; surface_route=\{surface_route}; presenter=\{harmonyos_skia_presenter_description()}; gpu_presenter=\{harmonyos_skia_gpu_presenter_description()}; gpu_runtime_available=\{gpu_runtime_available}; \{skia_host_renderer_bridge_preflight()}; \{host_preflight}; runtime=harmonyos-device-smoke-required; runtime_status=runtime_partial; unavailable=\"\{harmonyos_skia_unavailable_message()}\""
}

///|
fn skia_host_renderer_bridge_preflight() -> String {
  "renderer_bridge=HostWindowRenderer; renderer_frame=SkiaRasterRenderer.render_frame; renderer_text_system=SkiaRasterRenderer.text_system; renderer_image_resources=SkiaRasterRenderer.image_resources; renderer_image_resource_apply=SkiaRasterRenderer.apply_image_resource_load_completion; renderer_image_resource_change=SkiaRasterRenderer.set_image_resource_change_callback; renderer_present_count=SkiaRasterRenderer.present_count; renderer_dispose=SkiaRasterRenderer.dispose"
}

///|
fn create_renderer(
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : HarmonyOsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  if !harmonyos_skia_provider_ready() {
    println(harmonyos_skia_unavailable_message())
    return None
  }
  let native_window = surface.raw()
  // Prefer the main-thread HostGpuPresentTarget path on HarmonyOS. The async
  // GPU worker rewrote this route for picture-recorder promotion scaffolding,
  // but on HVD/XComponent it presents an empty/black surface even when
  // configure reports egl-gpu. Restore the proven direct EGL present path.
  match resolve_gpu_present_target(native_window, options) {
    Some(gpu_target) =>
      try {
        let renderer = @skia_renderer.create_with_present_target_and_route(
          renderer_metrics_from_host(metrics),
          harmonyos_skia_present_target(surface),
          surface_route=options.surface_route,
          gpu_target=Some(gpu_target),
          font_resolution=options.font_resolution,
          async_image_loading=true,
        )
        println(
          "HarmonyOS Skia renderer route diagnostics: \{renderer.surface_diagnostic_summary()}",
        )
        Some(host_renderer_from_skia(renderer, surface, metrics, options))
      } catch {
        err => {
          println(
            "error creating HarmonyOS Skia EGL GPU renderer, falling back to raster: \{err.message()}",
          )
          create_raster_renderer(surface, metrics, options)
        }
      }
    None => create_raster_renderer(surface, metrics, options)
  }
}

///|
/// Resolve the optional `HostGpuPresentTarget` for the HarmonyOS EGL
/// direct-present path. Returns `Some` when the user selected the EGL GPU
/// route AND the Skia build links Ganesh GL AND a valid OHNativeWindow is
/// available. Returns `None` to fall back to raster.
fn resolve_gpu_present_target(
  native_window : UInt64,
  options : HarmonyOsSkiaAppOptions,
) -> @skia_renderer.HostGpuPresentTarget? {
  if !options.surface_route.is_gpu() {
    return None
  }
  if native_window == 0UL {
    println(
      "HarmonyOS Skia EGL GPU route requested but OHNativeWindow is unavailable; falling back to raster",
    )
    return None
  }
  let gpu_available = @skia_native.Surface::egl_gpu_context_runtime_available()
  if !gpu_available {
    println(
      "HarmonyOS Skia EGL GPU route requested but Ganesh GL runtime is unavailable; falling back to raster",
    )
    return None
  }
  Some(harmonyos_skia_gpu_present_target(native_window))
}

///|
fn create_raster_renderer(
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : HarmonyOsSkiaAppOptions,
) -> @host.HostWindowRenderer? {
  match create_raster_skia_renderer(surface, metrics, options) {
    None => None
    Some(renderer) =>
      Some(host_renderer_from_skia(renderer, surface, metrics, options))
  }
}

///|
fn create_raster_skia_renderer(
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : HarmonyOsSkiaAppOptions,
) -> @skia_renderer.SkiaRasterRenderer? {
  Some(
    @skia_renderer.create_with_present_target_and_route(
      renderer_metrics_from_host(metrics),
      harmonyos_skia_present_target(surface),
      surface_route=@render.SkiaSurfaceRoute::RasterSurfaceRoute,
      font_resolution=options.font_resolution,
      async_image_loading=true,
    ),
  ) catch {
    err => {
      println("error creating HarmonyOS Skia renderer: \{err.message()}")
      None
    }
  }
}

///|
fn harmonyos_skia_provider_ready() -> Bool {
  @skia_renderer.backend_info().can_render
}

///|
pub fn harmonyos_skia_gpu_available() -> Bool {
  @skia_native.Surface::egl_gpu_context_runtime_available()
}

///|
fn harmonyos_skia_unavailable_message() -> String {
  "HarmonyOS Skia renderer selected, but moui_skia/native is unavailable; configure MOUI_SKIA_PLATFORM=harmonyos, MOUI_SKIA_ARCH=arm64, MOUI_SKIA_LINK_MODE=dynamic, and HarmonyOS native link flags before selecting HarmonyOS Skia"
}

///|
fn harmonyos_skia_presenter_description() -> String {
  "HarmonyOS XComponent native window RGBA8888 Skia pixel presenter"
}

///|
fn harmonyos_skia_gpu_presenter_description() -> String {
  "HarmonyOS EGL Skia direct GPU presenter"
}

///|
/// Build the `HostGpuPresentTarget` for the HarmonyOS EGL direct-present
/// path. `native_window` is the raw `OHNativeWindow*` handle obtained from
/// the XComponent and retained by the HarmonyOS host surface.
/// `create_window_surface` is invoked at renderer creation and on resize;
/// `present_gpu` is invoked per-frame after `flush_and_submit` to swap the
/// EGL surface and re-wrap the new back buffer as a fresh Skia `Surface`.
fn harmonyos_skia_gpu_present_target(
  native_window : UInt64,
) -> @skia_renderer.HostGpuPresentTarget {
  @skia_renderer.HostGpuPresentTarget::new(
    description=harmonyos_skia_gpu_presenter_description(),
    create_window_surface=(gpu_context, metrics) => {
      match gpu_context {
        None => None
        Some(context) =>
          @skia_native.Surface::egl_window_surface(
            context,
            native_window,
            harmonyos_skia_egl_surface_descriptor(metrics),
          )
      }
    },
    present_gpu=(gpu_context, surface) => {
      match gpu_context {
        None =>
          @skia_renderer.HostGpuPresentOutcome::new(
            succeeded=false,
            next_surface=None,
          )
        Some(context) => {
          let outcome = @skia_native.Surface::egl_present_and_acquire_next(
            surface, context, native_window,
          )
          match outcome {
            Some(next_surface) =>
              @skia_renderer.HostGpuPresentOutcome::new(
                succeeded=true,
                next_surface=Some(next_surface),
              )
            None =>
              @skia_renderer.HostGpuPresentOutcome::new(
                succeeded=false,
                next_surface=None,
              )
          }
        }
      }
    },
  )
}

///|
fn harmonyos_skia_egl_surface_descriptor(
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
fn harmonyos_skia_present_target(
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
) -> @skia_renderer.SkiaPresentTarget {
  @skia_renderer.SkiaPresentTarget::new(
    description=harmonyos_skia_presenter_description(),
    present=frame => {
      let pixels = frame.pixels()
      harmonyos_present_skia_pixels_to_surface(
        surface.raw(),
        frame.width(),
        frame.height(),
        frame.row_bytes(),
        pixels,
        pixels.length(),
      ) !=
      0
    },
  )
}

///|
fn host_renderer_from_skia(
  renderer : @skia_renderer.SkiaRasterRenderer,
  surface : @harmonyos_host.HarmonyOsSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
  options : HarmonyOsSkiaAppOptions,
) -> @host.HostWindowRenderer {
  // Sticky raster fallback only after HostGpu present/surface failures — not
  // incomplete draws — so a transient layer miss cannot permanently demote GPU.
  let fallback_to_raster = Ref(false)
  let active = Ref(renderer)
  let last_metrics = Ref(metrics)
  let host_gpu_present_failure = (
    diagnostics : Array[@skia_renderer.SkiaUnsupportedCommandDiagnostic],
  ) => {
    for diagnostic in diagnostics {
      let reason = diagnostic.reason()
      // SkiaRendererError::message() shapes from renderer.mbt.
      if reason.has_prefix("Skia presenter failed:") ||
        reason == "failed to create Skia surface" ||
        reason.has_prefix("failed to create Skia GPU context:") {
        return true
      }
    }
    false
  }
  let try_fallback = (metrics, reason) => {
    if fallback_to_raster.val {
      return
    }
    match create_raster_skia_renderer(surface, metrics, options) {
      None => ()
      Some(raster_renderer) => {
        println(
          "HarmonyOS Skia HostGpu present failed (\{reason}); sticky fallback to raster pixel presenter",
        )
        fallback_to_raster.val = true
        let previous = active.val
        // Drop EGL window ownership before raster reuses the same OHNativeWindow.
        previous.dispose()
        active.val = raster_renderer
      }
    }
  }
  @host.HostWindowRenderer::new(
    resize=metrics => {
      last_metrics.val = metrics
      active.val.resize(renderer_metrics_from_host(metrics)) catch {
        err => {
          println("error resizing HarmonyOS Skia renderer: \{err.message()}")
          if active.val.target_kind()
            is @skia_renderer.SkiaPresentKind::HostGpuSurface {
            try_fallback(metrics, err.message())
            if fallback_to_raster.val {
              active.val.resize(renderer_metrics_from_host(metrics)) catch {
                resize_err =>
                  println(
                    "error resizing HarmonyOS raster fallback: \{resize_err.message()}",
                  )
              }
            }
          }
        }
      }
    },
    render=commands => {
      active.val.render(commands) catch {
        err => println("error rendering HarmonyOS Skia frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => {
      let result = active.val.render_frame(frame)
      if !result.presented &&
        !fallback_to_raster.val &&
        active.val.target_kind()
        is @skia_renderer.SkiaPresentKind::HostGpuSurface &&
        host_gpu_present_failure(active.val.unsupported_command_diagnostics()) {
        try_fallback(last_metrics.val, "present-or-surface-unavailable")
        if fallback_to_raster.val {
          return active.val.render_frame(frame)
        }
      }
      result
    }),
    text_system=() => active.val.text_system(),
    present_count=() => active.val.present_count(),
    dispose=() => active.val.dispose(),
    image=@host.HostRendererImageCapability::new(
      image_resources=() => active.val.image_resources(),
      image_resource_snapshot=Some(() => active.val.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        active.val.apply_image_resource_load_completion(completion)
      }),
      set_image_resource_change_callback=callback => {
        active.val.set_image_resource_change_callback(callback)
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
        active.val.draw_platform_view_pixels(
          pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
        )
      },
      set_platform_view_draw_fn=draw_fn => {
        active.val.set_platform_view_draw_fn(draw_fn)
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
