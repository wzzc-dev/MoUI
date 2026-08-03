///|
test "Skia environment modes select the intended factory order" {
  let raster_only = factories_for_mode(Some(NativeRendererMode::SkiaRaster))
  assert_eq(raster_only.length(), 1)
  assert_eq(raster_only[0].id(), "skia-raster")
  let gpu_only = factories_for_mode(Some(NativeRendererMode::SkiaGpu))
  assert_eq(gpu_only.length(), 1)
  assert_eq(gpu_only[0].id(), "skia-hybrid")
  let automatic = factories_for_mode(Some(NativeRendererMode::Auto))
  assert_eq(automatic.length(), 2)
  assert_eq(automatic[0].id(), "skia-hybrid")
  assert_eq(automatic[1].id(), "skia-raster")
  let default_mode = factories_for_mode(None)
  assert_eq(default_mode.length(), 2)
  assert_eq(default_mode[0].id(), "skia-hybrid")
  assert_eq(default_mode[1].id(), "skia-raster")
}
