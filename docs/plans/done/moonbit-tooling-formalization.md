# Plan: MoonBit tooling formalization

- **Status**: done
- **Goal**: Move formalizable, `moon test`-able repository knowledge into
  `tools/moui` MoonBit packages. Keep other languages as host/orchestration shells
  only (Node for CDP/HTTP/process spawn, sh/ps1 for env/platform dispatch, C/Kotlin/
  Swift/ETS for OS/mobile shells).
- **Non-goals**:
  - Rewriting browser CDP / Web smoke runners in MoonBit
  - Replacing embedded-runtime templates or native presenters
  - Using MoonBit to install MSVC/SDK/toolchains
  - Big-bang deletion of every `scripts/*.mjs` in one PR

## Policy (already canonical)

- `AGENTS.md` / `docs/development.md` / `docs/testing.md`: prefer MoonBit for
  repository rules, static validation, structure scans, deterministic generators.
- Keep `node scripts/*.mjs` as thin `runMoonbitTool` wrappers when CI/docs depend
  on those paths.
- Wrapper budgets live in
  `tools/moui/validate_maintenance_baseline/moonbit_tool_wrapper_budget.mbt`.

## Classification

| Bucket | Examples | Target |
|---|---|---|
| A. Pure rules / schema / generators | GPU worker no-readback, feature-proof report/coverage, package/API/guidance validators (many done) | Logic in `tools/moui/*`; thin JS wrapper |
| B. Hybrid smoke | `record-web-runtime-presentation.mjs`, mobile smoke recorders | Keep Node I/O; extract schema/assertions to MoonBit over time |
| C. Host/orchestration only | CDP, HTTP, GitHub artifacts, sh/ps1 env, Gradle/hvigor/Xcode | Stay non-MoonBit |
| D. Platform product shells | Kotlin/Swift/ETS/C/C++/ObjC presenters | Stay platform languages |

## Acceptance

- [x] Active inventory of remaining Bucket A scripts documented in this plan
- [x] Batch 1 migrated with tests:
  - [x] `validate_gpu_worker_no_readback`
  - [x] `verify_feature_proof_coverage`
  - [x] `generate_feature_proof_report`
- [x] Batch 3 migrated with tests:
  - [x] `validate_harness_invariants` (P1/P2/R3/G1)
- [x] Batch 4 migrated with tests:
- [x] Batch 5 migrated with tests:
  - [x] `generate_grapheme_property_data`
  - [x] `generate_grapheme_break_fixtures`
- [x] Batch 6 migrated with tests:
  - [x] `refresh_evidence_table` (formal report assembly)
- [x] Batch 7 migrated with tests:
  - [x] `sync_website_docs` (catalog validation + robots/sitemap + docs sync)
- [x] Batch 8 migrated with tests:
  - [x] `conformance_capture_scaffold` (manifest generation)
  - [x] `interpret_macos_gpu_smoke_log` (GPU short-smoke heuristics)
  - [x] `window_dependency_info` (window pin query)
- [x] Batch 9 migrated with tests:
  - [x] `claim_macos_gpu_promotion` (ADR gate evaluation + claim assembly)
- [x] Thin JS wrappers call `runMoonbitTool`; no reintroduced FS rule logic
- [x] `moon test tools/moui/<batch1+2+3> --target native` passes
- [x] Wrapper budget includes new `validate-*.mjs` thin wrappers
- [x] Docs/guidance still point at stable `node scripts/...` entrypoints

## Remaining after Batch 8 (mostly hybrid I/O)

Pure Bucket A validators/generators targeted earlier are largely done.
What remains is predominantly **hybrid smoke/orchestration** (CDP, device,
process runners) where only additional assertion kernels can still move:

## Earlier Bucket A candidates (status)

| Script | Notes |
|---|---|
| ~~`validate-harness-invariants.mjs`~~ | **Done** → `tools/moui/validate_harness_invariants` |
| ~~`generate-grapheme-*.mjs`~~ | **Done** → `tools/moui/generate_grapheme_property_data` + `generate_grapheme_break_fixtures` |
| ~~`refresh-evidence-table.mjs`~~ | **Done** → `tools/moui/refresh_evidence_table` (table/report pure; Node shell keeps GitHub/gh fetch) |
| ~~`sync-website-docs.mjs` catalog rules~~ | **Done** → `tools/moui/sync_website_docs` (validate+generate+write/check) |
| ~~`conformance-capture-scaffold.mjs`~~ | **Done** → `tools/moui/conformance_capture_scaffold` (manifest body); shell keeps moon build orchestration |
| ~~`window-dependency-info` / smoke log heuristics~~ | **Done** → `tools/moui/window_dependency_info` + `tools/moui/interpret_macos_gpu_smoke_log` |
| `platform-services-check.mjs` | Hybrid process runner (moon test + zip probe); keep Node orchestration |

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-16 | Prefer incremental migration of pure validators/generators first; keep smoke runners hybrid. |
| 2026-07-16 | Feature-proof report timestamp stays injectable from thin shell (`--timestamp`) so MoonBit logic stays pure/testable. |

