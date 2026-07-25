# MoUI Agent Guide

Short map only. Deep rules live in `docs/`; do not treat this file as an encyclopedia.

Task skills:

- `skills/moui-app-development/SKILL.md` — examples, app packages, thin platform entrypoints
- `skills/moui-framework-development-skill/SKILL.md` — core/runtime/backend/render, gates, CI

Start at `docs/INDEX.md` for progressive disclosure.

## Hard boundaries (summary)

Full table: `docs/invariants.md`. Break only via RFC (`GOVERNANCE.md`).

- App logic → `examples/<name>/app`; platform entrypoints stay thin wiring.
- New controls → `moui/views` via `@core.View::node` (no new core view enum variants).
- Protocols → `moui/core`. Lifecycle trees → `moui/runtime`. Host contracts → `moui/backend/host`. Renderers → `moui/render/*`.
- App deps: `wzzc-dev/moui` + domain facades + `views` only (no `runtime` / `render/*` / platform backends).
- Mainline: Native Skia. Diagnostic: Native WGPU. Reclassify only with RFC.
- Mobile product class: `runtime_partial`; `wzzc-dev/window` hosted entrypoints are canonical. Details: `docs/platform-readiness-declaration.md`, ADR 0011.
- `moon.work`: no local `./window/modules/window*` members by default (use
  `window-dev-mode.sh on/off`), no `./openseek`.
- Discover APIs with `moon ide doc` / `outline` / `peek-def` / `find-references` before inventing names.

## Task router (read only what you need)

| Change surface | Read | Skill | Minimal loop |
|---|---|---|---|
| `examples/*/app`, entrypoints | `docs/moui-app-package-boundary.md`, `docs/examples.md` | app | `moon test examples/<name>/app --target native` |
| `moui/views`, controls, styles | `docs/view-catalog.md`, `docs/button-styling-guide.md` if buttons | framework | `moon test moui/views --target native` |
| `moui/core` contracts | `docs/architecture-map.md`, `docs/invariants.md` | framework | `moon test moui/core --target native` + `moon info` if public API |
| `moui/runtime` | `docs/architecture-map.md`, `docs/tea-program-model.md` | framework | `moon test moui/runtime --target native` |
| `moui/backend/host` or platform host | `docs/platform-host-contract.md`, platform notes | framework | `moon test moui/backend/host --target native` + affected backend tests |
| `moui/render/*`, `moui_skia` | `docs/renderer-capability-report.md`, `moui_skia/AGENTS.md` | framework | package tests + capability report if status changes |
| Android / iOS / HarmonyOS | `docs/window-hosted-moui.md`, platform support doc | framework | path-triggered window-hosted evidence (not default daily) |
| Theme / `moui_theme` / design systems | `docs/visual-theme-system.md` | framework | `sh scripts/check.sh --profile theme` |
| Docs / guidance only | `docs/INDEX.md`, topic page | — | `node scripts/validate-guidance-consistency.mjs` |
| Architecture / package graph | `docs/architecture-map.md` then `docs/architecture.md` | framework | + plan under `docs/plans/active/` if multi-package |

Complex multi-package or platform work: write/update `docs/plans/active/<id>.md` before coding.

## Repo map

| Path | Role |
|---|---|
| `docs/INDEX.md` | Catalog + where to read next |
| `docs/moonbitlang` | MoonBit language documentation index |
| `docs/architecture-map.md` | One-page package/dependency map |
| `docs/invariants.md` | Sole structural constraint source |
| `docs/testing.md` | Sole validation policy source |
| `docs/plans/` | Exec plans (`active` / `done` / `debt`) |
| `docs/decisions/` | ADRs |
| `docs/ai-sessions/` | Session logs (promote facts to `memories/repo/`) |
| `checks/profiles.json` | Check profile catalog |
| `smoke/gates.json` | Smoke suite catalog |
| `scripts/check.sh` | Primary check facade (`pr` / `daily` / `platform` / `theme`) |
| `skills/` | Task workflows |
| `memories/repo/` | Short durable agent facts |

Generated evidence stays out of git: do not commit `artifacts/`. Root `docs/` is source of truth; website sync via `node scripts/sync-website-docs.mjs`.

## Validation facade

Prefer the smallest loop from the router. Do not start small package edits with full daily/platform.

Pre-push static trio (every commit that touches guidance, API, or package layout):

```sh
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
```

Profiles (catalog: `checks/profiles.json`; policy: `docs/testing.md`):

```sh
sh scripts/check.sh --profile pr
sh scripts/check.sh --profile daily
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile theme
```

Design Systems is addon diagnostic coverage; use the theme profile for it.
Windows check wrapper plan and shared platform service checks are tracked in
`docs/testing.md` and `checks/profiles.json`.

Manual / real presentation smoke (path-triggered, not default):

```sh
scripts/macos-skia-renderer-smoke.sh
sh scripts/ci-web-runtime-presentation.sh
scripts/run-window-package-smoke.sh <macos|web|windows|linux> --run
```

Smoke catalog: `node scripts/smoke-gate.mjs --tier nightly --dry-run --json`.

## Script Tooling Policy

Repository validators should use MoonBit-backed tools where practical; keep
Node for browser/CDP, Web smoke, HTTP, and artifact orchestration. The
`rule`/`dev_build` helpers are only for deterministic package generation, not
dependency installation or smoke execution.

Mobile sessions share `EmbedderHostChannel`. Native XComponent callbacks are the only
surface/pointer/resize/detach source on HarmonyOS.

## When the agent is stuck

Do not “try harder” with a longer prompt. Ask: what capability, invariant, tool,
or doc is missing—and add that to the repo (plan → invariant/validator → skill
pointer). After significant sessions: update `memories/repo/`, ADRs, and
`docs/ai-sessions/` as appropriate.
