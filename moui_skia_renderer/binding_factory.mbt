///|
/// Build a Skia CPU raster provider from the renderer-neutral host contract.
pub fn raster(
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @render.RendererProvider {
  let image_decoder = skia_image_decoder()
  let caps = skia_provider_capabilities(
    provider_id="skia-raster",
    backend=@render.RendererBackendKind::SkiaRasterNative,
  )
  @render.RendererProvider::new(
    id="skia-raster",
    descriptor=skia_raster_native_descriptor(),
    capabilities=() => caps,
    bind=surface => {
      match @render_common.host_surface_metrics_error(surface) {
        Some(message) => return @render.RendererBindResult::Rejected(message)
        None => ()
      }
      guard surface.cpu_present() is Some(host) else {
        return @render.RendererBindResult::Rejected(
          "skia-raster requires a CPU presenter",
        )
      }
      let target = skia_present_target_from_host(Some(host))
      let renderer = create_with_present_target(
        surface.metrics(),
        target,
        font_resolution~,
        async_image_loading=true,
      ) catch {
        err =>
          return @render.RendererBindResult::Rejected(
            "skia-raster unavailable: " + err.message(),
          )
      }
      @render.RendererBindResult::Bound(
        renderer.to_renderer_session(
          image_source=surface
            .image_source()
            .unwrap_or(@render.HostImageSource::unavailable()),
          image_decoder=Some(image_decoder),
        ),
      )
    },
  )
}

///|
/// Build a Skia direct GPU provider. The platform policy belongs to this
/// renderer module and interprets the opaque native handles after binding.
pub fn gpu(
  platform~ : NativeGpuPlatform,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @render.RendererProvider {
  let image_decoder = skia_image_decoder()
  let caps = skia_provider_capabilities(
    provider_id="skia-hybrid",
    backend=@render.RendererBackendKind::SkiaGpuNative,
  )
  @render.RendererProvider::new(
    id="skia-hybrid",
    descriptor=skia_gpu_native_descriptor(),
    capabilities=() => caps,
    bind=surface => {
      match @render_common.host_surface_metrics_error(surface) {
        Some(message) => return @render.RendererBindResult::Rejected(message)
        None => ()
      }
      guard surface.native_surface() is Some(native_surface) else {
        return @render.RendererBindResult::Rejected(
          "skia-hybrid requires a native surface capability",
        )
      }
      match skia_native_surface_error(platform, native_surface) {
        Some(message) => return @render.RendererBindResult::Rejected(message)
        None => ()
      }
      if !skia_gpu_runtime_available(platform) {
        return @render.RendererBindResult::Rejected(
          "skia-hybrid GPU runtime unavailable for \{NativePlatformSurface::platform_label(platform)}",
        )
      }
      let session = create_skia_gpu_host_renderer(
        surface.metrics(),
        skia_present_target_from_host(surface.cpu_present()),
        platform,
        native_surface,
        font_resolution,
        image_source=surface
          .image_source()
          .unwrap_or(@render.HostImageSource::unavailable()),
        image_decoder=Some(image_decoder),
      )
      @render.RendererBindResult::Bound(session)
    },
  )
}

///|
fn skia_image_decoder() -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, bytes) => {
    match bytes {
      Some(data) =>
        skia_image_load_completion_from_bytes(source, data, background_io=true)
      None => skia_image_load_completion(source)
    }
  })
}

///|
fn skia_present_target_from_host(
  host : @render.PresentTarget?,
) -> SkiaPresentTarget {
  match host {
    Some(host) =>
      SkiaPresentTarget::new(description=host.description(), present=frame => {
        host.present(
          @render.PixelFrame::new(
            width=frame.width(),
            height=frame.height(),
            row_bytes=frame.row_bytes(),
            scale_factor=frame.scale_factor(),
            pixels=frame.pixels(),
          ),
        )
      })
    None =>
      SkiaPresentTarget::new(description="missing host CPU presenter", present=_ => {
        false
      })
  }
}

