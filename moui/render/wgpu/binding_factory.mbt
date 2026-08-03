///|
extern "C" fn wgpu_ptr_from_u64(value : UInt64) -> @wgpu_c.OpaquePtr = "moui_wgpu_ptr_from_u64"

///|
extern "C" fn wgpu_windows_hinstance() -> @wgpu_c.OpaquePtr = "moui_wgpu_windows_hinstance"

///|
/// Build a native WGPU factory. Platform text providers remain an explicit
/// composition-root choice and are captured by the factory.
pub fn native(
  text_engine~ : NativeTextEngine,
) -> @render.RendererBindingFactory {
  let image_decoder = native_image_decoder()
  @render.RendererBindingFactory::new(id="wgpu", bind=kit => {
    let descriptor = match kit.gpu_surface() {
      Some(bridge) => Some(bridge.descriptor())
      None => None
    }
    let provider = create_wgpu_provider(create_wgpu=metrics => {
      match descriptor {
        Some(descriptor) =>
          create_native_renderer(metrics, descriptor, text_engine)
        None => abort("WGPU requires a host GPU surface")
      }
    })
    let binding = @render.RendererProviderBinding::new(provider~, create_host_renderer=(
      metrics,
      _bound,
    ) => {
      match descriptor {
        Some(descriptor) =>
          create_native_renderer(metrics, descriptor, text_engine).to_host_window_renderer()
        None => abort("WGPU requires a host GPU surface")
      }
    })
    let surface = match descriptor {
      Some(descriptor) =>
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
      image_loader=Some(image_decoder.loader(kit.image_source())),
      surface~,
    )
  })
}

///|
fn native_image_decoder() -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, bytes) => {
    match bytes {
      Some(data) =>
        native_image_load_completion_from_bytes(
          source,
          data,
          background_io=true,
        )
      None => native_image_load_completion(source)
    }
  })
}

///|
fn create_native_renderer(
  metrics : @render.RendererSurfaceMetrics,
  descriptor : @render.GpuHostSurfaceDescriptor,
  text_engine : NativeTextEngine,
) -> WgpuRenderer {
  let surface = create_native_host_surface(descriptor) catch {
    err => abort(err.message())
  }
  create_with_host_surface_and_text_engine(metrics, surface, text_engine~) catch {
    err => abort(err.message())
  }
}

///|
fn create_native_host_surface(
  descriptor : @render.GpuHostSurfaceDescriptor,
) -> HostWgpuSurface raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let surface = match descriptor {
    @render.GpuHostSurfaceDescriptor::MetalLayer(layer) => {
      let native_descriptor = @wgpu_mbt.surface_descriptor_metal_layer_new(
        wgpu_ptr_from_u64(layer),
      )
      let surface = instance.create_surface(native_descriptor)
      @wgpu_mbt.surface_descriptor_free(native_descriptor)
      surface
    }
    @render.GpuHostSurfaceDescriptor::D3D12Hwnd(hwnd) =>
      instance.create_surface_windows_hwnd(
        wgpu_windows_hinstance(),
        wgpu_ptr_from_u64(hwnd),
      )
    @render.GpuHostSurfaceDescriptor::WaylandVulkanSurface(display, surface) =>
      instance.create_surface_wayland(
        wgpu_ptr_from_u64(display),
        wgpu_ptr_from_u64(surface),
      )
    _ => abort("unsupported WGPU host surface")
  }
  HostWgpuSurface::new(instance~, surface~)
}

///|
pub fn WgpuRenderer::to_host_window_renderer(
  self : WgpuRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => self.resize(metrics),
    render=commands => self.render(commands),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    dispose=() => self.dispose(),
    image=@render.HostRendererImageCapability::new(
      image_resources=() => self.image_resources(),
      image_resource_snapshot=Some(() => self.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        self.apply_image_resource_load_completion(completion)
      }),
    ),
  )
}
