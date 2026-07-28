///|
test "resolve_surface_route auto remains raster when promotion flag is false" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Windows,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(route == SkiaSurfaceRoute::RasterSurfaceRoute)
}

///|
test "all native platforms promote gpu for auto by default" {
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Macos))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Windows))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Linux))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Android))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Ios))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::HarmonyOs))
  let macos = resolve_surface_route(
    NativeGpuPlatform::Macos,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Macos),
  )
  assert_true(macos == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
  let windows = resolve_surface_route(
    NativeGpuPlatform::Windows,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Windows),
  )
  assert_true(windows == SkiaSurfaceRoute::Direct3DGpuSurfaceRoute)
  let linux = resolve_surface_route(
    NativeGpuPlatform::Linux,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Linux),
  )
  assert_true(linux == SkiaSurfaceRoute::VulkanGpuSurfaceRoute)
  let android = resolve_surface_route(
    NativeGpuPlatform::Android,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Android),
  )
  assert_true(android == SkiaSurfaceRoute::VulkanGpuSurfaceRoute)
  let ios = resolve_surface_route(
    NativeGpuPlatform::Ios,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Ios),
  )
  assert_true(ios == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
  let harmony = resolve_surface_route(
    NativeGpuPlatform::HarmonyOs,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::HarmonyOs),
  )
  assert_true(harmony == SkiaSurfaceRoute::EglGpuSurfaceRoute)
}

///|
test "resolve_surface_route explicit gpu resolves platform route" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Windows,
    NativeRendererMode::SkiaGpu,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(route == SkiaSurfaceRoute::Direct3DGpuSurfaceRoute)
}

///|
test "resolve_surface_route auto selects gpu after promotion" {
  let route = resolve_surface_route(
    NativeGpuPlatform::HarmonyOs,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == SkiaSurfaceRoute::EglGpuSurfaceRoute)
}

///|
test "native renderer mode parser uses shared environment labels" {
  assert_true(
    match NativeRendererMode::parse("auto") {
      Some(NativeRendererMode::Auto) => true
      _ => false
    },
  )
  assert_true(
    match NativeRendererMode::parse("SKIA-GPU") {
      Some(NativeRendererMode::SkiaGpu) => true
      _ => false
    },
  )
  assert_true(
    match NativeRendererMode::parse("skia-raster") {
      Some(NativeRendererMode::SkiaRaster) => true
      _ => false
    },
  )
  assert_true(NativeRendererMode::parse("wgpu") is None)
}

///|
test "native GPU host surface descriptors reject zero handles" {
  assert_true(GpuHostSurfaceDescriptor::metal_layer(0UL) is None)
  assert_true(GpuHostSurfaceDescriptor::d3d12_hwnd(0UL) is None)
  assert_true(GpuHostSurfaceDescriptor::android_vulkan_window(0UL) is None)
  assert_true(
    GpuHostSurfaceDescriptor::wayland_vulkan_surface(0UL, 1UL) is None,
  )
  assert_true(
    GpuHostSurfaceDescriptor::wayland_vulkan_surface(1UL, 0UL) is None,
  )
  assert_true(GpuHostSurfaceDescriptor::egl_native_window(0UL) is None)
  assert_true(GpuHostSurfaceDescriptor::metal_layer(1UL) is Some(_))
  assert_true(
    GpuHostSurfaceDescriptor::wayland_vulkan_surface(1UL, 2UL) is Some(_),
  )
}

///|
test "resolve_surface_route returns gpu route when available and promoted" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Macos,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
}

///|
test "resolve_surface_route falls back to raster when gpu unavailable" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Windows,
    NativeRendererMode::Auto,
    gpu_available=false,
    gpu_promoted=true,
  )
  assert_true(route == SkiaSurfaceRoute::RasterSurfaceRoute)
}

///|
test "resolve_surface_route respects explicit skia-raster request" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Linux,
    NativeRendererMode::SkiaRaster,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == SkiaSurfaceRoute::RasterSurfaceRoute)
}

///|
test "NativePlatformSurface trait dispatches platform_label" {
  assert_true(NativePlatformSurface::platform_label(NativeGpuPlatform::Macos) == "macos")
  assert_true(NativePlatformSurface::platform_label(NativeGpuPlatform::Windows) == "windows")
  assert_true(NativePlatformSurface::platform_label(NativeGpuPlatform::Linux) == "linux")
  assert_true(NativePlatformSurface::platform_label(NativeGpuPlatform::Android) == "android")
  assert_true(NativePlatformSurface::platform_label(NativeGpuPlatform::Ios) == "ios")
  assert_true(NativePlatformSurface::platform_label(NativeGpuPlatform::HarmonyOs) == "harmonyos")
}

///|
test "NativePlatformSurface trait dispatches surface_route per platform" {
  assert_true(
    NativePlatformSurface::surface_route(NativeGpuPlatform::Macos) == SkiaSurfaceRoute::MetalGpuSurfaceRoute,
  )
  assert_true(
    NativePlatformSurface::surface_route(NativeGpuPlatform::Windows) == SkiaSurfaceRoute::Direct3DGpuSurfaceRoute,
  )
  assert_true(
    NativePlatformSurface::surface_route(NativeGpuPlatform::Linux) == SkiaSurfaceRoute::VulkanGpuSurfaceRoute,
  )
  assert_true(
    NativePlatformSurface::surface_route(NativeGpuPlatform::HarmonyOs) == SkiaSurfaceRoute::EglGpuSurfaceRoute,
  )
}
