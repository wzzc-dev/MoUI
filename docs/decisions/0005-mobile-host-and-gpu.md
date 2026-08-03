# ADR 0005-0006: Mobile Host and GPU (merged)

> 原编号保留为小节锚点: 0005-mobile-host-channel-ownership,0006-mobile-gpu-surface-and-render-thread

---

## ADR 0005: Mobile Host Channel Ownership

- Status: Accepted
- Date: 2026-07-11

### Context

Android JNI, iOS Obj-C++, and HarmonyOS NAPI need the same runtime-facing IME,
clipboard, semantics, and accessibility action behavior. Putting separate
state machines in each shell would make composition, async completion, and
dispose behavior diverge.

### Decision

`moui/backend/host` owns `EmbedderHostChannel` and the platform-neutral mobile
payloads. Runtime sessions synchronize IME state and revisioned flattened
semantics snapshots into the channel. Platform shells drain updates and return
typed responses through a stable C ABI.

IME requests carry text, UTF-16 selection/composition ranges, caret, and
candidate rectangle without changing desktop `window_core.ImeRequest`.
Clipboard requests are asynchronous and preserve request/session identity.
Semantics actions are validated and dispatched by `ElementId`; platform shells
must not re-hit-test screen coordinates.

### Consequences

- Platform shells own native API conversion and permission/user-interaction
  timing, while runtime semantics remain shared.
- Revisions suppress unchanged semantics traffic across JNI/Obj-C++/NAPI.
- Disposal invalidates outstanding responses so an old platform callback
  cannot mutate a new session.
- Matching-device evidence remains required before capabilities are declared
  available.

---

## ADR 0006: Mobile GPU Surface And Render Thread Ownership

- Status: Accepted (product default is GPU on all native Skia platforms; matching-hardware evidence still tracked)
- Date: 2026-07-11
- Superseding note: 2026-07-14 product default flipped all `NativeGpuPlatform::gpu_promoted` arms to `true` without waiting for every matching-device seven-gate manifest.

### Context

The raster embedded-runtime route copies a complete pixel frame to each platform
presenter. iOS additionally constructs CoreGraphics/UIKit image objects. This
is useful for compatibility and testing but is not the final performance
architecture.

### Decision

`SkiaGpuNative` describes the direct `HostGpuSurface` route. Platform templates
expose `auto`, `skia-gpu`, and `skia-raster`. Product policy is now
**GPU-by-default**: `auto` selects GPU when the host surface is available on
every native Skia platform. `skia-raster` remains the explicit CPU path and the
sticky recovery fallback after terminal GPU failure. Matching-device seven-gate
manifests remain the quality evidence bar, not the gate that enables `auto`.

The runtime/UI thread owns `AppRuntime`, layout, and event dispatch. A renderer
thread exclusively owns the GPU context, window surface, Skia GPU objects, and
persistent GPU caches. Immutable, deeply owned render packets cross a
capacity-two latest-wins mailbox. Lifecycle and context control messages are
ordered and never dropped.

Direct presentation means Metal drawable-backed Skia on iOS/macOS, Vulkan with
GLES fallback on Android, EGL/GLES first on HarmonyOS, D3D12 on Windows, and
Wayland Vulkan on Linux. Web keeps WebGPU. Full-frame readback or platform image
intermediates are forbidden on a promoted GPU production path.

### Consequences

- Raster remains a tested fallback and can retain runtime state after GPU
  recovery failure.
- Cached layers, glyph atlases, images, and pipelines are generation-scoped,
  persistent, budgeted, and invalidated on context loss rather than resize.
- A descriptor, offscreen GPU smoke, or mailbox unit test is not GPU runtime
  completion. Promotion requires matching-device performance, memory,
  recreation, and context-loss evidence.

### Implementation Status

### Phase 1 — Window-surface source paths (implemented, unpromoted)

The Phase 1 paths have landed in source and are the product default for
`auto`/`skia-gpu` when a real Skia package is linked. Android Vulkan/EGL,
HarmonyOS EGL, and iOS Metal pass their target build pipelines; Windows D3D12
and Linux Wayland Vulkan still benefit from matching-host validation. Raster is
no longer the product default.

| Platform | Backend | Surface route | Source state |
| --- | --- | --- | --- |
| iOS | Metal | `MetalGpuSurfaceRoute` | Worker-owned source; simulator GPU build and nonblank first frame passed; physical-device validation pending |
| macOS | Metal | `MetalGpuSurfaceRoute` | Worker-owned context/picture replay/present source path; local first-frame smoke passed |
| Android | Vulkan (GLES fallback) | `VulkanGpuSurfaceRoute` / `EglGpuSurfaceRoute` | Worker-owned source; minSdk 23 GPU APK cross-build passed; device validation pending |
| HarmonyOS | EGL/GLES | `EglGpuSurfaceRoute` | Worker-owned source; native Ninja and HAP build passed; signed-device validation pending |
| Windows | Direct3D 12 | `Direct3DGpuSurfaceRoute` | Worker-owned source; MSVC build and hardware validation pending |
| Linux | Vulkan (Wayland) | `VulkanGpuSurfaceRoute` | Worker-owned source; matching Wayland build/validation pending |

The cross-platform `SurfaceRoute` enum lives in `moui/render` so it can be
referenced from both native-only `moui/render/skia` and the wasm-gc-compatible
`moui/render::NativeRendererSelection`. `HostGpuPresentTarget` takes a
flushed `@skia_native.Surface` and bypasses `read_frame()` on the GPU route.
These caller-thread bindings remain compatibility/diagnostic integration APIs;
native platform providers use the Picture worker for production GPU routing.

### Phase 2 — Promotion gate scaffolding (implemented)

