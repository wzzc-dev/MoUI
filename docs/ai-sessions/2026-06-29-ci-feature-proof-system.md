# 2026-06-29: CI Feature Proof System

- **Agent**: Trae AI
- **Goal**: Establish a "CI pass = feature proven" system with layered proof (L1: package tests, L2: real-Skia platform smoke, L3: cross-platform consistency) and a summary workflow.
- **Outcome**: Success (new PR smoke workflow, summary workflow, proof matrix docs, and verification scripts implemented)

## Summary

Created a three-layer feature proof system. L1 (package tests) runs on every PR via `ci.yml`. L2 (real-Skia platform smoke) runs only when `moui_skia/**` changes, adding macOS/Linux/Windows real-Skia pixel verification on PRs. A `feature-proof-summary.yml` workflow collects all job statuses and generates a proof report. Documentation includes `docs/feature-proof-matrix.md` (feature→CI mapping) and `docs/feature-status-dashboard.md` (current status).

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `.github/workflows/moui-skia-real-skia-pr-smoke.yml` | New workflow | L2 proof: 3-platform real-Skia smoke on `moui_skia/**` PR changes |
| `.github/workflows/feature-proof-summary.yml` | New workflow | Aggregate L1+L2 status into proof report |
| `scripts/generate-feature-proof-report.mjs` | New script | Generate `proof-report.json` and `proof-report.md` from CI job statuses |
| `scripts/verify-feature-proof-coverage.mjs` | New script | Validate required features have passing proof jobs |
| `docs/feature-proof-matrix.md` | New doc | Feature→CI job mapping with trigger conditions |
| `docs/feature-status-dashboard.md` | New doc | Current feature status matrix, follow-up tracking, evidence index |
| `docs/testing.md` | Updated | Added "Feature Proof Matrix" section link |
| `AGENTS.md` | Updated | Added proof matrix links to Validation section |
| `docs/renderer-capability-report.md` | Updated | Added dashboard link |
| `docs/roadmap-2026.md` | Updated | Added dashboard link to "Workstream 4" |

## Key Decisions

- **Paths-filtered L2**: Only trigger real-Skia smoke when `moui_skia/**` changes.
  Non-Skia PRs complete in ~5 min (L1 only).
- **Independent workflow file**: New `moui-skia-real-skia-pr-smoke.yml` does not
  modify `ci.yml`.
- **Release provider**: Use prebuilt Skia binary to avoid 90-min source build.
- **`workflow_run` trigger**: `feature-proof-summary.yml` fires after `ci.yml`
  completes.
- **`skiaSmokeTriggered` flag**: When `moui_skia` is unchanged, L2 features are
  marked `skipped` (not `gap`).
- **L1 + L2 parallel**: Skia PRs get both workflows in parallel (~30 min total).

## Discoveries

- `workflow_run` events only trigger from the default branch — PR testing
  workflows must be verified on `main` after merge.
- `paths` filter for PR events only applies to the PR's head branch — changes to
  workflow files themselves should also be included to test workflow changes.

## Validation

```sh
moon check
node scripts/validate-api-surface.mjs
node scripts/validate-maintenance-baseline.mjs
sh scripts/dev-check.sh
node scripts/smoke-gate.mjs --tier release --dry-run --json
node scripts/sync-website-docs.mjs --check
```

## Follow-Up

- [ ] Verify `feature-proof-summary.yml` triggers correctly after `ci.yml` completes on main.
- [ ] Create a non-Skia PR to confirm L2 workflow does not trigger.
- [ ] Create a Skia PR to confirm L2 workflow triggers and 3 platforms run in parallel.
