///|
/// Discriminator for the host window-surface construction route a Skia renderer
/// is bound to. Per ADR 0006, the route is selected by the platform provider
/// (e.g. `moui/backend/macos/skia`, `moui/backend/android/skia`,
/// `moui/backend/harmonyos/skia`, `moui/backend/windows/skia`,
/// `moui/backend/linux/skia`, `moui/backend/ios/skia`) and propagated through
/// `resolve_surface_route` so the host knows which
/// `Surface::*_window_surface` constructor to invoke.
///
/// The enum is intentionally declared in the cross-platform `moui/render`
/// package (rather than `moui/render/skia`, which is native-only) so that
/// cross-runtime packages such as `moui/backend/host` can carry the route on
/// their value types without pulling in the native Skia dependency graph.
pub(all) enum SkiaSurfaceRoute {
  RasterSurfaceRoute
  MetalGpuSurfaceRoute
  VulkanGpuSurfaceRoute
  EglGpuSurfaceRoute
  Direct3DGpuSurfaceRoute
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaSurfaceRoute::is_gpu(self : SkiaSurfaceRoute) -> Bool {
  match self {
    RasterSurfaceRoute => false
    MetalGpuSurfaceRoute => true
    VulkanGpuSurfaceRoute => true
    EglGpuSurfaceRoute => true
    Direct3DGpuSurfaceRoute => true
  }
}

///|
pub fn SkiaSurfaceRoute::label(self : SkiaSurfaceRoute) -> String {
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
pub fn SkiaSurfaceRoute::is_implemented(self : SkiaSurfaceRoute) -> Bool {
  match self {
    RasterSurfaceRoute => true
    MetalGpuSurfaceRoute => true
    VulkanGpuSurfaceRoute => true
    EglGpuSurfaceRoute => true
    Direct3DGpuSurfaceRoute => true
  }
}
