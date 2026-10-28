# 2026-10-27: ADR 0044 L0 — instrument the renderer route, then stop it

- **Agent**: Qoder Desktop agent (main session, MoonBit-native work)
- **Goal**: The user asked whether MoUI could drop third-party graphics libraries and
  drive the GPU directly (gpui / nanoui shape), and named the boundary: OS frameworks
  allowed, external graphics libraries not. Then: "做这两项" — L0.2 extract the neutral
  native text model, L0.1 make the perf harness provider-parametric.
- **Outcome**: Success for the two items; the route itself stays parked at L0 because
  the kill gate fired on the performance branch (→ ADR 0044).

## Summary

L0.2 moved the renderer-neutral native text model out of the wgpu-importing package
into `moui/render/native_text`, so `coretext` and `text_protocol` no longer import
`wzzc-dev/moui_wgpu_renderer`. L0.1 made the performance-budget harness drive frames
through the `RendererProvider` contract under `MOUI_PERFORMANCE_PROVIDER`, keeping the
concrete Skia path as the only budget-gated runner. That produced the first non-Skia
frame numbers in this repo's history, which answered the kill gate's untested branch
negatively and closed L0 without any drawing code.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui/render/native_text` | New package (`NativeTextEngine` + model), imports `moui/core` only | Providers must not depend on a concrete renderer to shape text |
| `moui_wgpu_renderer/*` | Re-exports the moved names with `pub using`; `native_text_model.mbt` −244 lines, validation/provider-engine files deleted | Published surface unchanged in name, dependency edge removed |
| `benchmarks/performance_budget/native/main.mbt` | `PerfFramePump` + three pumps (concrete / neutral / sun), provider-aware runner labels, identity asserts | Route decisions need a provider-parametric instrument |
| `scripts/run-performance-budgets.mjs` | `--provider`, gated-vs-control artifact paths, control runs skip budget validation | New runner must not re-price committed baselines |
| `checks/profiles.json` | `native text model tests` step added to `pr` | The extracted package had zero profile coverage |
| `checks/performance-budgets.json`, `tools/moui/validate_performance_budgets/*` | `drawMs` / `totalMs` emitted and gated as 7 required metrics | Two stages were being dropped silently |
| `THIRD_PARTY.md` | L0.3 license/notice fact sheet, unconfirmed items marked | License motive could not be confirmed, only notice completeness |
| `docs/testing.md`, plan `no-third-party-gpu-route.md`, ADRs 0043/0044, `memories/repo/renderer-route-economics.md` | Control-run rule, measurements, verdicts | Single source for the route decision |

## Key Decisions

- Gate the *gated* runner on the concrete path — the provider factory sets
  `async_image_loading=true`, so swapping it would have re-priced every committed
  `native-skia-raster` baseline as a side effect of an instrument change.
- Control runs (`skia-neutral`, `sun`) emit their own runner identity and are never
  budget-validated (→ `docs/testing.md`).
- Leave `benchmarks/app_cached_layer` concrete, and refuse non-`skia` providers under
  the `metal-gpu` present modes, rather than emit mislabelled numbers.
- Do not enter L1. The surviving case (size versus Skia + autonomy) must be re-priced
  on its own; two of the three owner motives died in L0 (→ ADR 0044).

## Discoveries

- `RendererSession` exposes presentation counters but **no unsupported-command
  accessor**, so a neutral session can certify presentation, not completeness. The
  error direction is known: a skipped command understates cost, which makes sun's
  15–233× a floor.
- wgpu's bind closure rejects any surface without `native_surface()`, so no headless
  harness can ever produce a wgpu frame number.
- `packageBytes` was byte-identical (23,262,232) across all three runners because the
  benchmark binary links both renderers — a provider swap cannot measure
  provider-only size.
- `startupMs` is not an independent signal: the timer spans app construction, pump
  construction and the warmup frames.
- Run-to-run drift on this headless harness reaches +1.8–11.0% on the *same* runner, so
  an A/B must be far larger than a few percent to mean anything.
- `moon fmt <package>` regenerates its `_build` copy without writing the source back.

## Validation

```sh
moon test moui/render/native_text --target native          # 8/8
moon test moui_wgpu_renderer --target native               # 61/61 (+ providers, 150 total)
node scripts/run-performance-budgets.mjs                   # gated: ok (performance budgets)
node scripts/run-performance-budgets.mjs --provider skia-neutral
node scripts/run-performance-budgets.mjs --provider sun    # native-sun-raster numbers
node scripts/validate-maintenance-baseline.mjs             # + 5 other static validators
sh scripts/check.sh --profile pr                           # green
```

## Follow-Up

- [x] L0.1 / L0.2 delivered; L0 verdict recorded.
- [ ] A wgpu or Metal frame number requires a real window — different instrument
      (`scripts/macos-skia-renderer-smoke.sh` shape), not this runner.
- [ ] `THIRD_PARTY.md` notice gaps (Skia root `LICENSE`, ICU terms) are ours to fill;
      unrelated to this route's fate.
- [ ] Re-price size-versus-Skia + autonomy before reopening L1.

## Promote

Durable facts went to `memories/repo/renderer-route-economics.md` (harness identity
rules, noise floor, the four limits above); the decision to `docs/decisions/0044-…`;
remaining work to `docs/plans/active/no-third-party-gpu-route.md`.
