# 2026-07-14: GPU Promotion Wave A Scaffolding

- **Agent**: ZCode / Grok
- **Goal**: Start landing the all-platform “default GPU” plan without flipping
  `auto` early; move promotion manifest construction into MoonBit.
- **Outcome**: Wave A tooling landed. macOS short-path smoke recorded as partial
  evidence. `gpu_promoted` remains `false` on every platform.

## Summary

Built the ADR 0006 evidence pipeline skeleton:

1. MoonBit tool `tools/moui/gpu_promotion_scaffold` writes schema-valid pending
   manifests, gap reports, gate inventory, optional macOS smoke-log ingest, and
   optional metrics overlay merge.
2. Node `scripts/record-gpu-promotion-smoke.mjs` stays a thin orchestrator
   (static no-readback guard, optional short-smoke, full-plan skeleton).
3. Daily profile / testing docs / runbook wired to the new tools.
4. Local macOS short-smoke succeeded with Metal markers; still not promotion.

## Key artifacts (local, gitignored)

- `artifacts/gpu-promotion/macos/short-smoke-latest/`
  - `shortPathOk=true`, `workerThread=true`, `surfaceRoute=metal-gpu`
  - `gpuPromoted=false`, `gatesComplete=false`
  - Smoke log includes both renderer GPU smoke and Showcase
    `present_kind=host-gpu-surface` / `gpu_context=worker-owned`

## Validation

```sh
moon test tools/moui/gpu_promotion_scaffold --target native   # 5/5
moon test tools/moui/validate_gpu_promotion_manifest --target native
node scripts/test-gpu-promotion-manifest-lib.mjs
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode full --skip-static-guard
  # exits 3 after writing full-plan/metrics template
node scripts/record-gpu-promotion-smoke.mjs --platform macos --mode short-smoke
  # shortPathOk=true, validate schema ok, gpuPromoted=false
node scripts/validate-gpu-worker-no-readback.mjs
```

## Explicit non-goals completed correctly

- Did **not** change `NativeGpuPlatform::gpu_promoted`.
- Did **not** make `auto` select GPU.
- Did **not** claim `--require-passed` promotion.

## Follow-up

- [x] macOS present-to-present performance harness (`MOUI_MACOS_SKIA_PERF_*`,
      `scripts/run-macos-gpu-performance-smoke.mjs`, metrics merge).
- [x] Fix `--run-gpu-smoke --write-local-config` so Metal/Ganesh flags can be
      persisted; continuous `request_platform_redraw` for performance sampling.
- [x] Local Metal GPU performance run completed with
      `surface_route=metal-gpu; surface_gpu=true; gpu_context=worker-owned;
      present_kind=host-gpu-surface`.
- [x] **600s Metal performance gate PASSED** (detached run
      `artifacts/gpu-promotion/macos/perf-gpu-600s-live/`):
      duration≈600.05s, samples=59873, p95≈10.96ms (≤16.7),
      dropped≈0.63% (<1%), input proxy≈0.66 VSync (≤2).
      `adrPerformanceGatePass=true`. Still `gpuPromoted=false`.
- [x] Long-run reliability: streaming logs, 5s checkpoints, measure-window
      after warm-up, detached launcher `scripts/run-macos-gpu-perf-detached.sh`.
- [x] Remaining lifecycle gates harnessed on macOS (`--promotion-lifecycle`):
      100 surface recreate, 100 fg/bg, context-loss inject, mailbox/readback
      flags, runtime preserve.
- [x] Full matching-host claim validated:
      `artifacts/gpu-promotion/macos/promotion-full-600s/gpu-promotion-claim.json`
      with `--require-passed`.
- [x] Flipped `NativeGpuPlatform::Macos.gpu_promoted() = true` and ADR 0006
      promotions table. Other platforms remain `false`.
- [ ] Repeat per platform (Web, iOS, Android, HarmonyOS, Windows, Linux).
