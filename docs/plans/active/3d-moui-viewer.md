# MoUI 3D Viewer Addon

- **Status**: active
- **Goal**: Ship an independent static glTF/GLB viewer addon with explicit GPU
  capability diagnostics and no changes to the 2D draw contract.
- **Non-goals**: game-engine systems, CPU 3D fallback, animation, skinning,
  transparency, shadows, XR, physics, and editor tooling.

This plan tracks the experimental `wzzc-dev/moui_3d` addon. The first slice is
a static glTF/GLB viewer with a renderer-neutral CPU scene model, orbit camera,
fit-to-bounds, and CPU picking. Native 3D uses an explicit WGPU route; Web uses
WebGPU. Neither route changes the Native Skia mainline or adds 3D variants to
MoUI's 2D `DrawCommand` protocol.

## Current slice

- Right-handed, Y-up scene math with `Double` CPU values.
- Static mesh primitives with positions, normals, UVs, indices, and PBR base
  color/metallic/roughness values.
- GLB container validation plus static glTF accessor decoding into scene data.
- Orbit camera and CPU ray/triangle picking.
- Latest-wins `ViewportSnapshot` binding for an external GPU surface.

GPU providers, native child surfaces, the Web secondary canvas, and the example
viewer are now wired through independent host ports. They remain experimental:
the runtime reports typed unavailable/failure results when the selected GPU host
cannot initialize, and real presentation/nonblank pixel evidence is still
required before any product-readiness change.
