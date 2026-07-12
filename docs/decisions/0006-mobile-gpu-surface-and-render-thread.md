# ADR 0006: Mobile GPU Surface And Render Thread Ownership

- Status: Accepted (Phase 1 capability implemented; Phase 2 promotion pending per-platform matching-device evidence)
- Date: 2026-07-11

## Context

The raster mobile route copies a complete pixel frame to each platform
presenter. iOS additionally constructs CoreGraphics/UIKit image objects. This
is useful for compatibility and testing but is not the final performance
architecture.

## Decision

`SkiaGpuNative` describes the direct `HostGpuSurface` route. It does not change
`SkiaRasterNative`. Platform templates expose `auto`, `skia-gpu`, and
`skia-raster`; `auto` remains raster until platform-specific promotion gates
pass.

The runtime/UI thread owns `AppRuntime`, layout, and event dispatch. A renderer
thread exclusively owns the GPU context, window surface, Skia GPU objects, and
persistent GPU caches. Immutable, deeply owned render packets cross a
capacity-two latest-wins mailbox. Lifecycle and context control messages are
ordered and never dropped.

Direct presentation means Metal drawable-backed Skia on iOS, Vulkan with GLES
fallback on Android, and EGL/GLES first on HarmonyOS. Full-frame readback or
platform image intermediates are forbidden on the GPU production path.

## Consequences

- Raster remains a tested fallback and can retain runtime state after GPU
  recovery failure.
- Cached layers, glyph atlases, images, and pipelines are generation-scoped,
  persistent, budgeted, and invalidated on context loss rather than resize.
- A descriptor, offscreen GPU smoke, or mailbox unit test is not GPU runtime
  completion. Promotion requires matching-device performance, memory,
  recreation, and context-loss evidence.

## Implementation Status

### Phase 1 — Direct GPU presentation capability (implemented)

The Phase 1 capability has landed in source behind the `--renderer skia-gpu`
opt-in. Each platform can build the GPU direct-presentation path; `auto` and
`skia-gpu` both resolve to `SkiaRasterNative` with an explicit fallback reason
until Phase 2 promotion evidence is recorded on matching hardware.

| Platform | Backend | Surface route | Source state |
| --- | --- | --- | --- |
| iOS | Metal | `MetalGpuSurfaceRoute` | Implemented (Phase 1.2) |
| macOS | Metal | `MetalGpuSurfaceRoute` | Implemented (Phase 1.3) |
| Android | Vulkan (GLES fallback) | `VulkanGpuSurfaceRoute` / `EglGpuSurfaceRoute` | Implemented (Phase 1.4) |
| HarmonyOS | EGL/GLES | `EglGpuSurfaceRoute` | Implemented (Phase 1.5) |
| Windows | Direct3D 11 | `Direct3DGpuSurfaceRoute` | Implemented (Phase 1.6) |
| Linux | Vulkan (Wayland) | `VulkanGpuSurfaceRoute` | Implemented (Phase 1.7) |

The cross-platform `SkiaSurfaceRoute` enum lives in `moui/render` so it can be
referenced from both native-only `moui/render/skia` and the wasm-gc-compatible
`moui/backend/host::MobileRendererSelection`. `HostGpuPresentTarget` takes a
flushed `@skia_native.Surface` and bypasses `read_frame()` on the GPU route;
the second per-row CPU copy in each platform presenter is skipped.

### Phase 2 — Promotion gate scaffolding (implemented)

The shared Phase 2 scaffolding required before any platform can flip
`gpu_promoted=true` is in place:

- **Renderer mailbox control queue** (`moui/render/render_frame_mailbox.mbt`):
  the existing capacity-two latest-wins frame mailbox now carries an ordered,
  never-dropped control message queue (`RendererControlMessage`:
  `Resize` / `Detach` / `ContextLoss` / `Shutdown`). Control messages survive
  frame flooding so the renderer thread always observes lifecycle transitions.
- **Context-loss recovery** (`moui/runtime/renderer_recovery.mbt`):
  cross-platform `RendererRecovery` state machine
  (`Idle → Lost → Recovering → Recovered → Idle`, terminal `FallbackToRaster`
  after exceeding `max_consecutive_recovery_failures`, default 2). Deadline is
  `vsync_ms * recovery_vsync_budget` (default 16.67 × 3 = 50.01 ms). AppRuntime
  state is preserved across all transitions. Per-platform loss detectors feed
  `report_context_loss`; the renderer thread consults `should_recover` and
  `should_fallback_to_raster` each frame.
- **Manifest schema extension** (`tools/moui/validate_mobile_runtime_manifest`):
  the validator now accepts an optional `renderer` block
  (`requested` / `selected` / `surfaceRoute` / `gpuAvailable` / `gpuPromoted` /
  `fallbackReason`) and, when `gpuPromoted=true`, requires the matching
  `gpuPromotionEvidence` block with the seven ADR 0006 gates:
  `readbackEliminated`, `rendererThread`, `mailboxOk`, `performance`
  (p95 ≤ 16.7 ms, dropped < 1 %, input-to-present ≤ 2 VSyncs), `memory`
  (bounded, ≥ 100 surface recreation + fg/bg cycles), `contextLoss`
  (recovered within 3 VSyncs, raster fallback preserves AppRuntime), and
  `rasterFallback` (automatic after repeated failure). Under `--require-passed`
  every gate must be satisfied.

### Phase 2 — Per-platform promotion evidence (pending)

`gpu_promoted` stays `false` on every platform. Promotion is recorded here as
each platform's matching-device manifest passes the seven gates above. The
promotions table is filled in incrementally:

| Platform | Backend | `gpu_promoted` | Promotion date | Manifest evidence |
| --- | --- | --- | --- | --- |
| iOS | Metal | `false` | pending | pending matching-device smoke |
| macOS | Metal | `false` | pending | pending matching-device smoke |
| Android | Vulkan / GLES | `false` | pending | pending matching-device smoke |
| HarmonyOS | EGL/GLES | `false` | pending | pending matching-device smoke |
| Windows | Direct3D 11 | `false` | pending | pending matching-device smoke |
| Linux | Vulkan (Wayland) | `false` | pending | pending matching-device smoke |

The intended backend order is iOS Metal, Android Vulkan with GLES fallback,
then HarmonyOS EGL/GLES followed by optional Vulkan. The desktop order is
macOS Metal, Windows D3D11, Linux Vulkan.