///|
fn create_skia_gpu_host_renderer(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  platform : NativeGpuPlatform,
  native_surface : @render.NativeSurface,
  font_resolution : SkiaFontResolution,
  image_source? : @render.HostImageSource = @render.HostImageSource::unavailable(),
  image_decoder? : @render.RendererImageDecoder? = None,
) -> @render.RendererSession {
  let route = NativePlatformSurface::surface_route(platform)
  // The host window's current physical size. Direct3D swap chains are resized
  // in place through the present path (ResizeBuffers); an HWND cannot hold a
  // second flip-model swap chain while the previous one is still referenced,
  // so recreating the surface on resize is not an option on Windows.
  let expected_metrics : Ref[@core.SurfaceMetrics] = Ref(metrics)
  let expected_size = () => {
    let metrics = expected_metrics.val
    Some(
      @moui_skia.ISize::new(
        metrics.physical_size.width.ceil().max(1.0).to_int(),
        metrics.physical_size.height.ceil().max(1.0).to_int(),
      ),
    )
  }
  let gpu_target = HostGpuPresentTarget::new(
    description="Skia direct host GPU presenter",
    create_window_surface=(context, next_metrics) => {
      native_surface.resize(next_metrics)
      match context {
        Some(context) =>
          skia_gpu_window_surface(
            context, platform, native_surface, next_metrics,
          )
        None => None
      }
    },
    present_gpu=(context, surface) => {
      let next = match context {
        Some(context) =>
          skia_gpu_present_and_acquire_next(
            surface, context, platform, native_surface,
            expected_size=expected_size(),
          )
        None => None
      }
      match next {
        Some(next_surface) => {
          ignore(native_surface.present(1UL))
          HostGpuPresentOutcome::new(
            succeeded=true,
            next_surface=Some(next_surface),
          )
        }
        None => HostGpuPresentOutcome::new(succeeded=false)
      }
    },
  )
  let gpu_renderer = create_with_present_target_and_route(
    metrics,
    target,
    surface_route=route,
    gpu_target=Some(gpu_target),
    font_resolution~,
    async_image_loading=true,
  ) catch {
    err => {
      // GPU context/surface creation can still fail after a positive native
      // capability probe. Keep the selected factory usable by constructing the
      // neutral CPU presenter immediately; the same path also handles hosts
      // that expose a stale drawable during attach.
      println(
        "Skia GPU renderer unavailable at attach; falling back to raster: " +
        err.message(),
      )
      return create_skia_raster_host_renderer(
        metrics,
        target,
        font_resolution,
        image_source~,
        image_decoder~,
        native_surface=Some(native_surface),
      )
    }
  }
  let fallback : Ref[SkiaRasterRenderer?] = Ref(None)
  let fallback_active : Ref[Bool] = Ref(false)
  let activate_fallback : (@core.SurfaceMetrics) -> Bool = next_metrics => {
    if fallback_active.val {
      return true
    }
    // Releasing the GPU surface before the CPU presenter locks the native
    // window is required on Android and HarmonyOS (both reuse the same host
    // window for the raster fallback).
    gpu_renderer.dispose()
    let raster : SkiaRasterRenderer? = Some(
      create_with_present_target(
        next_metrics,
        target,
        font_resolution~,
        async_image_loading=true,
      ),
    ) catch {
      err => {
        println(
          "Skia raster fallback unavailable after GPU failure: " + err.message(),
        )
        None
      }
    }
    match raster {
      Some(renderer) => {
        fallback.val = Some(renderer)
        fallback_active.val = true
        true
      }
      None => false
    }
  }
  let with_active : ((SkiaRasterRenderer) -> Unit) -> Unit = action => {
    match fallback.val {
      Some(renderer) if fallback_active.val => action(renderer)
      _ => action(gpu_renderer)
    }
  }
  let active_render_frame : (@render.RenderFrameSubmission) -> @render.RenderFrameResult = submission => {
    let frame = submission.frame()
    match fallback.val {
      Some(renderer) if fallback_active.val => renderer.render_frame(frame)
      _ => {
        let result = gpu_renderer.render_frame(frame)
        if result.presented {
          result
        } else if activate_fallback(gpu_renderer.metrics()) {
          match fallback.val {
            Some(renderer) => renderer.render_frame(frame)
            None => result
          }
        } else {
          result
        }
      }
    }
  }
  @render.RendererSession::new(
    resize=next_metrics => {
      if fallback_active.val {
        match fallback.val {
          Some(renderer) =>
            renderer.resize(next_metrics) catch {
              err =>
                println("error resizing Skia raster fallback: " + err.message())
            }
          None => ()
        }
      } else {
        expected_metrics.val = next_metrics
        gpu_renderer.resize(next_metrics) catch {
          err => {
            println("error resizing Skia GPU renderer: " + err.message())
            ignore(activate_fallback(next_metrics))
          }
        }
      }
    },
    render_frame=active_render_frame,
    text_system=() => {
      match fallback.val {
        Some(renderer) if fallback_active.val => renderer.text_system()
        _ => gpu_renderer.text_system()
      }
    },
    present_count=() => {
      match fallback.val {
        Some(renderer) if fallback_active.val => renderer.present_count()
        _ => gpu_renderer.present_count()
      }
    },
    dispose=() => {
      gpu_renderer.dispose()
      match fallback.val {
        Some(renderer) => renderer.dispose()
        None => ()
      }
    },
    image_records=() => {
      match fallback.val {
        Some(renderer) if fallback_active.val => renderer.image_resources()
        _ => gpu_renderer.image_resources()
      }
    },
    apply_image_load_completion=completion => {
      match fallback.val {
        Some(renderer) if fallback_active.val =>
          renderer.apply_image_resource_load_completion(completion)
        _ => gpu_renderer.apply_image_resource_load_completion(completion)
      }
    },
    image_source~,
    image_decoder~,
    platform_view=@render.RendererPlatformViewCapability::new(
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
        with_active(action => {
          action.draw_platform_view_pixels(
            pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
          )
        })
      },
      set_platform_view_draw_fn=draw_fn => {
        with_active(action => action.set_platform_view_draw_fn(draw_fn))
      },
    ),
    gpu_recovery=@render.RendererGpuRecoveryCapability::new(gpu_fallback_active=() => {
      fallback_active.val
    }),
    native_surface=Some(native_surface),
  )
}

