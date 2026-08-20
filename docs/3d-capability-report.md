# 3D Addon Capability Report

This report describes the independent `moui_3d` addon. It is not a promotion
of the Native Skia route and does not change the product readiness of native
GPU rendering.

| Area | Status | Evidence |
|---|---|---|
| CPU math, scene graph, AABB and ray picking | implemented | `moon test moui_3d --target native` |
| Static glTF/GLB subset | implemented | accessor, POSITION/NORMAL/TEXCOORD_0, indices, TRS, PBR metadata and embedded/URI texture tests |
| 3D viewport snapshot and latest-wins mailbox | implemented | `ThreeDViewportBinding` tests |
| Renderer-neutral 3D provider/session protocol | implemented | `moon test moui_3d/render --target native` |
| Native WGPU surface and depth-tested forward pass | implemented / experimental | `moon build examples/three_d_viewer/macos --target native`; real CAMetalLayer child surface, WGPU device/surface/depth pipeline |
| WebGPU secondary canvas and depth-tested forward pass | implemented / experimental | `moon build examples/three_d_viewer/web_wasm --target wasm-gc`; independent `webgpu` 3D host imports and depth pipeline |
| macOS child surface plugin | implemented / experimental | AppKit/QuartzCore child `CAMetalLayer`, resize/dispose and pointer/wheel bridge in `moui_3d/backend/macos` |
| Web secondary canvas plugin | implemented / experimental | `window_web` canvas placement/visibility bridge and `WebAppOptions` registration in `moui_3d/backend/web` |

Builds and package tests establish the host wiring and compile-time contracts.
Real presentation/nonblank/depth pixel smokes still require a matching macOS
GPU or browser WebGPU runtime; no CPU or Canvas2D fallback is used when those
hosts are absent.

The supported model subset is intentionally static and opaque: triangles,
node TRS, base-color PBR factors, PNG/JPEG texture references, one directional
light, and ambient light. Animation, skinning, morph targets, transparency,
shadows, post-processing, physics, XR, and editor features remain outside this
phase and require separate RFCs.
