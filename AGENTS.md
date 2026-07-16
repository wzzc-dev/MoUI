# MoUI Agent Guide

First stop for contributors and AI agents. For task-specific workflows:

- `skills/moui-app-development/SKILL.md` — shared app packages, examples, platform entrypoints.
- `skills/moui-framework-development-skill/SKILL.md` — framework internals, public API, runtime/backend/renderer, maintenance ratchets, smoke gates.

## Read First (10 min)

| Document | Read when |
|----------|-----------|
| `docs/architecture.md` | always — package map and runtime pipeline |
| `docs/moui-app-package-boundary.md` | always — app-safe dependency rules |
| `docs/invariants.md` | always — every structural constraint in one table |
| `docs/development.md` | setup and workspace workflow |
| `docs/testing.md` | validation commands and focused loops |
| `docs/mobile-mainline-roadmap.md` | touching Android/iOS/HarmonyOS |
| `docs/button-styling-guide.md` | changing button colors or styles |
| `docs/decisions/` | architectural changes |
| `docs/ai-sessions/` | past AI session summaries |

## Core Rules (summary — see `docs/invariants.md` for full table)

- **App logic** → `examples/<name>/app`; platform entrypoints → thin wiring.
- **New controls** → `moui/views` (use `@core.View::node`; no new core enum variants).
- **Cross-runtime protocols** → `moui/core`. **Runtime lifecycle** → `moui/runtime`.
- **Host contracts** → `moui/backend/host`. **Renderer code** → `moui/render/*`.
- **App dependencies**: `@moui.*` + domain facades + `views` only. No direct deps on `runtime`, `render/*`, or platform backends.
- **Mainline**: Native Skia. **Diagnostic**: Native WGPU. Do not reclassify without RFC.
- **Mobile**: embedded-session routes; product class is `runtime_partial`
  (usable managed shell + host path; not product-complete). Product `auto`
  default is `SkiaGpuNative` when the host GPU surface is available;
  `SkiaRasterNative` is explicit/recovery fallback. See
  `docs/platform-readiness-declaration.md` and ADR 0011.
- **Mobile shells**: managed builds stage package-owned Kotlin/AndroidX,
  SwiftUI, or ArkTS/XComponent canonical shells. App-owned native projects are
  versioned ejected shells or explicit Release N legacy fixtures only.
- **API discovery**: `moon ide doc` / `outline` / `peek-def` / `find-references` before inventing names.
- **`moon.work`**: no `./window` (use `window-dev-mode.sh on/off`), no `./openseek`.

## Pre-push

```sh
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
```

For core/view/render/backend changes, also run `sh scripts/check.sh --profile daily`.

For platform behavior: `sh scripts/check.sh --profile platform`.
For theme changes: `sh scripts/check.sh --profile theme`.

Design Systems is addon diagnostic coverage; run the theme profile for it.
The Windows check wrapper plan and shared platform service checks are tracked
in `docs/testing.md` and `checks/profiles.json`.

## Script Tooling Policy

Repository validators should use MoonBit-backed tools where practical; keep
Node for browser/CDP, Web smoke, HTTP, and artifact orchestration. The
`rule`/`dev_build` helpers are only for deterministic package generation, not
dependency installation or smoke execution.

Mobile sessions share `MobileHostChannel`. Native XComponent callbacks are the only
surface/pointer/resize/detach source on HarmonyOS.

## Manual Smoke (real platform/renderer evidence)

```sh
scripts/macos-skia-renderer-smoke.sh
sh scripts/ci-web-runtime-presentation.sh
scripts/run-window-package-smoke.sh <macos|web|windows|linux> --run
```

## Docs & Artifacts

- Root `docs/` is the source of truth. Sync website with `node scripts/sync-website-docs.mjs`.
- Do not commit `artifacts/`. Cite CI runs or smoke logs in release notes instead.
- After significant sessions, update `memories/repo/` (quick facts), `docs/decisions/` (ADRs), `docs/ai-sessions/` (session logs).
