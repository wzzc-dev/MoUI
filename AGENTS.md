# MoUI Agent Guide

Use this file as the first stop for AI/code agents working in this repository.
For task-specific workflows, use the repo-local skills:

- `skills/moui-app-development/SKILL.md` for shared app packages, examples, and
  platform entrypoints.
- `skills/moui-framework-development-skill/SKILL.md` for framework internals,
  public API, runtime/backend/renderer work, maintenance ratchets, and smoke
  gates.

## Read First

- `docs/architecture.md` for the current package map and runtime pipeline.
- `docs/moui-app-package-boundary.md` for app-safe package dependencies and
  owning-package rules.
- `docs/development.md` for setup, workspace members, docs sync, and focused
  development loops.
- `docs/testing.md` for the daily validation script, focused checks, and manual
  smoke commands.
- `docs/release-readiness.md` for release gates, smoke gate catalog policy, and
  artifact policy.

## Working Rules

- Keep shared app logic in `examples/<name>/app`; keep platform entrypoints thin.
- Ordinary app packages should default to `wzzc-dev/moui` and
  `wzzc-dev/moui/views`.
- Put new controls, control styles, form/navigation/data helpers, and default
  app-facing themes in `moui/views`.
- Put neutral cross-runtime protocols and value types in `moui/core`.
- Put runtime lifecycle, element/layout/render tree execution, effects,
  subscriptions, and diagnostics in `moui/runtime`.
- Put host service contracts in `moui/backend/host`; put concrete platform
  behavior in the platform backend packages.
- Keep native Skia mainline work on the Skia route. Treat native WGPU as
  diagnostic unless the request explicitly changes that policy.
- Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
  `moon ide find-references` for MoonBit API discovery before inventing names.

## Validation

Use focused tests while editing. Before handoff, prefer the daily validation
script:

```sh
sh scripts/dev-check.sh
```

The daily validation script includes `moon check`, maintenance baseline guards,
API surface guards, smoke catalog validation, core/view/render/backend package
tests, `moui_tester`, `moui_devtools`, Showcase and Markdown Editor app tests,
and Web wasm-gc builds.

Use these additional checks when relevant:

```sh
node scripts/validate-api-surface.mjs
moon info
node scripts/smoke-check.mjs --check
node scripts/smoke-gate.mjs --tier release --dry-run --json
sh scripts/dev-check.sh --theme-diagnostics
```

Design Systems is addon diagnostic coverage. Run `--theme-diagnostics` when
changing `moui_theme` or `examples/design_systems`.

## Manual Smoke

Manual smoke is required for real platform/browser/renderer claims. Choose the
smallest matching host smoke:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
sh scripts/ci-web-runtime-presentation.sh
scripts/run-window-package-smoke.sh <macos|web|windows|linux> --run
```

`smoke/gates.json` is the smoke gate catalog. `scripts/smoke-gate.mjs` previews
or runs catalog suites, and `.github/workflows/moui-runtime-smoke-gates.yml`
owns scheduled/manual runtime smoke in CI. Cite the relevant CI run, uploaded
artifact, or manual smoke log in release notes.

## Documentation

Root `docs/` is the source of truth. The website preview copy lives under
`website/web_wasm/docs/` and is generated with:

```sh
node scripts/sync-website-docs.mjs
node scripts/sync-website-docs.mjs --check
```

When workflow guidance changes, update `docs/`, this `AGENTS.md`, and the
relevant files under `skills/`. The guidance consistency guard checks these
surfaces.

## Artifact Policy

Do not commit artifacts/. Generated logs, screenshots, manifests, and benchmark
scaffolds under `artifacts/` are disposable local or CI evidence. Release notes
should cite the CI run or smoke log that was actually inspected.
