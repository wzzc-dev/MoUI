///|
/// Build a Skia CPU raster factory from the renderer-neutral host contract.
pub fn raster(
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @render.RendererFactory {
  let image_decoder = skia_image_decoder()
  @render.RendererFactory::new(id="skia-raster", bind=kit => {
    let target = match kit.cpu_present() {
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
    let binding = create_skia_raster_host_binding(create_host_renderer=(
      metrics,
      _bound,
    ) => {
      create_with_present_target(
        metrics,
        target,
        font_resolution~,
        async_image_loading=true,
      ).to_host_window_renderer() catch {
        err => abort(err.message())
      }
    })
    @render.RendererBindingPlan::new(
      binding~,
      image_loader=Some(
        @render_common.image_loader(image_decoder, kit.image_source()),
      ),
    )
  })
}

///|
/// Build a Skia direct GPU factory. Unsupported or unavailable host GPU
/// descriptors are rejected before provider negotiation so a following raster
/// factory can take over.
pub fn gpu(
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
) -> @render.RendererFactory {
  let image_decoder = skia_image_decoder()
  @render.RendererFactory::new(id="skia-hybrid", bind=kit => {
    let descriptor = match kit.gpu_surface() {
      Some(bridge) => {
        let descriptor = bridge.descriptor()
        if skia_gpu_runtime_available(descriptor) {
          Some((bridge, descriptor))
        } else {
          None
        }
      }
      None => None
    }
    let target = skia_present_target_from_host(kit.cpu_present())
    let binding = create_skia_hybrid_host_binding(create_host_renderer=(
      metrics,
      _bound,
    ) => {
      match descriptor {
        Some((bridge, descriptor)) =>
          create_skia_gpu_host_renderer(
            metrics, target, bridge, descriptor, font_resolution,
          )
        None => abort("Skia GPU requires an available host GPU surface")
      }
    })
    let surface = match descriptor {
      Some((_bridge, descriptor)) =>
        Some(
          @render.SurfaceDescriptor::gpu_surface(
            handle=descriptor,
            width=kit.metrics().logical_size.width,
            height=kit.metrics().logical_size.height,
            scale_factor=kit.metrics().scale_factor,
          ),
        )
      None => None
    }
    @render.RendererBindingPlan::new(
      binding~,
      image_loader=Some(
        @render_common.image_loader(image_decoder, kit.image_source()),
      ),
      surface~,
    )
  })
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
  bridge : @render.HostGpuSurfaceBridge,
  descriptor : @render.GpuHostSurfaceDescriptor,
  font_resolution : SkiaFontResolution,
) -> @render.WindowRenderer {
  let route = skia_gpu_surface_route(descriptor)
  let gpu_target = HostGpuPresentTarget::new(
    description="Skia direct host GPU presenter",
    create_window_surface=(context, next_metrics) => {
      bridge.resize(next_metrics)
      match context {
        Some(context) =>
          skia_gpu_window_surface(context, descriptor, next_metrics)
        None => None
      }
    },
    present_gpu=(context, surface) => {
      let next = match context {
        Some(context) =>
          skia_gpu_present_and_acquire_next(surface, context, descriptor)
        None => None
      }
      match next {
        Some(next_surface) => {
          ignore(bridge.present(1UL))
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
      bridge.dispose()
      return create_skia_raster_host_renderer(metrics, target, font_resolution)
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
  let active_render_frame : (@core.DrawFrame) -> @render.RenderFrameResult = frame => {
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
  @render.WindowRenderer::new(
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
        gpu_renderer.resize(next_metrics) catch {
          err => {
            println("error resizing Skia GPU renderer: " + err.message())
            ignore(activate_fallback(next_metrics))
          }
        }
      }
    },
    render=commands => {
      with_active(action => {
        action.render(commands) catch {
          err => println("error rendering Skia frame: " + err.message())
        }
      })
    },
    render_frame=Some(active_render_frame),
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
      bridge.dispose()
    },
    image=@render.HostRendererImageCapability::new(
      image_resources=() => {
        match fallback.val {
          Some(renderer) if fallback_active.val => renderer.image_resources()
          _ => gpu_renderer.image_resources()
        }
      },
      image_resource_snapshot=Some(() => {
        match fallback.val {
          Some(renderer) if fallback_active.val =>
            renderer.image_resource_snapshot()
          _ => gpu_renderer.image_resource_snapshot()
        }
      }),
      apply_image_resource_load_completion=Some(completion => {
        match fallback.val {
          Some(renderer) if fallback_active.val =>
            renderer.apply_image_resource_load_completion(completion)
          _ => gpu_renderer.apply_image_resource_load_completion(completion)
        }
      }),
      set_image_resource_change_callback=callback => {
        match fallback.val {
          Some(renderer) if fallback_active.val =>
            renderer.set_image_resource_change_callback(callback)
          _ => gpu_renderer.set_image_resource_change_callback(callback)
        }
      },
    ),
    platform_view=@render.HostRendererPlatformViewCapability::new(
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
    gpu_recovery=@render.HostRendererGpuRecoveryCapability::new(gpu_fallback_active=() => {
      fallback_active.val
    }),
  )
}

///|
/// Construct the synchronous CPU host path used both by the explicit raster
/// factory and by GPU creation/recovery failures.
fn create_skia_raster_host_renderer(
  metrics : @core.SurfaceMetrics,
  target : SkiaPresentTarget,
  font_resolution : SkiaFontResolution,
) -> @render.WindowRenderer {
  create_with_present_target(
    metrics,
    target,
    font_resolution~,
    async_image_loading=true,
  ).to_host_window_renderer() catch {
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
  descriptor : @render.GpuHostSurfaceDescriptor,
  metrics : @core.SurfaceMetrics,
) -> @skia_native.Surface? {
  let surface = skia_gpu_surface_descriptor(metrics)
  match descriptor {
    @render.GpuHostSurfaceDescriptor::MetalLayer(layer) =>
      @skia_native.Surface::metal_window_surface(context, layer, surface)
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(hwnd) =>
      @skia_native.Surface::direct3d_window_surface(context, hwnd, surface)
    @render.GpuHostSurfaceDescriptor::AndroidVulkanWindow(window) =>
      @skia_native.Surface::vulkan_window_surface(context, window, surface)
    @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(display, window) =>
      @skia_native.Surface::vulkan_wayland_surface(
        context, display, window, surface,
      )
    @render.GpuHostSurfaceDescriptor::EglNativeWindow(window) =>
      @skia_native.Surface::egl_window_surface(context, window, surface)
  }
}

///|
fn skia_gpu_present_and_acquire_next(
  surface : @skia_native.Surface,
  context : @skia_native.GpuContext,
  descriptor : @render.GpuHostSurfaceDescriptor,
) -> @skia_native.Surface? {
  match descriptor {
    @render.GpuHostSurfaceDescriptor::MetalLayer(layer) =>
      @skia_native.Surface::metal_present_and_acquire_next(
        surface, context, layer,
      )
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(hwnd) =>
      @skia_native.Surface::direct3d_present_and_acquire_next(
        surface, context, hwnd,
      )
    @render.GpuHostSurfaceDescriptor::AndroidVulkanWindow(window) =>
      @skia_native.Surface::vulkan_present_and_acquire_next(
        surface, context, window,
      )
    @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(_display, window) =>
      @skia_native.Surface::vulkan_present_and_acquire_next(
        surface, context, window,
      )
    @render.GpuHostSurfaceDescriptor::EglNativeWindow(window) =>
      @skia_native.Surface::egl_present_and_acquire_next(
        surface, context, window,
      )
  }
}

///|
fn skia_gpu_surface_route(
  descriptor : @render.GpuHostSurfaceDescriptor,
) -> @render.SurfaceRoute {
  match descriptor {
    @render.GpuHostSurfaceDescriptor::MetalLayer(_) =>
      @render.SurfaceRoute::MetalGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(_) =>
      @render.SurfaceRoute::Direct3DGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::AndroidVulkanWindow(_)
    | @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(_, _) =>
      @render.SurfaceRoute::VulkanGpuSurfaceRoute
    @render.GpuHostSurfaceDescriptor::EglNativeWindow(_) =>
      @render.SurfaceRoute::EglGpuSurfaceRoute
  }
}

///|
fn skia_gpu_runtime_available(
  descriptor : @render.GpuHostSurfaceDescriptor,
) -> Bool {
  match descriptor {
    @render.GpuHostSurfaceDescriptor::MetalLayer(_) =>
      @skia_native.Surface::metal_gpu_context_runtime_available()
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(_) =>
      @skia_native.Surface::direct3d_gpu_context_runtime_available()
    @render.GpuHostSurfaceDescriptor::AndroidVulkanWindow(_)
    | @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(_, _) =>
      @skia_native.Surface::vulkan_gpu_context_runtime_available()
    @render.GpuHostSurfaceDescriptor::EglNativeWindow(_) =>
      @skia_native.Surface::egl_gpu_context_runtime_available()
  }
}

///|
/// Resolve the environment policy entirely inside the Skia renderer package.
pub fn from_env() -> Array[@render.RendererFactory] {
  let mode = match @env.get_env_var("MOUI_SKIA_RENDERER") {
    Some(value) => NativeRendererMode::parse(value)
    None => None
  }
  factories_for_mode(mode)
}

///|
fn factories_for_mode(
  mode : NativeRendererMode?,
) -> Array[@render.RendererFactory] {
  match mode {
    Some(NativeRendererMode::SkiaRaster) => [raster()]
    Some(NativeRendererMode::SkiaGpu) => [gpu()]
    Some(NativeRendererMode::Auto) | None => [gpu(), raster()]
  }
}
