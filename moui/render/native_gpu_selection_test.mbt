///|
test "native renderer auto remains raster when promotion flag is false" {
  let result = select_native_renderer(
    NativeGpuPlatform::Windows,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(result.selected == RendererBackendKind::SkiaRasterNative)
  assert_true(result.surface_route == SkiaSurfaceRoute::RasterSurfaceRoute)
  assert_true(result.fallback_reason is Some(_))
}

///|
test "all native platforms promote gpu for auto by default" {
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Macos))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Windows))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Linux))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Android))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Ios))
  assert_true(NativePlatformSurface::gpu_promoted(NativeGpuPlatform::HarmonyOs))
  let macos = select_native_renderer(
    NativeGpuPlatform::Macos,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Macos),
  )
  assert_true(macos.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(macos.surface_route == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
  let windows = select_native_renderer(
    NativeGpuPlatform::Windows,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Windows),
  )
  assert_true(windows.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(
    windows.surface_route == SkiaSurfaceRoute::Direct3DGpuSurfaceRoute,
  )
  let linux = select_native_renderer(
    NativeGpuPlatform::Linux,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Linux),
  )
  assert_true(linux.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(linux.surface_route == SkiaSurfaceRoute::VulkanGpuSurfaceRoute)
  let android = select_native_renderer(
    NativeGpuPlatform::Android,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Android),
  )
  assert_true(android.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(android.surface_route == SkiaSurfaceRoute::VulkanGpuSurfaceRoute)
  let ios = select_native_renderer(
    NativeGpuPlatform::Ios,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::Ios),
  )
  assert_true(ios.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(ios.surface_route == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
  let harmony = select_native_renderer(
    NativeGpuPlatform::HarmonyOs,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativePlatformSurface::gpu_promoted(NativeGpuPlatform::HarmonyOs),
  )
  assert_true(harmony.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(harmony.surface_route == SkiaSurfaceRoute::EglGpuSurfaceRoute)
}

///|
test "native renderer explicit gpu resolves platform route" {
  let result = select_native_renderer(
    NativeGpuPlatform::Windows,
    NativeRendererMode::SkiaGpu,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(result.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(result.surface_route == SkiaSurfaceRoute::Direct3DGpuSurfaceRoute)
}

///|
test "native renderer auto selects gpu after promotion" {
  let result = select_native_renderer(
    NativeGpuPlatform::HarmonyOs,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(result.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(result.surface_route == SkiaSurfaceRoute::EglGpuSurfaceRoute)
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
