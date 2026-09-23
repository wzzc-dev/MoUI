///|
pub struct WgpuRenderer {
  priv backend : RendererHandle
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=NativeWgpu,
    status=Supported,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="Native wgpu facade over wgpu_mbt/libwgpu_native; platform hosts provide HostWgpuSurface.",
  )
}

///|
pub fn native_surface_contract() -> @render.WgpuSurfaceContract {
  @render.WgpuSurfaceContract::new(
    source=NativeHostSurface,
    backend=NativeWgpu,
    ready=true,
    description="Native host owns HWND/Metal/window handles and passes an initialized wgpu surface to render/wgpu.",
  )
}

///|
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=NativeWgpu,
    family=Wgpu,
    presentation=HostGpuSurface,
    supported_targets=[Native],
    capabilities=wgpu_provider_capabilities(
      provider_id="wgpu",
      backend=NativeWgpu,
    ),
    description="Native wgpu renderer over host-provided GPU surfaces.",
  )
}

///|
pub fn create_with_host_surface(
  metrics : @core.SurfaceMetrics,
  surface : HostWgpuSurface,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  { backend: RendererHandle::create_with_host_surface(metrics, surface), }
}

///|
pub fn create_with_host_surface_and_text_engine(
  metrics : @core.SurfaceMetrics,
  surface : HostWgpuSurface,
  text_engine~ : NativeTextEngine,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  {
    backend: RendererHandle::create_with_host_surface_and_text_engine(
      metrics, surface, text_engine,
    ),
  }
}

///|
pub fn WgpuRenderer::resize(
  self : WgpuRenderer,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.backend.resize(metrics)
}

///|
pub fn WgpuRenderer::render(
  self : WgpuRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  self.backend.render(commands)
}

///|
pub fn WgpuRenderer::text_system(self : WgpuRenderer) -> @core.TextSystem {
  native_text_system_with_cache(self.backend.font_cache)
}

///|
pub fn WgpuRenderer::dispose(self : WgpuRenderer) -> Unit {
  self.backend.dispose()
}

///|
pub fn WgpuRenderer::backend_kind(
  self : WgpuRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  NativeWgpu
}

///|
pub fn WgpuRenderer::backend_info(
  self : WgpuRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn WgpuRenderer::last_batch_count(self : WgpuRenderer) -> Int {
  self.backend.last_batches.length()
}

///|
pub fn WgpuRenderer::present_count(self : WgpuRenderer) -> Int {
  self.backend.present_count
}

///|
pub fn WgpuRenderer::unsupported_command_count(self : WgpuRenderer) -> Int {
  self.backend.unsupported_command_count
}

///|
pub fn WgpuRenderer::image_resources(
  self : WgpuRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.backend.image_lifecycle.snapshot()
}

///|
pub fn WgpuRenderer::apply_image_resource_load_completion(
  self : WgpuRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> Bool {
  let changed = self.backend.image_lifecycle.apply_load_completion(completion)
  if changed {
    match completion.status {
      ImageLoadReady => {
        ignore(self.backend.failed_images.remove(completion.source))
        if completion.has_decoded_rgba_payload() {
          self.backend.decoded_image_cache[completion.source] = {
            width: completion.width,
            height: completion.height,
            data: completion.decoded_pixels,
          }
        }
      }
      ImageLoadFailed => self.backend.failed_images[completion.source] = true
    }
  }
  changed
}