## Progress

| Date | Note |
|------|------|
| 2026-07-16 | Plan created; Batch 1 implementation started. |
| 2026-07-16 | Batch 1 landed: GPU no-readback + feature-proof generate/verify in `tools/moui`; wrappers thin; 11/11 package tests pass. |
| 2026-07-16 | Batch 3 landed: harness P1/P2/R3/G1 → `tools/moui/validate_harness_invariants` (5/5 tests; real repo scan OK). |
| 2026-07-16 | Batch 5 landed: grapheme property/fixture generators → MoonBit tools with thin JS wrappers. |
| 2026-07-16 | Batch 6 landed: evidence table report assembly → `tools/moui/refresh_evidence_table`; Node retains GitHub/gh fetch shell. |
| 2026-07-16 | Batch 7 landed: website docs catalog validation/sync → `tools/moui/sync_website_docs`; JS wrapper thin. |
| 2026-07-16 | Batch 8 landed: conformance scaffold body + macOS GPU smoke log heuristics + window dependency pin query → MoonBit; Node keeps build/process shells. |
| 2026-07-16 | Batch 9 landed: macOS GPU promotion claim gate evaluation/assembly → `tools/moui/claim_macos_gpu_promotion`. |


## Status after Batch 9

Formalizable Bucket A work targeted by this plan is **complete** (through Batch 9):

- static validators / generators live under `tools/moui/*`
- stable `node scripts/*` entrypoints remain as thin shells or hybrid I/O orchestrators

### Intentionally remaining non-MoonBit (Bucket B/C)

These are host/orchestration shells, not formal knowledge kernels:

- CDP / browser / device smoke recorders (`record-web-runtime-presentation.mjs`, `moui verify`, …)
- packaging / npm / wasm asset assembly (`generate-playground-assets.mjs`, `web-bundle-tools.mjs`)
- process runners and CI glue (`claim-macos-gpu-promotion.mjs`, `external-consumer-ci.mjs`, `lint-scripts.mjs`)
- JS integration tests (`test-*.mjs`) that exercise the thin shells

Further MoonBit work here should only extract additional pure assertion kernels if new formal rules appear inside those hybrids.


## Final residual pure-rule scan (Batch 9)

Scanned remaining thick scripts that still lack `runMoonbitTool` as primary logic
owners. Classification:

| Script | Pure formal rules left? | Disposition |
|---|---|---|
| `claim-macos-gpu-promotion.mjs` | Yes (gate thresholds + claim JSON) | **Migrated** → `tools/moui/claim_macos_gpu_promotion`; JS thin shell + optional validator call |
| `generate-playground-assets.mjs` | Mostly packaging constants + graph walk tightly coupled to npm/`_build` IO | **Intentional hybrid shell** (npm pack, tar, moon bundle, file copy) |
| `web-bundle-tools.mjs` | Size measurement uses zlib; path helpers tied to build outputs | **Intentional hybrid shell** (moon build + gzip/brotli + FS) |
| `record-*-smoke.mjs` / CDP runners | Assertions already call MoonBit validators where formal | **Intentional hybrid shell** (browser/device/process) |
| `external-consumer-ci.mjs`, `lint-scripts.mjs`, `check.mjs` | Orchestration only | **Intentional hybrid shell** |
| `test-*.mjs` | Integration tests of shells | **2026-08 修订**:validator 自测已删除(见 `docs/plans/active/validation-hygiene-cleanup.md`);仅保留产品行为/构建测试(浏览器运行时、DOM 语义、WebGPU、Canvas2D fallback、prebuild、打包产物) |

### Intentional non-goals (host/orchestration)

Hybrid smoke I/O shells (CDP, device, process runners, npm/wasm packaging) are
**not** incomplete Bucket A work. They are the host/orchestration layer required by
`docs/development.md` / `docs/testing.md`. Further MoonBit extraction is only
warranted if new formal schema/assertion kernels appear inside them.

### Acceptance for the objective

- [x] All identified formalizable, moon-testable repository rules/generators from
  the active plan are in `tools/moui/*`
- [x] Stable script entrypoints remain as thin wrappers or hybrid I/O shells
- [x] Residual thick scripts re-scanned; no additional pure Bucket A kernels found
  beyond Batch 9 claim migration
- [x] Hybrid smoke/packaging shells documented as intentional non-goals
