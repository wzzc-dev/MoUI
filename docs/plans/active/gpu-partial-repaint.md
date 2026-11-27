# Plan: GPU inter-frame partial repaint

- **Status**: active
- **Goal**: Turn the existing damage bookkeeping into real GPU-side partial
  repaint: present only the damaged region per frame on the GPU routes
  instead of full-surface redraws, with per-renderer swapchain ownership.
- **Environment prerequisite**: matching-host GPU surfaces (macOS Metal
  window, Windows D3D12/Vulkan, Linux Wayland Vulkan) for the L2 evidence
  the GPU promotion runbook requires. The MoonBit-side slices below are
  host-independent and land first.

## Starting point (verified 2026-11-07)

- `SurfaceDamageCapability` (`moui/render/renderer.mbt`) is a capability
  contract enum with no presenter implementation behind it.
- Damage bookkeeping is structural: `DamageRegion`/`DamageIndex` track
  rebuild/layout/paint dirtiness and the accumulated per-frame damage region
  reaches the renderer as `DrawFrame.damage`, but pixel-level frame-间
  composition (preserving the previous frame outside the damage rect) is not
  implemented on any GPU route.
- `SkiaGpuNative` presents full frames through the native worker
  (`gpu_render_worker.mbt`, capacity-two latest-wins); the promotion
  manifests track window-surface ownership per platform.
- `benchmarks/app_cached_layer` already measures damage-rect and cache
  hit/miss behavior.

## Implementation progress (2026-11-26, issue #45 workstream 1)

Landed for the default providers, without claiming partial presentation:

- Damage resolves per draw target: retained CPU raster and Metal backing
  accept `SubRect` after their first full draw; a fresh GPU drawable always
  resolves full. Resize, incomplete-frame, flush/copy failure, and backing
  invalidation force the next full clear; push/pop scope frames fall back to
  full with a recorded reason.
- The Metal backing is updated only inside the effective damage region,
  flushed, and copied in full into the new drawable; direct
  Vulkan/Direct3D/EGL drawables stay full; partial presentation is not
  implemented.
- `SkiaDamageReport` records requested/effective damage, fallback reason,
  target, presented, and phase microseconds; `SkiaPartialRepaintReport`
  separates advertised `SubRect`, drawable retention, backing, partial
  redraw, and partial present. `renderer.damage_fallback` carries
  promotions into `RenderFrameResult.diagnostics`.
- Default wiring: `raster()` and the CPU fallback advertise `SubRect`; the
  GPU provider advertises `SubRect` only on Metal and normalizes an explicit
  `SubRect` on other GPU routes to `FullSurfaceOnly`.

| Path | Advertised | Retained pixels | Partial redraw | Partial present |
|---|---|---|---|---|
| Skia raster CPU (`raster()`) | `SubRect` | retained raster surface | yes, after first full frame | no (full pixel frame) |
| Skia GPU Metal backing | `SubRect` | offscreen backing; fresh drawable | yes, after backing init | no (full backing copy) |
| Skia GPU Vulkan/D3D/EGL direct | `FullSurfaceOnly` | none | no | no |
| Push/pop scope frame | forced full | unchanged | no (fallback recorded) | n/a |

`skia_renderer_partial_repaint_wbtest.mbt` covers move, delete, transparent
background, HiDPI, scope fallback, resize/incomplete recovery, default raster
negotiation, and Metal backing; CPU cases compare exact bytes to a full reference.
Measured on Linux x86_64 native Skia CPU raster, 2026-11-26, one run of
`moon run moui_tests/skia_cached_layer_benchmark/native --target native`
(120 frames, 20 warmup; not a budget). `draw` includes replay and flush,
`copy` is raster readback, `present` the callback:

| Run | draw ms | copy ms | present ms |
|---|---|---|---|
| Partial overlay, `SubRect`, 120-frame average | 0.770 | 0.333 | 0.00025 |
| Same commands, full damage, single warmed reference | 19.284 | 0.642 | 0.00034 |
| Full dashboard, `FullSurfaceOnly`, 120-frame average | 20.030 | 0.730 | 0.00050 |

The partial final frame differed from the same-renderer full reference by 52
bytes (max channel delta 5 of 2,304,000); the harness bounds that clip-edge
antialiasing while unit tests compare exactly. Cached-layer hit frames still
fall back to full because the cached range contains scope commands. GPU phase
numbers are not claimed: this host reports `metal=false vulkan=false`, so
Metal backing has guarded tests but no matching-host timing; its smoke and
promotion manifests remain the evidence route.

## Slices

1. **Contract first**: extend `RendererSession`/`SurfaceDamageCapability`
   with a real query (`supports_partial_present()`) and define the damaged-
   rect presentation semantics for retained layers + the accumulated
   `DrawFrame.damage` region; document which routes can honor it (Metal
   drawable damage, Wayland surface damage, D3D12 DirtyRects).
2. **Skia raster route**: plumb the accumulated damage rect into the CPU
   presenter's present path (surface invalidation rects), giving the
   raster mainline a measurable partial-present baseline.
3. **SkiaGpuNative worker**: carry the damage region through the
   `RendererControlMessage` handoff and apply it on the presenting side per
   platform worker (macOS Metal first — the only completed worker owner).
4. **Evidence**: matching-host frame-time + present-rect observation via the
   GPU promotion runbook's seven-gate manifests; extend
   `benchmarks/app_cached_layer` with a present-rect-size budget in
   `checks/performance-budgets.json`.

## Acceptance

- [ ] `SurfaceDamageCapability` backed by a real per-route capability query
      with L1 tests.
- [ ] macOS Metal worker presents damaged rects only; frame budget asserts
      present-rect area < full surface for partial updates.
- [ ] Windows/Linux GPU routes either honor the contract or report
      `unsupported` honestly in the capability report.
- [ ] `renderer-capability-report.md` and the GPU promotion manifests
      updated with matching-host evidence.

Workstream 1 does not complete the partial-present acceptance items above;
they remain open until a presenting side consumes the damage region.

## Validation

```sh
moon test moui/render --target native
moon test moui_skia_renderer --target native
sh scripts/check.sh --profile platform
scripts/macos-metal-presentation-smoke.sh
```
