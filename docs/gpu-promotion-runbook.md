# GPU Promotion Runbook

How to record matching-host evidence for ADR 0006 and eventually flip
`NativeGpuPlatform::gpu_promoted` so `auto` selects `SkiaGpuNative`.

This is **Wave A** tooling: scaffold manifests, gate inventory, macOS short-path
hooks, and validators. It does **not** promote any platform by itself.

## Rules

1. Source paths, package tests, offscreen GPU smoke, and `PictureRecorded` are
   **not** promotion.
2. Each platform promotes **independently**.
3. Flip `gpu_promoted` in source **only after** a manifest passes
   `node scripts/validate-gpu-promotion-manifest.mjs <file> --require-passed`
   (mobile: runtime manifest with `gpuPromotionEvidence` under
   `--require-passed`).
4. Do not commit generated files under `artifacts/` (gitignored). Link CI
   artifacts or smoke logs from ADR 0006 / release notes.

## Seven gates

| Gate | Requirement |
| --- | --- |
| `readbackEliminated` | Production present path: no full-frame CPU readback / image intermediates |
| `rendererThread` | Worker owns GPU context/surface |
| `mailboxOk` | Latest-wins frames; lifecycle controls never dropped |
| `performance` | ≥ 600s; p95 ≤ 16.7ms@60 / 8.3ms@120; dropped &lt; 1%; input→present ≤ 2 VSync |
| `memory` | Bounded; ≥ 100 surface recreations; ≥ 100 fg/bg cycles |
| `contextLoss` | Recover ≤ 3 VSyncs; raster fallback keeps `AppRuntime` |
| `rasterFallback` | Automatic after repeated recovery failure |

Schema example: [`gpu-promotion-manifest.example.json`](gpu-promotion-manifest.example.json).

## Commands

### MoonBit scaffold tool

```sh
moon run tools/moui/gpu_promotion_scaffold --target native -- \
  --platform macos --out-dir artifacts/gpu-promotion/macos/manual
moon test tools/moui/gpu_promotion_scaffold --target native
```

Node `scripts/record-gpu-promotion-smoke.mjs` is a thin orchestrator over this tool
(and optional macOS short-smoke).


### Static guard (worker must not present via readback)

```sh
node scripts/validate-gpu-worker-no-readback.mjs
```

### Scaffold a pending manifest + gap report

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos
```

Writes under `artifacts/gpu-promotion/<platform>/<timestamp>/`:

- `gpu-promotion-manifest.json` — always `gpuPromoted: false` for Wave A
- `gap-report.md` — what still blocks `auto` → GPU
- `gate-inventory.json` — tooling coverage per gate
- `recorder.log`

### macOS short-path smoke (partial diagnostics only)

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode short-smoke
```

Runs `scripts/macos-skia-renderer-smoke.sh --run-gpu-smoke --run-showcase-smoke`,
parses Metal markers, and fills **partial** diagnostics. Still **not**
promotion.

Direct smoke (without recorder):

```sh
scripts/macos-skia-renderer-smoke.sh --run-gpu-smoke --run-showcase-smoke
```

### Validate

```sh
# Schema / structural checks (pending manifests OK)
node scripts/validate-gpu-promotion-manifest.mjs \
  artifacts/gpu-promotion/macos/<ts>/gpu-promotion-manifest.json

# Promotion bar (must fail until gates are real)
node scripts/validate-gpu-promotion-manifest.mjs \
  artifacts/gpu-promotion/macos/<ts>/gpu-promotion-manifest.json \
  --require-passed
```

### macOS performance harness (partial gate)

```sh
# 15s measured window after warm-up (dev)
node scripts/run-macos-gpu-performance-smoke.mjs --duration-ms 15000 --prepare

# ADR performance gate length
node scripts/run-macos-gpu-performance-smoke.mjs --duration-ms 600000 --prepare

# or via recorder
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode performance --duration-seconds 15
```

Success log must include `surface_route=metal-gpu; surface_gpu=true; gpu_context=worker-owned; present_kind=host-gpu-surface`. If you see `Ganesh Metal runtime is unavailable; falling back to raster`, numbers are not GPU-present evidence. Ordinary runs use `moon run ... --target native`; Skia/Metal flags come from moui_skia prebuild.

Writes `metrics.json` with p95/drop%/duration. Still leaves mailbox/memory/context-loss gates incomplete and never sets `gpuPromoted=true`.

### Dry-run

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos --dry-run
```

### Lib self-test

```sh
node scripts/test-gpu-promotion-manifest-lib.mjs
```

## Modes

| Mode | Status | Meaning |
| --- | --- | --- |
| `scaffold` | implemented | Pending manifest + inventory |
| `short-smoke` | macOS only | Metal first-frame / GPU smoke markers |
| `full` | skeleton only | Writes `full-plan.json` + `metrics-template.json`, can merge `--metrics-json`, exits `3` |

`full` still exits `3` so automation cannot treat it as promotion success. Measured values may be merged through:

```sh
moon run tools/moui/gpu_promotion_scaffold --target native -- \
  --platform macos --out-dir artifacts/gpu-promotion/macos/manual \
  --mode full --metrics-json path/to/metrics.json
```

Even with metrics merged, the tool **never** sets `gpuPromoted=true`.

Local macOS short-path recording example (partial evidence only):

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode short-smoke
# expect shortPathOk=true, gpuPromoted=false, schema validate ok
```

## Product default (current)

As of 2026-07-14, **all** `NativeGpuPlatform::gpu_promoted` arms return `true`.
Product `auto` selects GPU whenever the host surface is available. This runbook
still records matching-host seven-gate evidence for quality claims; it no longer
gates the product default.

Keep working:

- explicit `skia-raster` / `MOUI_SKIA_RENDERER=skia-raster`
- sticky raster recovery after terminal GPU failure
- fallback-Skia packaging (`gpuPromoted: false`, selected raster)

## Platform order for evidence collection (recommended)

1. macOS Metal (claim already recorded)  
2. Web WebGPU (optional promotion record; already product GPU mainline)  
3. iOS Metal (device)  
4. Android Vulkan (+ API 23 GLES fallback evidence)  
5. HarmonyOS EGL (signed device)  
6. Windows D3D12 (MSVC host)  
7. Linux Wayland Vulkan  

## Related

- ADR: [`decisions/0006-mobile-gpu-surface-and-render-thread.md`](decisions/0006-mobile-gpu-surface-and-render-thread.md)
- Roadmap: [`shell-mainline-roadmap.md`](shell-mainline-roadmap.md)
- Capability notes: [`renderer-capability-report.md`](renderer-capability-report.md)
- Session: [`ai-sessions/2026-07-13-all-platform-native-gpu-workers.md`](ai-sessions/2026-07-13-all-platform-native-gpu-workers.md)
