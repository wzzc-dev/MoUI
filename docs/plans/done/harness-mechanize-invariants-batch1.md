# Plan: Mechanize invariants batch 1 (harness)

- **Status**: done (implementation complete; move to `docs/plans/done/` when convenient)
- **Goal**: Turn the highest-frequency “code review” invariants into machine checks with agent-facing fix hints, and align agent entry docs with harness-engineering progressive disclosure.
- **Non-goals**: Full mobile semantic proof automation; rewriting all of `docs/architecture.md`; changing product renderer defaults.

## Context

OpenAI harness-engineering lesson applied to MoUI: discipline lives in
structure, tools, and feedback loops—not longer manuals. MoUI already had
`validate-maintenance-baseline`, provider manifests, and guidance consistency.
Batch 1 closed the largest agent-blind gaps where Detection was still
“code review”.

## Delivered

- [x] `AGENTS.md` rewritten as short map + task router (guidance tokens preserved)
- [x] `docs/INDEX.md` progressive-disclosure catalog
- [x] `docs/architecture-map.md` one-page dependency map
- [x] `docs/golden-principles.md`
- [x] Plans layout + session promote checklist + ai-collaboration router workflow
- [x] **A6** window pin: `validate-window-dependency.mjs` (+ Fix/See anchors)
- [x] **M5** Harmony shell: `validate-harmonyos-m5-shell.mjs` on pr profile
- [x] **P1/P2/R3/G1/G2**: `scripts/validate-harness-batch1.mjs` on pr profile

## Batch 1 — status

| ID | Status | Tool surface |
|---|---|---|
| **P1** | DONE | `validate-harness-batch1.mjs` — entry size/file count + no product `update`/`view`/`Model`/`Msg` in entrypoints; requires `app/` or root `app.mbt` |
| **P2** | DONE | `validate-harness-batch1.mjs` — forbid `pub enum View` and control constructors in `moui/core` (mbti + sources) |
| **A6** | DONE | `validate-window-dependency.mjs` — four consumers share `wzzc-dev/window@…` |
| **R3** | DONE | `validate-harness-batch1.mjs` — desktop providers read `MOUI_SKIA_RENDERER`; mobile entries expose configure/selection; `prepare-native-build --renderer` |
| **M5** | DONE | `validate-harmonyos-m5-shell.mjs` (+ managed-shell node tests) |
| **G1** | DONE | `validate-harness-batch1.mjs` — skills must not re-list ≥3 P-rows |
| **G2** | DONE | `--json` on batch1 (+ M5 already supports `--json`) |

### Already mechanical (pre-batch1)

| ID | Detection |
|---|---|
| P8, P9, R5 | `validate-maintenance-baseline.mjs` |
| R2 | `validate-renderer-provider-manifests.mjs` |
| R4 | `validate-window-dependency.mjs` |
| R6, M7 | `validate_mobile_runtime_manifest` |
| A1, A2 | `moon check` |

## Acceptance

- [x] `docs/invariants.md` Detection column updated for shipped IDs
- [x] `node scripts/validate-guidance-consistency.mjs` passes
- [x] Checks on `checks/profiles.json` `pr` (window, M5, harness batch1)
- [x] Failure output includes Fix + `docs/invariants.md#…`
- [x] No growth of always-read surface in `AGENTS.md`

## Commands

```sh
node scripts/validate-window-dependency.mjs
node scripts/validate-harmonyos-m5-shell.mjs
node scripts/validate-harness-batch1.mjs
node scripts/validate-harness-batch1.mjs --json
node scripts/validate-check-profiles.mjs
node scripts/validate-guidance-consistency.mjs
```

## Decision log

| Date | Decision |
|---|---|
| 2026-07-16 | Prefer extending existing MoonBit validators over new Node-only logic where practical; batch1 residual rules shipped as one Node tool for speed |
| 2026-07-16 | Keep mobile full evidence path-triggered; batch 1 is static structure only |
| 2026-07-16 | AGENTS.md remains token-compatible with `validate_guidance_consistency` |
| 2026-07-16 | P1 allows root `app.mbt` when `app/` package is absent (agent_counter) |
| 2026-07-16 | R3 checks providers + mobile ABI configure path rather than duplicating desktop CLI in every thin entry |

## Progress

| Date | Note |
|---|---|
| 2026-07-16 | Harness map docs landed |
| 2026-07-16 | A6 Fix anchors + M5 pr gate |
| 2026-07-16 | P1/P2/R3/G1/G2 via `validate-harness-batch1.mjs`; plan complete |
