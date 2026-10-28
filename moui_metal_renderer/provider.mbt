///|
pub fn metal_renderer_descriptor(
  capabilities : Array[@render.RendererBackendFeatureCapability],
) -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=NativeDirectGpu,
    family=DirectGpu,
    presentation=HostGpuSurface,
    supported_targets=[Native],
    capabilities~,
    // The phrases the gates grep ("No Skia", "no wgpu") are load-bearing:
    // `metal_renderer_wbtest.mbt` and the readiness docs read this string, so the
    // stage it states has to be the stage that is actually true today.
    description="Direct Metal renderer drawing on the host CAMetalLayer. No Skia and no wgpu are linked: the only graphics dependency is Apple's Metal framework (ADR 0044). Every `DrawCommand` variant has a drawing branch, the 17-row capability table is probed against the device row by row, and a first frame is presented in a real window by `scripts/macos-metal-presentation-smoke.sh`. Still experimental (ADR 0045): the windowed smoke reads the presented surface back and requires ink on it, which is coverage rather than in-window pixel fidelity, and a frame repaints the whole surface rather than a damage rect.",
  )
}
