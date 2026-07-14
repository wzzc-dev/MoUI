///|
test "native renderer auto remains raster before promotion" {
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
test "macos platform promotion flag is enabled" {
  assert_true(NativeGpuPlatform::Macos.gpu_promoted())
  assert_false(NativeGpuPlatform::Windows.gpu_promoted())
  assert_false(NativeGpuPlatform::Linux.gpu_promoted())
  assert_false(NativeGpuPlatform::Android.gpu_promoted())
  assert_false(NativeGpuPlatform::Ios.gpu_promoted())
  assert_false(NativeGpuPlatform::HarmonyOs.gpu_promoted())
  let auto = select_native_renderer(
    NativeGpuPlatform::Macos,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=NativeGpuPlatform::Macos.gpu_promoted(),
  )
  assert_true(auto.selected == RendererBackendKind::SkiaGpuNative)
  assert_true(auto.surface_route == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
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
