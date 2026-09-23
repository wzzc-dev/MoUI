///|
test "resolve_surface_route auto remains raster when promotion flag is false" {
  let route = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Windows,
    Auto,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(route == RasterSurfaceRoute)
}

///|
test "all native platforms promote gpu for auto by default" {
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::MacOS,
    ),
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::Windows,
    ),
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::Linux,
    ),
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::Android,
    ),
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::IOS,
    ),
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::HarmonyOS,
    ),
  )
  let macos = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::MacOS,
    Auto,
    gpu_available=true,
    gpu_promoted=@moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::MacOS,
    ),
  )
  assert_true(macos == MetalGpuSurfaceRoute)
  let windows = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Windows,
    Auto,
    gpu_available=true,
    gpu_promoted=@moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::Windows,
    ),
  )
  assert_true(windows == Direct3DGpuSurfaceRoute)
  let linux = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Linux,
    Auto,
    gpu_available=true,
    gpu_promoted=@moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::Linux,
    ),
  )
  assert_true(linux == VulkanGpuSurfaceRoute)
  let android = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Android,
    Auto,
    gpu_available=true,
    gpu_promoted=@moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::Android,
    ),
  )
  assert_true(android == VulkanGpuSurfaceRoute)
  let ios = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::IOS,
    Auto,
    gpu_available=true,
    gpu_promoted=@moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::IOS,
    ),
  )
  assert_true(ios == MetalGpuSurfaceRoute)
  let harmony = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::HarmonyOS,
    Auto,
    gpu_available=true,
    gpu_promoted=@moui_skia_renderer.NativePlatformSurface::gpu_promoted(
      @moui_skia_renderer.NativeGpuPlatform::HarmonyOS,
    ),
  )
  assert_true(harmony == EglGpuSurfaceRoute)
}

///|
test "resolve_surface_route explicit gpu resolves platform route" {
  let route = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Windows,
    SkiaGpu,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(route == Direct3DGpuSurfaceRoute)
}

///|
test "resolve_surface_route auto selects gpu after promotion" {
  let route = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::HarmonyOS,
    Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == EglGpuSurfaceRoute)
}

///|
test "native renderer mode parser uses shared environment labels" {
  assert_true(
    match @moui_skia_renderer.NativeRendererMode::parse("auto") {
      Some(Auto) => true
      _ => false
    },
  )
  assert_true(
    match @moui_skia_renderer.NativeRendererMode::parse("SKIA-GPU") {
      Some(SkiaGpu) => true
      _ => false
    },
  )
  assert_true(
    match @moui_skia_renderer.NativeRendererMode::parse("skia-raster") {
      Some(SkiaRaster) => true
      _ => false
    },
  )
  assert_true(@moui_skia_renderer.NativeRendererMode::parse("wgpu") is None)
}

///|
test "Skia platform policy validates opaque native handles" {
  assert_true(@render.NativeSurface::new(surface_handle=0UL) is None)
  assert_true(@render.NativeSurface::new(surface_handle=1UL) is Some(_))
}

///|
test "resolve_surface_route returns gpu route when available and promoted" {
  let route = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::MacOS,
    Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == MetalGpuSurfaceRoute)
}

///|
test "resolve_surface_route falls back to raster when gpu unavailable" {
  let route = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Windows,
    Auto,
    gpu_available=false,
    gpu_promoted=true,
  )
  assert_true(route == RasterSurfaceRoute)
}

///|
test "resolve_surface_route respects explicit skia-raster request" {
  let route = @moui_skia_renderer.resolve_surface_route(
    @moui_skia_renderer.NativeGpuPlatform::Linux,
    SkiaRaster,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == RasterSurfaceRoute)
}

///|
test "NativePlatformSurface trait dispatches platform_label" {
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::platform_label(
      @moui_skia_renderer.NativeGpuPlatform::MacOS,
    ) ==
    "macos",
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::platform_label(
      @moui_skia_renderer.NativeGpuPlatform::Windows,
    ) ==
    "windows",
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::platform_label(
      @moui_skia_renderer.NativeGpuPlatform::Linux,
    ) ==
    "linux",
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::platform_label(
      @moui_skia_renderer.NativeGpuPlatform::Android,
    ) ==
    "android",
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::platform_label(
      @moui_skia_renderer.NativeGpuPlatform::IOS,
    ) ==
    "ios",
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::platform_label(
      @moui_skia_renderer.NativeGpuPlatform::HarmonyOS,
    ) ==
    "harmonyos",
  )
}

///|
test "NativePlatformSurface trait dispatches surface_route per platform" {
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::surface_route(
      @moui_skia_renderer.NativeGpuPlatform::MacOS,
    ) ==
    MetalGpuSurfaceRoute,
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::surface_route(
      @moui_skia_renderer.NativeGpuPlatform::Windows,
    ) ==
    Direct3DGpuSurfaceRoute,
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::surface_route(
      @moui_skia_renderer.NativeGpuPlatform::Linux,
    ) ==
    VulkanGpuSurfaceRoute,
  )
  assert_true(
    @moui_skia_renderer.NativePlatformSurface::surface_route(
      @moui_skia_renderer.NativeGpuPlatform::HarmonyOS,
    ) ==
    EglGpuSurfaceRoute,
  )
}
