///|
/// Browser WebGPU provider over the independent `webgpu` 3D host imports.
/// It has no Canvas2D fallback and reports unavailable through the binding
/// result when the browser host did not initialize WebGPU.
pub fn descriptor() -> @render.ThreeDRendererDescriptor {
  @render.ThreeDRendererDescriptor::new(
    id="moui-3d-webgpu",
    backend=@render.ThreeDRendererBackend::WebGpu,
    status=@render.ThreeDRendererStatus::Available,
    description="WebGPU 3D host provider with depth testing; no Canvas2D fallback.",
  )
}

///|
pub fn create_provider() -> @render.ThreeDRendererProvider {
  @render.ThreeDRendererProvider::new(descriptor=descriptor(), bind=() => None)
}

///|
/// Host-linked provider used by browser composition roots. Keeping this
/// factory separate lets pure package tests run without a browser import
/// object while the real app opts into the WebGPU host port explicitly.
pub fn create_host_provider() -> @render.ThreeDRendererProvider {
  @render.ThreeDRendererProvider::new(
    descriptor=descriptor(),
    bind=() => None,
    bind_surface=(window, size) => create_webgpu_3d_session(window, size),
  )
}
