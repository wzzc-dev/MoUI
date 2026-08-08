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
pub(all) enum NativeRendererMode {
  Auto
  SkiaGpu
  SkiaRaster
} derive(Eq, Debug, ToJson)

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
    NativeRendererMode::SkiaRaster => raster_route
    NativeRendererMode::SkiaGpu =>
      if gpu_available {
        gpu_route
      } else {
        raster_route
      }
    NativeRendererMode::Auto =>
      if gpu_available && gpu_promoted {
        gpu_route
      } else {
        raster_route
      }
  }
}

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
