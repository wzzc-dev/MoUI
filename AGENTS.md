# MoUI Agent Guide

Short map only. Deep rules live in `docs/`; do not treat this file as an encyclopedia.

Task skills:

- `skills/moui-app-development/SKILL.md` — examples, app packages, thin platform entrypoints
- `skills/moui-framework-development-skill/SKILL.md` — core/runtime/backend/render, gates, CI

Start at `docs/INDEX.md` for progressive disclosure.

## Hard boundaries (summary)

Full table: `docs/invariants.md`. Break only via RFC (`GOVERNANCE.md`).

- App logic → `examples/<name>/app`; platform entrypoints stay thin wiring.
- New built-in controls → concrete `@core.ViewNode` implementations in `moui/views`, constructed with `@core.View::from_node` (no new core view enum variants).
- Cross-runtime protocols → `moui/core`; lifecycle trees → `moui/runtime`; backend protocols/state → `moui/backend` / `moui/backend/common`; render protocols/algorithms → `moui/render` / `moui/render/common`; concrete renderers live in independent `moui_*_renderer` modules.
- Release closure: `wzzc-dev/moui` must not depend on concrete renderers, renderer bindings, diagnostic renderer stacks, or integration-test libraries. Composition roots declare their selected renderer module explicitly.
- App deps: `wzzc-dev/moui` + domain facades + `views` only (no `runtime` / `render/*` / platform backends).
- Mainline: Native Skia. Diagnostic: Native WGPU. Reclassify only with RFC.
- Embedded-runtime product class: `experimental` (`ready=false`; code compiles, no usability/product commitment without matching-device evidence); `wzzc-dev/window` hosted entrypoints are canonical. Details: `docs/platform-readiness-declaration.md`, ADR 0021.
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
| `moui/backend`, `moui/backend/common`, platform backend | `docs/platform-host-contract.md`, platform notes | framework | root/common + affected backend tests |
| `moui/render`, `moui/render/common`, `moui_*_renderer`, `moui_skia` | `docs/renderer-capability-report.md`, `moui_skia/AGENTS.md` | framework | root/common + affected renderer tests |
| Android / iOS / HarmonyOS embedded runtime backends | `docs/window-hosted-moui.md`, platform support doc | framework | path-triggered window-hosted evidence (not default daily) |
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
| `checks/release-modules.json` | Published module directory/stage catalog |
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
node scripts/validate-release-module-closures.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-renderer-capability-consistency.mjs
node scripts/validate-doc-references.mjs
```

Profiles (catalog: `checks/profiles.json`; policy: `docs/testing.md`):

```sh
sh scripts/check.sh --profile pr
sh scripts/check.sh --profile daily
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile theme
```

## Linux RISC-V64 experimental route

Linux RISC-V64 is an architecture variant of the canonical `linux/skia` route,
recorded as `linux-skia-riscv64`, not a new platform route. The first slice
targets `riscv64-linux-gnu` with Skia Raster static linking and is limited to
non-blocking L0-L2 evidence. Use
`scripts/prepare-linux-riscv64-sysroot.sh` with the locked Ubuntu Base fixture,
then `scripts/linux-riscv64-cross-build.sh --sysroot PATH --run-qemu` for the
cross-build and renderer-owned QEMU smokes. Keep `ready=false` and do not raise
Linux Wayland L3 status without matching-device evidence.

Design Systems is addon diagnostic coverage; use the theme profile for it.
Windows check wrapper plan and shared platform service checks are tracked in
`docs/testing.md` and `checks/profiles.json`.

Manual / real presentation smoke (path-triggered, not default):

```sh
scripts/macos-skia-renderer-smoke.sh
sh scripts/ci-web-runtime-presentation.sh
scripts/run-window-package-smoke.sh <macos|web|windows|linux> --run
```

Smoke catalog: `node scripts/smoke-check.mjs --check`.

## Script Tooling Policy

Repository validators should use MoonBit-backed tools where practical; keep
Node for browser/CDP, Web smoke, HTTP, and artifact orchestration. The
`rule`/`dev_build` helpers are only for deterministic package generation, not
dependency installation or smoke execution.

Embedded runtime sessions share `EmbedderHostChannel`. Native XComponent callbacks are the only
surface/pointer/resize/detach source on HarmonyOS.

## When the agent is stuck

Do not “try harder” with a longer prompt. Ask: what capability, invariant, tool,
or doc is missing—and add that to the repo (plan → invariant/validator → skill
pointer). After significant sessions: update `memories/repo/`, ADRs, and
`docs/ai-sessions/` as appropriate.
