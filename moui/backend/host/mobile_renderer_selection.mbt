///|
pub(all) enum MobileRendererMode {
  Auto
  SkiaGpu
  SkiaRaster
} derive(Eq, Debug, ToJson)

///|
/// Result of selecting a mobile Skia renderer. Product default is GPU: when
/// `gpu_promoted` and `gpu_available` are both true, `Auto` resolves to
/// `SkiaGpuNative` and `surface_route` carries the platform direct-present
/// route (`MetalGpuSurfaceRoute` / `VulkanGpuSurfaceRoute` /
/// `EglGpuSurfaceRoute` / `Direct3DGpuSurfaceRoute`). `RasterSurfaceRoute` is
/// reported for explicit raster requests, unavailable GPU, or recovery
/// fallback.
pub(all) struct MobileRendererSelection {
  requested : MobileRendererMode
  selected : @render.RendererBackendKind
  gpu_available : Bool
  gpu_promoted : Bool
  surface_route : @render.SkiaSurfaceRoute
  fallback_reason : String?
} derive(Eq, Debug, ToJson)

///|
/// Resolve the mobile renderer mode against GPU availability and the
/// platform's promotion gate. `surface_route` is required so the caller can
/// pass the platform's preferred direct-present route
/// (`MetalGpuSurfaceRoute`, `VulkanGpuSurfaceRoute`,
/// `EglGpuSurfaceRoute`, or `Direct3DGpuSurfaceRoute`); the chosen
/// `surface_route` is reported back on the returned selection. When the
/// raster fallback is selected, `surface_route` is reset to
/// `RasterSurfaceRoute` on the returned selection so consumers always see a
/// route consistent with `selected`.
pub fn select_mobile_renderer(
  requested : MobileRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
  surface_route~ : @render.SkiaSurfaceRoute,
) -> MobileRendererSelection {
  let raster_route = @render.SkiaSurfaceRoute::RasterSurfaceRoute
  match requested {
    MobileRendererMode::SkiaRaster =>
      {
        requested,
        selected: @render.RendererBackendKind::SkiaRasterNative,
        gpu_available,
        gpu_promoted,
        surface_route: raster_route,
        fallback_reason: None,
      }
    MobileRendererMode::SkiaGpu =>
      if gpu_available {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaGpuNative,
          gpu_available,
          gpu_promoted,
          surface_route,
          fallback_reason: None,
        }
      } else {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaRasterNative,
          gpu_available,
          gpu_promoted,
          surface_route: raster_route,
          fallback_reason: Some(
            "requested Skia GPU host surface is unavailable",
          ),
        }
      }
    MobileRendererMode::Auto =>
      if gpu_available && gpu_promoted {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaGpuNative,
          gpu_available,
          gpu_promoted,
          surface_route,
          fallback_reason: None,
        }
      } else {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaRasterNative,
          gpu_available,
          gpu_promoted,
          surface_route: raster_route,
          fallback_reason: if !gpu_available {
            Some("Skia GPU host surface is unavailable")
          } else {
            Some("Skia GPU route has not passed platform promotion gates")
          },
        }
      }
  }
}
