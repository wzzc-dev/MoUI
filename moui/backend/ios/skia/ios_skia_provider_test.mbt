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
