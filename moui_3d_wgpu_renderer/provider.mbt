///|
/// Native WGPU remains experimental, but this provider now creates a real
/// device/surface/depth pipeline when the host supplies a valid native handle.
pub fn descriptor() -> @render.ThreeDRendererDescriptor {
  @render.ThreeDRendererDescriptor::new(
    id="moui-3d-native-wgpu",
    backend=@render.ThreeDRendererBackend::NativeWgpu,
    status=@render.ThreeDRendererStatus::Available,
    description="Experimental native WGPU 3D forward renderer; no CPU fallback.",
  )
}

///|
pub enum WgpuNative3DPlatform {
  MacOS
  Windows
  Linux
} derive(Eq, Debug)

///|
pub fn create_provider(
  platform? : WgpuNative3DPlatform = WgpuNative3DPlatform::MacOS,
) -> @render.ThreeDRendererProvider {
  @render.ThreeDRendererProvider::new(
    descriptor=descriptor(),
    bind=() => None,
    bind_surface=(handle, size) => {
      guard @moui_render.NativeSurface::new(surface_handle=handle)
        is Some(native_surface) else {
        return None
      }
      let metrics = @core.SurfaceMetrics::new(
        logical_size=@core.Size::new(
          width=size.width().to_double(),
          height=size.height().to_double(),
        ),
        physical_size=@core.Size::new(
          width=size.width().to_double() * size.scale_factor(),
          height=size.height().to_double() * size.scale_factor(),
        ),
        scale_factor=size.scale_factor(),
      )
      let renderer = Native3DRenderer::new(metrics, platform, native_surface) catch {
        _ => return None
      }
      Some(renderer.to_session())
    },
  )
}

///|
/// Alias used by composition roots that already selected macOS in their
/// platform entrypoint.
pub fn macos_provider() -> @render.ThreeDRendererProvider {
  create_provider(platform=WgpuNative3DPlatform::MacOS)
}

///|
/// Provider factory for a platform-owned HWND surface. The matching platform
/// view plugin remains outside the macOS-first MVP.
pub fn windows_provider() -> @render.ThreeDRendererProvider {
  create_provider(platform=WgpuNative3DPlatform::Windows)
}

///|
/// Provider factory for a platform-owned Wayland surface. Its native surface
/// descriptor must include both display and surface handles.
pub fn linux_provider() -> @render.ThreeDRendererProvider {
  create_provider(platform=WgpuNative3DPlatform::Linux)
}
