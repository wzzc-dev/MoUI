///|
extern "C" fn wgpu_ptr_from_u64(value : UInt64) -> @wgpu_c.OpaquePtr = "moui_wgpu_ptr_from_u64"

///|
extern "C" fn wgpu_windows_hinstance() -> @wgpu_c.OpaquePtr = "moui_wgpu_windows_hinstance"

///|
/// Build a native WGPU provider. The composition root supplies the platform
/// policy used to interpret the renderer-neutral native handles.
pub fn native(
  platform~ : WgpuNativePlatform,
  text_engine~ : NativeTextEngine,
) -> @render.RendererProvider {
  let image_decoder = native_image_decoder()
  let caps = wgpu_provider_capabilities(
    provider_id="wgpu",
    backend=@render.RendererBackendKind::NativeWgpu,
  )
  @render.RendererProvider::new(
    id="wgpu",
    descriptor=renderer_descriptor(),
    capabilities=() => caps,
    bind=surface => {
      match @render_common.host_surface_metrics_error(surface) {
        Some(message) => return @render.RendererBindResult::Rejected(message)
        None => ()
      }
      guard surface.native_surface() is Some(native_surface) else {
        return @render.RendererBindResult::Rejected(
          "wgpu requires a native surface capability",
        )
      }
      match native_surface_error(platform, native_surface) {
        Some(message) => return @render.RendererBindResult::Rejected(message)
        None => ()
      }
      let renderer = create_native_renderer(
        surface.metrics(),
        platform,
        native_surface,
        text_engine,
      ) catch {
        err =>
          return @render.RendererBindResult::Rejected(
            "wgpu unavailable for \{platform.label()}: \{err.message()}",
          )
      }
      @render.RendererBindResult::Bound(
        renderer.to_renderer_session(
          image_source=surface
            .image_source()
            .unwrap_or(@render.HostImageSource::unavailable()),
          image_decoder=Some(image_decoder),
          native_surface=Some(native_surface),
        ),
      )
    },
  )
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
  metrics : @core.SurfaceMetrics,
  platform : WgpuNativePlatform,
  native_surface : @render.NativeSurface,
  text_engine : NativeTextEngine,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  let surface = create_native_host_surface(platform, native_surface)
  create_with_host_surface_and_text_engine(metrics, surface, text_engine~)
}

///|
fn create_native_host_surface(
  platform : WgpuNativePlatform,
  native_surface : @render.NativeSurface,
) -> HostWgpuSurface raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let surface = match platform {
    WgpuNativePlatform::MacOS => {
      let native_descriptor = @wgpu_mbt.surface_descriptor_metal_layer_new(
        wgpu_ptr_from_u64(native_surface.surface_handle()),
      )
      let surface = instance.create_surface(native_descriptor)
      @wgpu_mbt.surface_descriptor_free(native_descriptor)
      surface
    }
    WgpuNativePlatform::Windows =>
      instance.create_surface_windows_hwnd(
        wgpu_windows_hinstance(),
        wgpu_ptr_from_u64(native_surface.surface_handle()),
      )
    WgpuNativePlatform::Linux =>
      instance.create_surface_wayland(
        wgpu_ptr_from_u64(native_surface.display_handle().unwrap()),
        wgpu_ptr_from_u64(native_surface.surface_handle()),
      )
  }
  HostWgpuSurface::new(instance~, surface~)
}

///|
fn native_surface_error(
  platform : WgpuNativePlatform,
  surface : @render.NativeSurface,
) -> String? {
  if surface.surface_handle() == 0UL {
    return Some("wgpu requires a non-zero surface handle")
  }
  match platform {
    WgpuNativePlatform::Linux =>
      match surface.display_handle() {
        Some(display) if display != 0UL => None
        _ => Some("wgpu linux requires a non-zero display handle")
      }
    WgpuNativePlatform::MacOS | WgpuNativePlatform::Windows => None
  }
}

///|
pub fn WgpuRenderer::to_renderer_session(
  self : WgpuRenderer,
  image_source? : @render.HostImageSource = @render.HostImageSource::unavailable(),
  image_decoder? : @render.RendererImageDecoder? = None,
  native_surface? : @render.NativeSurface? = None,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => {
      match native_surface {
        Some(surface) => surface.resize(metrics)
        None => ()
      }
      self.resize(metrics)
    },
    render_frame=submission => {
      let frame = submission.frame()
      self.render(frame.commands)
      @render.RenderFrameResult::new(presented=true)
    },
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => self.dispose(),
    image_records=() => self.image_resources(),
    apply_image_load_completion=completion => {
      self.apply_image_resource_load_completion(completion)
    },
    image_source~,
    image_decoder~,
    native_surface~,
  )
}