///|
/// Construct the synchronous CPU host path used both by the explicit raster
/// factory and by GPU creation/recovery failures.
fn create_skia_raster_host_renderer(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  font_resolution : SkiaFontResolution,
  image_source? : @render.HostImageSource = @render.HostImageSource::unavailable(),
  image_decoder? : @render.RendererImageDecoder? = None,
  native_surface? : @render.NativeSurface? = None,
) -> @render.RendererSession {
  create_with_present_target(
    metrics,
    target,
    font_resolution~,
    async_image_loading=true,
  ).to_renderer_session(image_source~, image_decoder~, native_surface~) catch {
    err => abort(err.message())
  }
}

///|
fn skia_gpu_surface_descriptor(
  metrics : @core.SurfaceMetrics,
) -> @moui_skia.SurfaceDescriptor {
  @moui_skia.SurfaceDescriptor::gpu_n32_premul(
    @moui_skia.ISize::new(
      metrics.physical_size.width.ceil().max(1.0).to_int(),
      metrics.physical_size.height.ceil().max(1.0).to_int(),
    ),
  )
}

///|
fn skia_gpu_window_surface(
  context : @skia_native.GpuContext,
  platform : NativeGpuPlatform,
  native_surface : @render.NativeSurface,
  metrics : @core.SurfaceMetrics,
) -> @skia_native.Surface? {
  let surface = skia_gpu_surface_descriptor(metrics)
  match platform {
    NativeGpuPlatform::MacOS | NativeGpuPlatform::IOS =>
      @skia_native.Surface::metal_window_surface(
        context,
        native_surface.surface_handle(),
        surface,
      )
    NativeGpuPlatform::Windows =>
      @skia_native.Surface::direct3d_window_surface(
        context,
        native_surface.surface_handle(),
        surface,
      )
    NativeGpuPlatform::Android =>
      @skia_native.Surface::vulkan_window_surface(
        context,
        native_surface.surface_handle(),
        surface,
      )
    NativeGpuPlatform::Linux =>
      @skia_native.Surface::vulkan_wayland_surface(
        context,
        native_surface.display_handle().unwrap(),
        native_surface.surface_handle(),
        surface,
      )
    NativeGpuPlatform::HarmonyOS =>
      @skia_native.Surface::egl_window_surface(
        context,
        native_surface.surface_handle(),
        surface,
      )
  }
}

