# 2026-07-14 Native Skia GPU Default

## Decision

Product `auto` now selects `SkiaGpuNative` on **all** native Skia platforms when
a host GPU surface is available. Matching-device seven-gate manifests remain
quality evidence, not the product-default gate.

## Code

- `NativeGpuPlatform::gpu_promoted` → `true` for Macos/Windows/Linux/Android/Ios/HarmonyOs
- Mobile `prepare-native-build.mjs` `selectRenderer`: `auto`/`skia-gpu` → `skia-gpu` + `gpuPromoted:true` (except fallback Skia)
- `moui_skia/build.js`: default-on GPU backends per target (Metal/D3D/Vulkan/EGL)
- macOS examples/testers follow provider default route env (`MOUI_SKIA_RENDERER` / `MOUI_MACOS_SKIA_SURFACE_ROUTE`)

## Retained

- Explicit `skia-raster` / `MOUI_SKIA_RENDERER=skia-raster`
- Sticky raster recovery after terminal GPU failure
- Fallback-Skia packaging stays raster

## Docs

ADR 0006, invariants R2/R3, architecture, mobile roadmap, platform support notes,
memories, framework skill updated to the GPU-by-default policy.

## Follow-up: iOS / HarmonyOS runtime evidence (same day)

- Recorder now emits optional `renderer` (+ pending `gpuPromotionEvidence`
  skeleton when `gpuPromoted=true`, `claimed=false`) from configure logs /
  `mobile-build.json`.
- Continuous iOS `log stream` capture; service-probe-first idb planning.
- iOS shell once-fire a11y smoke via `MOUI_EMBEDDING_A11Y_SMOKE=1`.
- Runtime smoke `--require-passed` no longer requires seven-gate thresholds
  unless a promotion claim is asserted.
- Rebuilt + recorded iOS Simulator Component Gallery:
  - `artifacts/mobile-runtime/ios/component_gallery/` → **`passed`**
    (`--require-passed` ok)
- GPU promotion scaffolds:
  - `artifacts/gpu-promotion/ios/scaffold-latest/`
  - `artifacts/gpu-promotion/harmonyos/scaffold-latest/`
- HarmonyOS: `hdc list targets` empty; packaging-only note under
  `artifacts/mobile-runtime/harmonyos/harmonyos_demo/README.md`
- Docs: `docs/ios-support.md`, `docs/harmonyos-support.md`,
  `docs/mobile-mainline-roadmap.md`, `docs/testing.md`
