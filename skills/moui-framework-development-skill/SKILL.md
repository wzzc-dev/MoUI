---
name: moui-framework-development-skill
description: Change MoUI framework internals and repository quality gates. Use when modifying moui/core, moui/views, moui/runtime, backend/host, platform backends, renderers, moui_skia, moui_theme, public API, pkg.generated.mbti, maintenance baselines, smoke/gates.json, scripts, CI workflows, docs, AGENTS.md, or repo-local skills.
---

# MoUI Framework Development

Use this skill for framework-layer changes. Preserve package ownership, public
API reviewability, and validation gates.

## Start Here

Read only what the task needs:

- `docs/architecture.md` for package roles and target routes.
- `docs/moui-app-package-boundary.md` for owning-package rules.
- `docs/development.md` for setup and focused package commands.
- `docs/testing.md` for Daily check, focused checks, and Manual smoke.
- `docs/release-readiness.md` for release gates and smoke catalog policy.
- `moui_skia/AGENTS.md` before changing `moui_skia` native/fallback binding
  ownership.

## Ownership Rules

- `moui/core`: cross-runtime protocols and neutral value types only.
- `moui/views`: app-facing controls, control styles, default themes,
  form/navigation/data helpers, WebView facade, and concrete custom view
  behavior.
- `moui/runtime`: runtime lifecycle, element/layout/render trees, event
  dispatch, effects, subscriptions, diagnostics, inspector snapshots.
- `moui/backend/host`: host service protocols, window/timer/route sources,
  WebView protocol, async image service, accessibility/input/redraw contracts.
- `moui/backend/<platform>`: concrete platform hosts.
- `moui/backend/<platform>/skia`: native Skia mainline renderer providers.
- `moui/backend/<platform>/wgpu`: native WGPU diagnostic providers.
- `moui/render`: renderer facade and renderer-neutral capability/fallback
  planning.
- `moui/render/skia`: native Skia renderer facade over `moui_skia`.
- `moui/render/webgpu_adapter`: browser WebGPU host-import adapter for
  `wasm-gc`.
- `moui/render/wgpu`: experimental native WGPU renderer.
- `moui_skia`: Skia binding, native capability manifests, fallback parity, FFI
  ownership, and native smoke marker coverage.
- `moui_theme`: optional design-system addon diagnostics and theme builders.

Do not add a new public package until the existing owning packages cannot
naturally own the capability.

## Public API Workflow

1. Locate the owning package and inspect `moon.pkg`.
2. Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
   `moon ide find-references` before adding or renaming public symbols.
3. Add focused black-box tests for public behavior; use white-box tests only
   when private internals matter.
4. Run `moon info` after public API changes.
5. Review `pkg.generated.mbti` diffs and keep them committed when intended.
6. Run `node scripts/validate-api-surface.mjs`.

Use `#alias(old_api, deprecated)` only when compatibility is intentionally
preserved. The default for this repo is to keep public surface small and
owning-package boundaries clear.

## Daily Check

Before handoff, prefer the Daily check:

```sh
sh scripts/dev-check.sh
```

It includes:

```sh
node scripts/validate-guidance-consistency.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/smoke-check.mjs --check
moon check
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render/skia --target native
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test moui_tester --target native
moon test moui_devtools --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Use focused tests during implementation, then run the full daily script when
possible.

## Maintenance Ratchets

Run:

```sh
node scripts/validate-maintenance-baseline.mjs
```

when changing file organization, public facade size, `pub(all)` exposure, test
file sizes, or package boundaries. If a refactor reduces a budget, ratchet the
baseline down in the same change. If a budget grows, explain why in review.

## Renderer And Backend Work

- Native Skia is the native mainline. Keep Skia provider wiring, renderer tests,
  `moui_skia` capability contracts, and docs in sync.
- Web rendering goes through `moui/backend/web` and
  `moui/render/webgpu_adapter` on `wasm-gc`.
- Native WGPU is diagnostic; keep it opt-in through `--wgpu-experimental`.
- Text changes often span `moui/core`, `moui/render/skia`,
  `moui/render/webgpu_adapter`, optional native WGPU text providers, and
  `docs/text-system.md`.
- Platform behavior claims require matching-host tests or manual smoke.

## Manual Smoke

Manual smoke is required for real renderer/browser/platform claims:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
sh scripts/ci-web-runtime-presentation.sh
scripts/run-window-package-smoke.sh <macos|web|windows|linux> --run
```

`smoke/gates.json` is the smoke gate catalog. Use:

```sh
node scripts/smoke-check.mjs --check
node scripts/smoke-gate.mjs --tier release --dry-run --json
```

before changing or running catalog-backed smoke. The CI owner for runtime smoke
is `.github/workflows/moui-runtime-smoke-gates.yml`.

## Docs And Skills

When workflow, package ownership, validation, examples, or smoke behavior
changes, update:

- `docs/`
- `AGENTS.md`
- `skills/moui-app-development/SKILL.md`
- `skills/moui-framework-development-skill/SKILL.md`
- `tools/moui/validate_guidance_consistency/*`

Then sync website docs:

```sh
node scripts/sync-website-docs.mjs
node scripts/sync-website-docs.mjs --check
```

Design Systems is addon diagnostic coverage. Run `sh scripts/dev-check.sh
--theme-diagnostics` when changing `moui_theme` or `examples/design_systems`.

Do not commit `artifacts/`. Cite CI run IDs, uploaded artifacts, or manual smoke
logs in release notes instead.
