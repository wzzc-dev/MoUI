///|
test "android skia preflight names scaffold requirements" {
  let summary = android_skia_provider_preflight_summary(
    options=AndroidSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
    ),
  )
  assert_true(summary.contains("Android Skia provider preflight"))
  assert_true(
    summary.contains(
      "presenter=Android ANativeWindow RGBA8888 Skia pixel presenter",
    ),
  )
  assert_true(summary.contains("runtime_status=experimental-scaffold"))
  assert_true(summary.contains("host=Android host"))
  assert_true(summary.contains("font=empty-typeface"))
}
