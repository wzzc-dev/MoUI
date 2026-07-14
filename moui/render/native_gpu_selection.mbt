///|
/// Native platform whose Skia GPU route can be promoted independently.
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
pub fn NativeGpuPlatform::label(self : NativeGpuPlatform) -> String {
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
pub fn NativeGpuPlatform::surface_route(
  self : NativeGpuPlatform,
) -> SkiaSurfaceRoute {
  match self {
    Macos | Ios => SkiaSurfaceRoute::MetalGpuSurfaceRoute
    Windows => SkiaSurfaceRoute::Direct3DGpuSurfaceRoute
    Linux | Android => SkiaSurfaceRoute::VulkanGpuSurfaceRoute
    HarmonyOs => SkiaSurfaceRoute::EglGpuSurfaceRoute
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
/// Per-platform default GPU gate for `auto`. All native Skia platforms default
/// to GPU when the host surface is available; raster remains the explicit mode
/// and the sticky recovery fallback. Evidence tooling may still record
/// matching-host manifests, but does not block the product default.
pub fn NativeGpuPlatform::gpu_promoted(self : NativeGpuPlatform) -> Bool {
  match self {
    Macos | Windows | Linux | Android | Ios | HarmonyOs => true
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
pub fn select_native_renderer(
  platform : NativeGpuPlatform,
  requested : NativeRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
) -> NativeRendererSelection {
  let gpu_route = platform.surface_route()
  let raster_route = SkiaSurfaceRoute::RasterSurfaceRoute
  match requested {
    NativeRendererMode::SkiaRaster =>
      NativeRendererSelection::new(
        platform~,
        requested~,
        selected=RendererBackendKind::SkiaRasterNative,
        gpu_available~,
        gpu_promoted~,
        surface_route=raster_route,
        fallback_reason=None,
      )
    NativeRendererMode::SkiaGpu =>
      if gpu_available {
        NativeRendererSelection::new(
          platform~,
          requested~,
          selected=RendererBackendKind::SkiaGpuNative,
          gpu_available~,
          gpu_promoted~,
          surface_route=gpu_route,
          fallback_reason=None,
        )
      } else {
        NativeRendererSelection::new(
          platform~,
          requested~,
          selected=RendererBackendKind::SkiaRasterNative,
          gpu_available~,
          gpu_promoted~,
          surface_route=raster_route,
          fallback_reason=Some("requested Skia GPU host surface is unavailable"),
        )
      }
    NativeRendererMode::Auto =>
      if gpu_available && gpu_promoted {
        NativeRendererSelection::new(
          platform~,
          requested~,
          selected=RendererBackendKind::SkiaGpuNative,
          gpu_available~,
          gpu_promoted~,
          surface_route=gpu_route,
          fallback_reason=None,
        )
      } else {
        NativeRendererSelection::new(
          platform~,
          requested~,
          selected=RendererBackendKind::SkiaRasterNative,
          gpu_available~,
          gpu_promoted~,
          surface_route=raster_route,
          fallback_reason=if !gpu_available {
            Some("Skia GPU host surface is unavailable")
          } else {
            Some("Skia GPU route has not passed platform promotion gates")
          },
        )
      }
  }
}
