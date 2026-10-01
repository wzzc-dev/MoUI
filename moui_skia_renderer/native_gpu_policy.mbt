///|
pub(all) enum NativeGpuPlatform {
  MacOS
  Windows
  Linux
  Android
  IOS
  HarmonyOS
} derive(Eq, Debug, ToJson)

///|
pub extend NativeGpuPlatform with Debug::{to_repr}

///|
pub extend NativeGpuPlatform with Eq::{not_equal, equal}

///|
pub extend NativeGpuPlatform with NativePlatformSurface::{
  gpu_promoted,
  platform_label,
  surface_route,
}

///|
pub extend NativeGpuPlatform with ToJson::{to_json}

///|
pub(all) enum NativeRendererMode {
  Auto
  SkiaGpu
  SkiaRaster
} derive(Eq, Debug, ToJson)

///|
pub extend NativeRendererMode with Debug::{to_repr}

///|
pub extend NativeRendererMode with Eq::{not_equal, equal}

///|
pub extend NativeRendererMode with ToJson::{to_json}

///|
/// Renderer-local route used to select the concrete Skia GPU API. Platform
/// and graphics API names never cross the root `moui/render` boundary.
pub(all) enum SkiaSurfaceRoute {
  RasterSurfaceRoute
  MetalGpuSurfaceRoute
  VulkanGpuSurfaceRoute
  EglGpuSurfaceRoute
  Direct3DGpuSurfaceRoute
} derive(Eq, Debug, ToJson)

///|
pub extend SkiaSurfaceRoute with Debug::{to_repr}

///|
pub extend SkiaSurfaceRoute with Eq::{not_equal, equal}

///|
pub extend SkiaSurfaceRoute with ToJson::{to_json}

///|
pub fn SkiaSurfaceRoute::is_gpu(self : SkiaSurfaceRoute) -> Bool {
  match self {
    RasterSurfaceRoute => false
    _ => true
  }
}

///|
pub fn SkiaSurfaceRoute::is_implemented(self : SkiaSurfaceRoute) -> Bool {
  let _ = self
  true
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
pub(open) trait NativePlatformSurface {
  fn surface_route(Self) -> SkiaSurfaceRoute
  fn gpu_promoted(Self) -> Bool
  fn platform_label(Self) -> String
}

///|
pub fn[P : NativePlatformSurface] resolve_surface_route(
  platform : P,
  requested : NativeRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
) -> SkiaSurfaceRoute {
  let gpu_route = platform.surface_route()
  let raster_route = SkiaSurfaceRoute::RasterSurfaceRoute
  match requested {
    SkiaRaster => raster_route
    SkiaGpu => if gpu_available { gpu_route } else { raster_route }
    Auto => if gpu_available && gpu_promoted { gpu_route } else { raster_route }
  }
}

///|
pub impl NativePlatformSurface for NativeGpuPlatform with fn surface_route(self) {
  match self {
    MacOS | IOS => MetalGpuSurfaceRoute
    Windows => Direct3DGpuSurfaceRoute
    Linux | Android => VulkanGpuSurfaceRoute
    HarmonyOS => EglGpuSurfaceRoute
  }
}

///|
pub impl NativePlatformSurface for NativeGpuPlatform with fn gpu_promoted(_self) {
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
    "auto" => Some(Auto)
    "skia-gpu" => Some(SkiaGpu)
    "skia-raster" => Some(SkiaRaster)
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
