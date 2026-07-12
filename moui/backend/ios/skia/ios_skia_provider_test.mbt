///|
test "ios skia preflight names scaffold requirements" {
  let summary = ios_skia_provider_preflight_summary(
    options=IosSkiaAppOptions::new(
      font_resolution=@skia_renderer.SkiaFontResolution::EmptyTypeface,
    ),
  )
  assert_true(summary.contains("iOS Skia provider preflight"))
  assert_true(
    summary.contains("presenter=iOS UIKit UIImageView Skia pixel presenter"),
  )
  assert_true(summary.contains("runtime_status=experimental-scaffold"))
  assert_true(summary.contains("host=iOS host"))
  assert_true(summary.contains("font=empty-typeface"))
}

///|
test "ios skia preflight reports gpu metal direct presenter path" {
  let summary = ios_skia_provider_preflight_summary()
  assert_true(
    summary.contains(
      "gpu_presenter=iOS CAMetalLayer Skia Metal direct GPU presenter",
    ),
  )
  assert_true(summary.contains("gpu_runtime_available="))
  assert_true(summary.contains("metal_view_factory=available"))
}
