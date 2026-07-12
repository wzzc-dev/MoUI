///|
pub(all) enum MobileRendererMode {
  Auto
  SkiaGpu
  SkiaRaster
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MobileRendererSelection {
  requested : MobileRendererMode
  selected : @render.RendererBackendKind
  gpu_available : Bool
  gpu_promoted : Bool
  fallback_reason : String?
} derive(Eq, Debug, ToJson)

///|
pub fn select_mobile_renderer(
  requested : MobileRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
) -> MobileRendererSelection {
  match requested {
    MobileRendererMode::SkiaRaster =>
      {
        requested,
        selected: @render.RendererBackendKind::SkiaRasterNative,
        gpu_available,
        gpu_promoted,
        fallback_reason: None,
      }
    MobileRendererMode::SkiaGpu =>
      if gpu_available {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaGpuNative,
          gpu_available,
          gpu_promoted,
          fallback_reason: None,
        }
      } else {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaRasterNative,
          gpu_available,
          gpu_promoted,
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
          fallback_reason: None,
        }
      } else {
        {
          requested,
          selected: @render.RendererBackendKind::SkiaRasterNative,
          gpu_available,
          gpu_promoted,
          fallback_reason: if !gpu_available {
            Some("Skia GPU host surface is unavailable")
          } else {
            Some("Skia GPU route has not passed platform promotion gates")
          },
        }
      }
  }
}
