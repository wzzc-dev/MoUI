///|
/// Renderer-neutral discriminator for a negotiated host surface route.
/// Concrete policy and native surface construction stay in the owning
/// renderer package; platform backends expose only `SurfaceContext`.
pub(all) enum SurfaceRoute {
  RasterSurfaceRoute
  MetalGpuSurfaceRoute
  VulkanGpuSurfaceRoute
  EglGpuSurfaceRoute
  Direct3DGpuSurfaceRoute
} derive(Eq, Debug, ToJson)

///|
pub fn SurfaceRoute::is_gpu(self : SurfaceRoute) -> Bool {
  match self {
    RasterSurfaceRoute => false
    MetalGpuSurfaceRoute => true
    VulkanGpuSurfaceRoute => true
    EglGpuSurfaceRoute => true
    Direct3DGpuSurfaceRoute => true
  }
}

///|
pub fn SurfaceRoute::label(self : SurfaceRoute) -> String {
  match self {
    RasterSurfaceRoute => "raster"
    MetalGpuSurfaceRoute => "metal-gpu"
    VulkanGpuSurfaceRoute => "vulkan-gpu"
    EglGpuSurfaceRoute => "egl-gpu"
    Direct3DGpuSurfaceRoute => "direct3d-gpu"
  }
}

///|
/// Returns true when the route is wired into the renderer (a GPU context can be
/// created and a host window surface can be produced). Phase 1.1 of the
/// readback-elimination plan keeps only `MetalGpuSurfaceRoute` implemented;
/// Phase 1.6 promotes `Direct3DGpuSurfaceRoute` for the Windows presenter;
/// Phase 1.4 promotes `VulkanGpuSurfaceRoute` for the Android presenter;
/// Phase 1.5 promotes `EglGpuSurfaceRoute` for the HarmonyOS presenter;
/// Phase 1.7 promotes `VulkanGpuSurfaceRoute` for the Linux Wayland presenter.
/// The remaining GPU variant is reserved for the per-platform
/// Phase 1.7 work so providers can already negotiate the surface
/// route at selection time.
pub fn SurfaceRoute::is_implemented(self : SurfaceRoute) -> Bool {
  match self {
    RasterSurfaceRoute => true
    MetalGpuSurfaceRoute => true
    VulkanGpuSurfaceRoute => true
    EglGpuSurfaceRoute => true
    Direct3DGpuSurfaceRoute => true
  }
}
