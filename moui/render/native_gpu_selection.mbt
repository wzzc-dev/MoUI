///|
/// Raw host surface descriptor used only by renderer/provider integration.
/// Application packages should leave native handle ownership to platform
/// entrypoints.
pub enum GpuHostSurfaceDescriptor {
  MetalLayer(UInt64)
  D3D12Hwnd(UInt64)
  AndroidVulkanWindow(UInt64)
  WaylandVulkanSurface(UInt64, UInt64)
  EglNativeWindow(UInt64)
} derive(Eq, Debug, ToJson)

///|
pub fn GpuHostSurfaceDescriptor::metal_layer(
  layer : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if layer == 0UL {
    None
  } else {
    Some(MetalLayer(layer))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::d3d12_hwnd(
  hwnd : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if hwnd == 0UL {
    None
  } else {
    Some(D3D12Hwnd(hwnd))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::android_vulkan_window(
  native_window : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if native_window == 0UL {
    None
  } else {
    Some(AndroidVulkanWindow(native_window))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::wayland_vulkan_surface(
  display : UInt64,
  surface : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if display == 0UL || surface == 0UL {
    None
  } else {
    Some(WaylandVulkanSurface(display, surface))
  }
}

///|
pub fn GpuHostSurfaceDescriptor::egl_native_window(
  native_window : UInt64,
) -> GpuHostSurfaceDescriptor? {
  if native_window == 0UL {
    None
  } else {
    Some(EglNativeWindow(native_window))
  }
}
