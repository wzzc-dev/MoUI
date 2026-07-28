///|
/// [DEPRECATED] Native platform enum used by the legacy `select_native_renderer`
/// central selection matrix.
///
/// **Migration**: Use `RendererProviderRegistry` + `SurfaceDescriptor` for
/// provider-based selection (ADR 0019). Platform entrypoints call
/// `create_skia_raster_provider` / `create_skia_hybrid_provider` instead of
/// `select_native_renderer`. The old function is preserved for incremental
/// migration and will be removed after all consumers migrate.
///
/// Native platform whose Skia GPU route can be promoted independently.
/// Platform surface knowledge (`surface_route`, `gpu_promoted`, `platform_label`)
/// is provided by the `NativePlatformSurface` trait impl below, replacing the
/// prior central match methods (ADR 0019 Phase E).
pub(all) enum NativeGpuPlatform {
  Macos
  Windows
  Linux
  Android
  Ios
  HarmonyOs
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
/// Result of resolving a native renderer preference against host capability
/// and the per-platform promotion state.
pub(all) struct NativeRendererSelection {
  platform : NativeGpuPlatform
  requested : NativeRendererMode
  selected : RendererBackendKind
  gpu_available : Bool
  gpu_promoted : Bool
  surface_route : SkiaSurfaceRoute
  fallback_reason : String?
} derive(Eq, Debug, ToJson)

///|
/// `NativePlatformSurface` trait impl for `NativeGpuPlatform` (ADR 0019 Phase E).
/// Each platform's GPU surface route, promotion default, and diagnostic label
/// are declared here via trait dispatch. New platforms add a branch to these
/// impls rather than editing a separate central matrix file.
///
/// Call sites use explicit `NativePlatformSurface::method(platform)` syntax
/// to avoid the deprecated implicit-promotion warning.

///|
pub impl NativePlatformSurface for NativeGpuPlatform with fn surface_route(self) {
  match self {
    Macos | Ios => SkiaSurfaceRoute::MetalGpuSurfaceRoute
    Windows => SkiaSurfaceRoute::Direct3DGpuSurfaceRoute
    Linux | Android => SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    HarmonyOs => SkiaSurfaceRoute::EglGpuSurfaceRoute
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
pub impl NativePlatformSurface for NativeGpuPlatform with fn platform_label(self) {
  match self {
    Macos => "macos"
    Windows => "windows"
    Linux => "linux"
    Android => "android"
    Ios => "ios"
    HarmonyOs => "harmonyos"
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

///|
pub fn NativeRendererSelection::new(
  platform~ : NativeGpuPlatform,
  requested~ : NativeRendererMode,
  selected~ : RendererBackendKind,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
  surface_route~ : SkiaSurfaceRoute,
  fallback_reason~ : String?,
) -> NativeRendererSelection {
  {
    platform,
    requested,
    selected,
    gpu_available,
    gpu_promoted,
    surface_route,
    fallback_reason,
  }
}

///|
/// [DEPRECATED] Resolve native renderer selection using the central matrix.
///
/// **Migration**: Use `resolve_surface_route` for route-only consumers, or
/// `RendererProviderRegistry::select_native` for provider-based selection.
/// This function is preserved for incremental migration and will be removed
/// after all consumers migrate.
///
/// Internally delegates to `resolve_surface_route` + trait methods so the
/// route calculation is no longer duplicated. The `selected` field is derived
/// from `surface_route.is_gpu()`.
pub fn select_native_renderer(
  platform : NativeGpuPlatform,
  requested : NativeRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
) -> NativeRendererSelection {
  let surface_route = resolve_surface_route(
    platform,
    requested,
    gpu_available~,
    gpu_promoted~,
  )
  let selected = if surface_route.is_gpu() {
    RendererBackendKind::SkiaGpuNative
  } else {
    RendererBackendKind::SkiaRasterNative
  }
  let fallback_reason : String? = if surface_route.is_gpu() {
    None
  } else {
    match requested {
      NativeRendererMode::SkiaRaster => None
      NativeRendererMode::SkiaGpu =>
        Some("requested Skia GPU host surface is unavailable")
      NativeRendererMode::Auto =>
        if !gpu_available {
          Some("Skia GPU host surface is unavailable")
        } else {
          Some("Skia GPU route has not passed platform promotion gates")
        }
    }
  }
  NativeRendererSelection::new(
    platform~,
    requested~,
    selected~,
    gpu_available~,
    gpu_promoted~,
    surface_route~,
    fallback_reason~,
  )
}
