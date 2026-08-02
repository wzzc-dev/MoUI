///|
/// Native platform enum whose Skia GPU route can be promoted independently.
/// Platform surface knowledge (`surface_route`, `gpu_promoted`, `platform_label`)
/// is provided by the `NativePlatformSurface` trait impl below, replacing the
/// prior central match methods (ADR 0019 Phase E).
///
/// Platform entrypoints call `create_skia_raster_provider` /
/// `create_skia_hybrid_provider` and use `resolve_surface_route` for route
/// calculation instead of the removed central selection matrix.
pub(all) enum NativeGpuPlatform {
  MacOS
  Windows
  Linux
  Android
  IOS
  HarmonyOS
} derive(Eq, Debug, ToJson)

///|
/// User-visible native renderer preference. `Auto` prefers GPU when the host
/// surface is available; `SkiaGpu` is an explicit request and may still fall
/// back when the host surface or provider is unavailable. `SkiaRaster` forces
/// the CPU path. Runtime recovery may still sticky-fallback to raster.
pub(all) enum NativeRendererMode {
  Auto
  SkiaGpu
  SkiaRaster
} derive(Eq, Debug, ToJson)

///|
/// Raw host surface descriptor used only by renderer/provider integration.
/// Application packages should leave native handle ownership to platform
/// entrypoints.
pub enum GpuHostSurfaceDescriptor {
  MetalLayer(UInt64)
  D3D12Hwnd(UInt64)
  AndroidVulkanWindow(UInt64)
  WaylandVulkanSurface(UInt64, UInt64)
  EglNativeWindow(UInt64)
} derive(Eq, Debug, ToJson)

///|
pub fn GpuHostSurfaceDescriptor::metal_layer(
  layer : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if layer == 0UL {
    None
  } else {
    Some(MetalLayer(layer))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::d3d12_hwnd(
  hwnd : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if hwnd == 0UL {
    None
  } else {
    Some(D3D12Hwnd(hwnd))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::android_vulkan_window(
  native_window : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if native_window == 0UL {
    None
  } else {
    Some(AndroidVulkanWindow(native_window))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::wayland_vulkan_surface(
  display : UInt64,
  surface : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if display == 0UL || surface == 0UL {
    None
  } else {
    Some(WaylandVulkanSurface(display, surface))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::egl_native_window(
  native_window : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if native_window == 0UL {
    None
  } else {
    Some(EglNativeWindow(native_window))
  }
}

///|
/// `NativePlatformSurface` trait impl for `NativeGpuPlatform` (ADR 0019 Phase E).
/// Each platform's GPU surface route, promotion default, and diagnostic label
/// are declared here via trait dispatch. New platforms add a branch to these
/// impls rather than editing a separate central matrix file.
///
/// Call sites use explicit `NativePlatformSurface::method(platform)` syntax
/// for trait dispatch.

///|
pub impl NativePlatformSurface for NativeGpuPlatform with fn surface_route(self) {
  match self {
    MacOS | IOS => SkiaSurfaceRoute::MetalGpuSurfaceRoute
    Windows => SkiaSurfaceRoute::Direct3DGpuSurfaceRoute
    Linux | Android => SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    HarmonyOS => SkiaSurfaceRoute::EglGpuSurfaceRoute
  }
}

///|
pub impl NativePlatformSurface for NativeGpuPlatform with fn gpu_promoted(_self) {
  // Per-platform default GPU gate for `auto`. All native Skia platforms
  // default to GPU when the host surface is available; raster remains the
  // explicit mode and the sticky recovery fallback.
  true
}

///|
pub impl NativePlatformSurface for NativeGpuPlatform with fn platform_label(
  self,
) {
  match self {
    MacOS => "macos"
    Windows => "windows"
    Linux => "linux"
    Android => "android"
    IOS => "ios"
    HarmonyOS => "harmonyos"
  }
}

///|
pub fn NativeRendererMode::parse(value : String) -> NativeRendererMode? {
  match value.trim().to_lower() {
    "auto" => Some(NativeRendererMode::Auto)
    "skia-gpu" => Some(NativeRendererMode::SkiaGpu)
    "skia-raster" => Some(NativeRendererMode::SkiaRaster)
    _ => None
  }
}

///|
pub fn NativeRendererMode::label(self : NativeRendererMode) -> String {
  match self {
    Auto => "auto"
    SkiaGpu => "skia-gpu"
    SkiaRaster => "skia-raster"
  }
}
