///|
test "shell renderer runtime auto selects gpu by default" {
  assert_true(shell_renderer_configure("auto"))
  let selection = shell_renderer_selection(
    @render.NativeGpuPlatform::Android,
    gpu_available=true,
  )
  assert_true(selection.selected is @render.RendererBackendKind::SkiaGpuNative)
  assert_true(
    selection.surface_route is @render.SkiaSurfaceRoute::VulkanGpuSurfaceRoute,
  )
  let status = shell_renderer_status_json(
    @render.NativeGpuPlatform::Android,
    gpu_available=true,
  )
  assert_true(status.contains("\"requested\":\"auto\""))
  assert_true(status.contains("\"gpuPromoted\":true"))
  assert_true(status.contains("\"selected\":\"skia-gpu-native\""))
}

///|
test "shell renderer runtime accepts explicit gpu and rejects unknown mode" {
  assert_true(shell_renderer_configure("skia-gpu"))
  let selection = shell_renderer_selection(
    @render.NativeGpuPlatform::Ios,
    gpu_available=true,
  )
  assert_true(
    selection.surface_route is @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute,
  )
  assert_false(shell_renderer_configure("native-wgpu"))
  assert_true(shell_renderer_requested() is @render.NativeRendererMode::SkiaGpu)
  ignore(shell_renderer_configure("auto"))
}
