///|
fn main {
  let app = @app.ShowcaseApp::new()
  let exit_after_first_present = @env.get_env_var(
      "MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT",
    ) ==
    Some("1")
  let font_resolution = if exit_after_first_present {
    @skia_renderer.SkiaFontResolution::EmptyTypeface
  } else {
    @skia_renderer.SkiaFontResolution::SystemFontMgr
  }
  let surface_route = if @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") ==
    Some("metal-gpu") {
    @skia_renderer.SkiaSurfaceRoute::MetalGpuSurfaceRoute
  } else {
    @skia_renderer.SkiaSurfaceRoute::RasterSurfaceRoute
  }
  @macos_skia_backend.run_app_with_options(
    "MoUI Showcase",
    app.runtime_with_host_summary(@macos_backend.macos_capability_summary()),
    options=@macos_skia_backend.MacosSkiaAppOptions::new(
      font_resolution~,
      surface_route~,
      exit_after_first_present~,
    ),
  )
}