///|
fn skia_gpu_present_and_acquire_next(
  surface : @skia_native.Surface,
  context : @skia_native.GpuContext,
  platform : NativeGpuPlatform,
  native_surface : @render.NativeSurface,
  expected_size? : @moui_skia.ISize? = None,
) -> @skia_native.Surface? {
  match platform {
    NativeGpuPlatform::MacOS | NativeGpuPlatform::IOS =>
      @skia_native.Surface::metal_present_and_acquire_next(
        surface,
        context,
        native_surface.surface_handle(),
      )
    NativeGpuPlatform::Windows =>
      @skia_native.Surface::direct3d_present_and_acquire_next(
        surface,
        context,
        native_surface.surface_handle(),
        expected_size~,
      )
    NativeGpuPlatform::Linux | NativeGpuPlatform::Android =>
      @skia_native.Surface::vulkan_present_and_acquire_next(
        surface,
        context,
        native_surface.surface_handle(),
      )
    NativeGpuPlatform::HarmonyOS =>
      @skia_native.Surface::egl_present_and_acquire_next(
        surface,
        context,
        native_surface.surface_handle(),
      )
  }
}

///|
fn skia_gpu_runtime_available(platform : NativeGpuPlatform) -> Bool {
  match platform {
    NativeGpuPlatform::MacOS | NativeGpuPlatform::IOS =>
      @skia_native.Surface::metal_gpu_context_runtime_available()
    NativeGpuPlatform::Windows =>
      @skia_native.Surface::direct3d_gpu_context_runtime_available()
    NativeGpuPlatform::Linux | NativeGpuPlatform::Android =>
      @skia_native.Surface::vulkan_gpu_context_runtime_available()
    NativeGpuPlatform::HarmonyOS =>
      @skia_native.Surface::egl_gpu_context_runtime_available()
  }
}

///|
fn skia_native_surface_error(
  platform : NativeGpuPlatform,
  surface : @render.NativeSurface,
) -> String? {
  if surface.surface_handle() == 0UL {
    return Some("skia-hybrid requires a non-zero surface handle")
  }
  match platform {
    NativeGpuPlatform::Linux =>
      match surface.display_handle() {
        Some(display) if display != 0UL => None
        _ => Some("skia-hybrid linux requires a non-zero display handle")
      }
    _ => None
  }
}

///|
/// Resolve the environment policy entirely inside the Skia renderer package.
pub fn from_env(
  platform~ : NativeGpuPlatform,
) -> Array[@render.RendererProvider] {
  let mode = match @env.get_env_var("MOUI_SKIA_RENDERER") {
    Some(value) => NativeRendererMode::parse(value)
    None => None
  }
  providers_for_mode(platform, mode)
}

///|
fn providers_for_mode(
  platform : NativeGpuPlatform,
  mode : NativeRendererMode?,
) -> Array[@render.RendererProvider] {
  match mode {
    Some(NativeRendererMode::SkiaRaster) => [raster()]
    Some(NativeRendererMode::SkiaGpu) => [gpu(platform~)]
    Some(NativeRendererMode::Auto) | None => [gpu(platform~), raster()]
  }
}
