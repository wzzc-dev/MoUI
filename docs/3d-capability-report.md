# 3D Addon Capability Report

wzzc-dev/moui_3d is an independent experimental addon. Version 0.1.10 is a
breaking 3D release and does not alter MoUI's 2D draw contract or Native Skia
mainline.

| Area | Status | Evidence |
|---|---|---|
| CPU math, homogeneous transforms, scene graph, AABB and ray picking | implemented | moon test moui_3d --target native |
| glTF/GLB validation and accessor decoding | implemented for documented subset | focused loader tests; data URI, sparse accessor, sampler/camera/scene, skin and morph coverage |
| PBR material metadata and texture references | implemented | material-level texture/alpha regression test |
| STEP/LINEAR/CUBICSPLINE animation ingestion | implemented for CPU channels | animation tests and loader path |
| Renderer-neutral packet and stable resource residency | implemented | moon test moui_3d/render --target native |
| Native WGPU depth-tested forward pass | experimental / compiled | native renderer test/build; real pixel evidence pending |
| WebGPU secondary canvas depth-tested pass | experimental / compiled | wasm-gc renderer test/build; browser pixel evidence pending |
| macOS 3D child-surface plugin | experimental / compiled | moui_3d/backend/macos |
| Web 3D secondary-canvas plugin | experimental / compiled | moui_3d/backend/web |
| Physics neutral contracts | experimental / contract-only | moui_3d_physics tests |
| Rapier adapter | implemented / experimental | `Milky2018/moon_rapier@0.5.1`; native gravity, collision, transform and ray-query tests |
| Rapier viewer example | implemented / experimental | `examples/three_d_physics_viewer`; native Play/Pause/Step/Reset, scene sync and ray-query readout |
| WebXR/OpenXR | experimental / contract-only | moui_3d_xr descriptor tests |

The loader now carries skin joints/inverse-bind metadata, vertex joints/weights
and morph deltas into the CPU scene and packet. Concrete GPU deformation still
remains an experimental follow-up. Punctual lights, IBL, shadows, tone mapping
and FXAA are also outside this slice. Native and WebGPU hosts now keep
session-local vertex buffers,
apply neutral material/texture/sampler residency notifications, and skip
repeat-payload uploads; concrete image upload plus browser-pixel gates remain
release work.

All platform routes report typed unavailable/failure results when a required
GPU host is absent. No CPU 3D fallback is claimed. Product readiness remains
ready=false until matching-device nonblank color and depth-occlusion smokes
are recorded for macOS, Web, Windows and Linux.