The shared Phase 2 scaffolding required before any platform can flip
`gpu_promoted=true` is in place:

- **Renderer mailbox control queue** (`moui/render/render_frame_mailbox.mbt`):
  the existing capacity-two latest-wins frame mailbox now carries an ordered,
  never-dropped control message queue (`RendererControlMessage`:
  `Resize` / `Detach` / `ContextLoss` / `Shutdown`). Control messages survive
  frame flooding so the renderer thread always observes lifecycle transitions.
- **Native Picture handoff** (`moui_skia/native/skia_stub_gpu_worker.cpp`): an
  independent `std::thread` retains only `SkPicture` and POD metadata, uses a
  latest-wins pending slot plus ordered controls, acknowledges detach, and
  exposes polling diagnostics. An unattached worker reports `PictureRecorded`.
  Metal, D3D12, Vulkan WSI, and EGL branches own their context, surface or
  swapchain, synchronization, picture replay, flush, and present resources.
  Android dynamically loads Vulkan on API 24+ and uses EGL/GLES when the
  loader or a present-capable queue is unavailable. Only a completed platform
  present reports `Presented`.
- **Completion-driven host accounting** (`moui/backend/host` and platform
  backends): queued submission is not presentation. macOS, Windows, and Linux
  retain a `frame_pending` flag and poll completions without resubmitting the
  same frame; Android, iOS, and HarmonyOS drain completions on every VSync.
  First-frame state, image-present revisions, and provider present counts move
  only on `Presented`. `Dropped` and `FallbackToRaster` request another frame
  without replacing `AppRuntime`.
- **Picture-backed cache and platform pixels** (`moui/render/skia`): cached
  layers are nested immutable pictures, so the same recorded frame can replay
  after terminal raster fallback. Platform-view/WebView pixels are copied into
  the active picture canvas before recording ends; the GPU producer never
  needs an UI-thread `Surface` or `Image` cache.
- **Context-loss recovery** (`moui/runtime/renderer_recovery.mbt`):
  cross-platform `RendererRecovery` state machine
  (`Idle → Lost → Recovering → Recovered → Idle`, terminal `FallbackToRaster`
  after exceeding `max_consecutive_recovery_failures`, default 2). Deadline is
  `vsync_ms * recovery_vsync_budget` (default 16.67 × 3 = 50.01 ms). AppRuntime
  state is preserved across all transitions. Per-platform loss detectors feed
  `report_context_loss`; the renderer thread consults `should_recover` and
  `should_fallback_to_raster` each frame.
- **Promotion evidence** (`docs/gpu-promotion-runbook.md`): a future
  `gpuPromoted=true` claim must include matching-host evidence for the seven
  ADR 0006 gates:
  `readbackEliminated`, `rendererThread`, `mailboxOk`, `performance`
  (p95 ≤ 16.7 ms, dropped < 1 %, input-to-present ≤ 2 VSyncs), `memory`
  (bounded, ≥ 100 surface recreation + fg/bg cycles), `contextLoss`
  (recovered within 3 VSyncs, raster fallback preserves AppRuntime), and
  `rasterFallback` (automatic after repeated failure). No embedded-runtime
  route currently makes this promotion claim.

### Phase 2 — Worker-owned GPU presentation (source implemented; promotion pending)

All native providers now record immutable pictures on the runtime thread and
queue them to the native worker. The worker owns Metal, D3D12, Vulkan, or EGL
resources, processes ordered lifecycle controls, acknowledges detach before
releasing host handles, and retains raster as the same-runtime fallback after
two failed presents. Provider accounting accepts only `Presented`; recording
and queueing are deliberately non-presenting states. macOS has a matching-host
worker-owned first-frame smoke; iOS has a simulator GPU first frame; Android
and HarmonyOS have target build evidence. Windows MSVC and Linux Wayland builds
plus matching-hardware resize, context-loss deadline, performance, and memory
evidence remain required.

### Phase 2 — Per-platform promotion evidence

Promotion is recorded here as each platform's matching-device manifest passes
the seven gates above. The promotions table is filled in incrementally.

Native mobile runs embed the gate block in the mobile runtime manifest.
Desktop and Web use `docs/gpu-promotion-manifest.example.json`, validated by
`scripts/validate-gpu-promotion-manifest.mjs --require-passed`.

| Platform | Backend | `gpu_promoted` (product default) | Default-on date | Matching-device evidence |
| --- | --- | --- | --- | --- |
| iOS | Metal | `true` | 2026-07-14 | pending physical-device seven-gate manifest |
| macOS | Metal | `true` | 2026-07-14 | matching-host claim: `artifacts/gpu-promotion/macos/promotion-full-600s/gpu-promotion-claim.json` |
| Android | Vulkan / GLES | `true` | 2026-07-14 | pending matching-device seven-gate manifest |
| HarmonyOS | EGL/GLES | `true` | 2026-07-14 | pending matching-device seven-gate manifest |
| Windows | Direct3D 12 | `true` | 2026-07-14 | pending matching-host seven-gate manifest |
| Linux | Vulkan (Wayland) | `true` | 2026-07-14 | pending matching-host seven-gate manifest |
| Web | WebGPU | n/a (already product GPU mainline) | already | optional Chrome device-loss/performance record |

All `NativeGpuPlatform::gpu_promoted()` arms return `true`, so native `auto`
selects `SkiaGpuNative` when the host GPU surface is available. Raster remains
the explicit `skia-raster` choice and the recovery fallback.

The intended backend order is iOS Metal, Android Vulkan with GLES fallback,
then HarmonyOS EGL/GLES followed by optional Vulkan. The desktop order is
macOS Metal, Windows D3D12, Linux Vulkan.

