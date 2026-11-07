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

## Validation

```sh
moon test moui/render --target native
moon test moui_skia_renderer --target native
sh scripts/check.sh --profile platform
scripts/macos-metal-presentation-smoke.sh
```
