///|
fn main {
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @render.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  @macos_skia_backend.run_smoke_app_with_options(
    "MoUI Text Input Smoke",
    @fixture.runtime(),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
      surface_route~,
    ),
    smoke_options=@macos_skia_backend.MacosSkiaSmokeOptions::new(
      first_frame_smoke_auto_exit=true,
      native_ime_runtime_smoke=true,
    ),
  )
}
