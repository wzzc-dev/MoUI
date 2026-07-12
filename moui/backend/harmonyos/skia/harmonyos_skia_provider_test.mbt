///|
test "harmonyos skia preflight names scaffold requirements" {
  let summary = harmonyos_skia_provider_preflight_summary(
    options=HarmonyOsSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
    ),
  )
  assert_true(summary.contains("HarmonyOS Skia provider preflight"))
  assert_true(
    summary.contains(
      "presenter=HarmonyOS XComponent native window RGBA8888 Skia pixel presenter",
    ),
  )
  assert_true(summary.contains("runtime_status=experimental-scaffold"))
  assert_true(summary.contains("host=HarmonyOS host"))
  assert_true(summary.contains("font=empty-typeface"))
  assert_true(summary.contains("surface_route=raster"))
  assert_true(summary.contains("gpu_presenter="))
  assert_true(summary.contains("gpu_runtime_available="))
  assert_true(summary.contains("MOUI_SKIA_PLATFORM=harmonyos"))
}

///|
test "harmonyos skia preflight reports egl direct gpu presenter path" {
  let summary = harmonyos_skia_provider_preflight_summary(
    options=HarmonyOsSkiaAppOptions::new(
      surface_route=@render.SkiaSurfaceRoute::EglGpuSurfaceRoute,
    ),
  )
  assert_true(summary.contains("surface_route=egl-gpu"))
  assert_true(
    summary.contains("gpu_presenter=HarmonyOS EGL Skia direct GPU presenter"),
  )
  assert_true(summary.contains("gpu_runtime_available="))
}
