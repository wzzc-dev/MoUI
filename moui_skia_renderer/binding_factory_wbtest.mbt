///|
test "Skia environment modes select the intended provider order" {
  let platform = NativeGpuPlatform::MacOS
  let raster_only = providers_for_mode(
    platform,
    Some(NativeRendererMode::SkiaRaster),
  )
  assert_eq(raster_only.length(), 1)
  assert_eq(raster_only[0].id(), "skia-raster")
  let gpu_only = providers_for_mode(platform, Some(NativeRendererMode::SkiaGpu))
  assert_eq(gpu_only.length(), 1)
  assert_eq(gpu_only[0].id(), "skia-hybrid")
  let automatic = providers_for_mode(platform, Some(NativeRendererMode::Auto))
  assert_eq(automatic.length(), 2)
  assert_eq(automatic[0].id(), "skia-hybrid")
  assert_eq(automatic[1].id(), "skia-raster")
  let default_mode = providers_for_mode(platform, None)
  assert_eq(default_mode.length(), 2)
  assert_eq(default_mode[0].id(), "skia-hybrid")
  assert_eq(default_mode[1].id(), "skia-raster")
}

///|
test "Skia platform policy requires a display handle only on Linux" {
  let macos = @render.NativeSurface::new(surface_handle=1UL).unwrap()
  assert_true(
    skia_native_surface_error(NativeGpuPlatform::MacOS, macos) is None,
  )
  assert_true(
    skia_native_surface_error(NativeGpuPlatform::Linux, macos) is Some(_),
  )
  let linux = @render.NativeSurface::new(
    surface_handle=1UL,
    display_handle=Some(2UL),
  ).unwrap()
  assert_true(
    skia_native_surface_error(NativeGpuPlatform::Linux, linux) is None,
  )
}
