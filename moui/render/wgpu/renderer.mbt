///|
pub struct WgpuRenderer {
  priv backend : RendererHandle
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::NativeWgpu,
    status=@render.RendererCapabilityStatus::Supported,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="Native wgpu facade over wgpu_mbt/libwgpu_native; platform hosts provide HostWgpuSurface.",
  )
}

///|
pub fn native_surface_contract() -> @render.WgpuSurfaceContract {
  @render.WgpuSurfaceContract::new(
    source=@render.WgpuSurfaceSourceKind::NativeHostSurface,
    backend=@render.RendererBackendKind::NativeWgpu,
    ready=true,
    description="Native host owns HWND/Metal/window handles and passes an initialized wgpu surface to render/wgpu.",
  )
}

///|
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::NativeWgpu,
    family=@render.RendererFamily::Wgpu,
    presentation=@render.RendererPresentationModel::HostGpuSurface,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::NativeWgpu,
    ),
    description="Native wgpu renderer over host-provided GPU surfaces.",
  )
}

///|
pub fn create_with_host_surface(
  metrics : @render.RendererSurfaceMetrics,
  surface : HostWgpuSurface,
) -> WgpuRenderer raise @wgpu_mbt.WgpuError {
  { backend: RendererHandle::create_with_host_surface(metrics, surface) }
}

///|
pub fn create_with_host_surface_and_text_engine(
  metrics : @render.RendererSurfaceMetrics,
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
  metrics : @render.RendererSurfaceMetrics,
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
  @render.RendererBackendKind::NativeWgpu
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
pub fn WgpuRenderer::image_resource_snapshot(
  self : WgpuRenderer,
) -> @render.ImageResourceSnapshot {
  self.backend.image_lifecycle.snapshot_with_revision()
}

///|
pub fn WgpuRenderer::apply_image_resource_load_completion(
  self : WgpuRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  let previous_revision = self.backend.image_lifecycle.revision()
  let snapshot = self.backend.image_lifecycle.apply_load_completion(completion)
  if snapshot.revision > previous_revision {
    match completion.status {
      @render.ImageResourceLoadCompletionStatus::ImageLoadReady =>
        ignore(self.backend.failed_images.remove(completion.source))
      @render.ImageResourceLoadCompletionStatus::ImageLoadFailed =>
        self.backend.failed_images[completion.source] = true
    }
  }
  snapshot
}
