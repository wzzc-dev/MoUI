///|
pub(open) trait NativePlatformSurface {
  fn surface_route(Self) -> SkiaSurfaceRoute
  fn gpu_promoted(Self) -> Bool
  fn platform_label(Self) -> String
}

///|
/// Resolve the Skia surface route from platform capability + user preference.
/// Generic over any `NativePlatformSurface` so future platform types outside
/// `NativeGpuPlatform` can reuse this logic without editing a central matrix.
pub fn[P : NativePlatformSurface] resolve_surface_route(
  platform : P,
  requested : NativeRendererMode,
  gpu_available : Bool,
  gpu_promoted : Bool,
) -> SkiaSurfaceRoute {
  let gpu_route = platform.surface_route()
  let raster_route = SkiaSurfaceRoute::RasterSurfaceRoute
  match requested {
    NativeRendererMode::SkiaRaster => raster_route
    NativeRendererMode::SkiaGpu => if gpu_available { gpu_route } else { raster_route }
    NativeRendererMode::Auto => if gpu_available && gpu_promoted { gpu_route } else {
      raster_route
    }
  }
}
