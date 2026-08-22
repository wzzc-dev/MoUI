# MoUI 3D 0.1.10 Breaking Release

- Status: active
- Release: 0.1.10
- Goal: deliver the independent 3D addon with a renderer-neutral GPU packet
  contract, glTF/GLB PBR and animation ingestion, explicit host capability
  diagnostics, and platform evidence gates.
- Compatibility: breaking release; no 0.1.x compatibility shim is kept for the
  previous 3D packet or material API.

The addon remains independent from MoUI's 2D DrawCommand protocol and from the
Native Skia mainline. Native macOS/Windows/Linux use the experimental WGPU
route; Web uses a secondary WebGPU canvas. A host without the required GPU
capability reports typed unavailable/failure state rather than silently falling
back to CPU 3D.

## Delivered in this slice

- Right-handed, Y-up Double scene math, homogeneous model/view/projection
  transforms, orbit camera, AABB and CPU triangle picking.
- glTF 2.0/GLB validation and accessor decoding for positions, normals, UVs,
  indices, node TRS/matrix, PBR base/normal/occlusion/emissive textures,
  emissive factor, alpha mode/cutoff and double-sided materials. Data URI
  buffers, sampler wrap/filter state, camera/scene metadata, sparse accessors
  required-extension diagnostics, skin joints/inverse-bind metadata, vertex
  joints/weights and morph target deltas are included.
- CPU animation data model and glTF animation channel ingestion for STEP,
  LINEAR and CUBICSPLINE translation, rotation, scale and weights paths.
- Renderer-neutral ThreeDRenderPacket, stable resource keys, session-owned
  residency graph with create/remove transitions for mesh/material/texture/
  sampler resources, and depth-tested native/Web GPU host paths.
- Injected asset byte source API, independent macOS/Web 3D platform ports, and
  addon packages for neutral physics and XR contracts.
- Rapier 0.5.1 adapter with dynamic/fixed/kinematic bodies, supported collider
  shapes, gravity stepping, transform queries and ray hits, using stable
  neutral ids.
- Native WGPU now owns a session-local vertex buffer cache. Stable packet
  revisions reuse the buffer without a queue upload; changed payloads replace
  and release the old buffer, while dispose releases the cache.
- Native and WebGPU hosts reuse expanded vertex payloads across frames and
  apply material/texture/sampler residency notifications, and release cached
  buffers on session disposal.
- The example viewer loads the checked-in `fixture.gltf` through MoonBit's
  deterministic `:embed` pre-build and `load_gltf_scene`, keeps a procedural
  fallback, and exposes play, pause, seek, clip selection and pick state with
  app tests. Animation samples are applied to a copied scene before each
  snapshot publish.
- A separate native-only `examples/three_d_physics_viewer` example now owns
  the Rapier integration. It demonstrates a dynamic sphere falling onto a fixed
  ground collider, fixed-step simulation controls, transform synchronization
  into `moui_3d.Scene`, and a neutral ray-cast readout without adding physics
  state to the glTF viewer.

## Remaining release gates

1. Add concrete GPU skin deformation and morph target evaluation passes; the
   CPU scene and packet data are now present.
2. Extend concrete native/Web image upload and sampler object caches; neutral
   residency notifications are now present but texture decode/upload is still
   pending.
3. Keep the Web typed/binary host bridge under browser smoke coverage; the
   wasm ABI uses a base64 envelope that is decoded once into Uint8Array, and
   the browser pixel smoke still needs to exercise the 3D entrypoint.
4. Add alpha interaction coverage to the example viewer after the fixture
   loader exposes texture sampling and material alpha in the packet.
5. Add Windows/Linux surface plugins and composition roots, then collect real
   nonblank color and depth-occlusion evidence on macOS, Web, Windows and
   Linux.
6. Implement WebXR/OpenXR bridge, swapchain/view pose/input/frame submit, and
   desktop OpenXR matrix evidence.

## Validation loop

Focused package tests run on every change. Before release, run the 3D, physics
and XR focused tests, moon info for public API snapshots, API and release-
closure validators, renderer/backend boundary validators, and the platform
smoke catalog. Real presentation evidence is required before changing the
experimental readiness declaration.
