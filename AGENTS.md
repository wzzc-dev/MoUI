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
- `docs/button-styling-guide.md` for the button color/style resolution pipeline
  and app-level override strategies (per-control `style=`, theme component
  override, palette seed). Read this before any "change button color" task
  instead of re-deriving the pipeline from source.
- `docs/decisions/` for formal Architecture Decision Records (ADRs) that
  document significant technical choices. Read relevant ADRs before changing
  architecture, APIs, or package boundaries.
- `docs/ai-sessions/` for summaries of past AI-agent sessions with key
  discoveries and patterns.

## Working Rules

- Keep shared app logic in `examples/<name>/app`; keep platform entrypoints thin.

### CI Safety Rules

- **Verify API existence in the exact imported package** before using any MoonBit API. Use `moon ide doc <pkg>.<fn>` to check, or grep the package's `.mbt` files. An API may exist in one package (e.g. `moonbitlang/async/fs::tmpdir`) but not in another (e.g. `moonbitlang/x/fs`).
- **Update moon.pkg imports** whenever you introduce a new `@pkg` prefix in a `.mbt` file. Run `moon check <package>` locally to catch missing imports before pushing.
- **Study all target platforms** before writing a cross-platform fix. A pattern that works on macOS/Linux (e.g. `/tmp/` path, `pthread` timing) may behave fundamentally differently on Windows (no `/tmp/`, `CreateThread` always succeeds, `Sleep(0)` needed to yield).
- **Prefer existing helpers** over inventing new path/API conventions. This repo has platform-tested helpers like `skia_test_temp_dir()` in `moui/render/skia/skia_renderer_test_helpers_wbtest.mbt`.
- **Run local validation before push**:
  - `moon check <package>` for compile errors and missing imports
  - `moon test <package> --target native` for the affected test package (if native-supporting)
  - `sh scripts/dev-check.sh` when changing core/view/render/backend packages
- **Synchronize async test patterns**: When a test spawns background threads and polls for results, ensure the polling loop yields the thread (e.g. `Sleep(0)` on Windows) so the background thread can execute before the poll budget is exhausted.
- Ordinary app packages should default to `wzzc-dev/moui` (app-loop `@moui.*`),
  `wzzc-dev/moui/<geometry|graphics|text|state>` as needed, and `wzzc-dev/moui/views`;
  use domain sugar and `@views` re-exports; reserve `@core` for tests (`for "test"`)
  or advanced kernel (see `docs/moui-app-package-boundary.md`, ADR `docs/decisions/0003-domain-sugar-and-root-facade.md`).
- Put new controls, control styles, form/navigation/data helpers, and default
  app-facing themes in `moui/views`.
- Put neutral cross-runtime protocols and value types in `moui/core`.
- Put runtime lifecycle, element/layout/render tree execution, effects,
  subscriptions, and diagnostics in `moui/runtime`.
- Put host service contracts in `moui/backend/host`; put concrete platform
  behavior in the platform backend packages.
- Keep native Skia mainline work on the Skia route. Treat native WGPU as
  diagnostic unless the request explicitly changes that policy.
- `wzzc-dev/window` resolves from mooncakes.io by default. `moon.work` must
  not list `./window`; `scripts/validate-window-dependency.mjs` enforces this
  in `dev-check.sh` and CI. To edit window source locally, run
  `sh scripts/window-dev-mode.sh on` (adds `./window` to `moon.work`), then
  `sh scripts/window-dev-mode.sh off` before committing. After publishing a
  new window version, update the pinned version in all four consumers
  (`moui/`, `moui_skia/`, `moui_webview/`, `examples/markdown_editor/`)
  and run `moon update`. See `docs/development.md` for the full workflow.
- Mo Workbench depends on `bobzhang/openseek`, which now resolves from
  mooncakes.io (pinned in `examples/mo_workbench/moon.mod`, e.g.
  `bobzhang/openseek@0.2.2`). No git submodule or `./openseek` workspace member
  is required; `moon.work` must not list `./openseek`. Run `moon update` to
  refresh the resolved registry version when a new openseek release ships.
- Use `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
  `moon ide find-references` for MoonBit API discovery before inventing names.
- `docs/button-styling-guide.md` documents the button style resolution pipeline
  (palette → component tokens → state resolution → control paint) and the three
  app-level override strategies. When changing any of the following, update
  that doc so future "change button color" tasks stay accurate:
  - `@core.ColorPalette` / `ColorPalette::from_seed` / `light()` / `dark()`
    in `moui/core/theme.mbt`;
  - `@core.ButtonTheme`, `ControlStateTokens`, `StateLayerTokens`, or
    `ButtonTheme::resolve` in `moui/core/theme_components.mbt`;
  - `minimal_components` / `minimal_state_layer` in
    `moui/core/theme_resolver.mbt`;
  - `ButtonVariant::style` / `ButtonVariant::to_token` in
    `moui/views/style_api.mbt`;
  - `ButtonStyle` / `ButtonStyle::filled/tonal/outline/ghost` / `control_state`
    in `moui/views/control_style.mbt`;
  - `button` / `button_control` paint resolution in `moui/views/button.mbt` or
    `moui/views/control_primitives.mbt`;
  - the `ButtonVariant` enum surface or the `ControlStateStyle` struct fields.
  Prefer app-level overrides (Strategy A/B in the doc) over framework edits;
  if a framework edit is unavoidable, update the doc in the same change.

## Pre-push Check

Before pushing any commit, run the same CI validation checks locally to avoid
CI failures:

```sh
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
```

A common CI failure is `node scripts/validate-maintenance-baseline.mjs`
complaining about unexpected test files (e.g.
`moui/backend/host/host_async_image_loader_test.mbt`). When this happens,
either register the new test in the maintenance baseline or revert the change
before pushing. The same guard also keeps MoonBit-backed JS validator wrappers
thin over `scripts/lib/moonbit-tool-runner.mjs`; do not reintroduce local
process runners, direct filesystem parsing, or hard-coded native `_build`
executable paths in those wrappers. Run `sh scripts/dev-check.sh` for the full
pre-push suite.

## Script Tooling Policy

Keep scripts simple, clear, and maintainable first. When MoonBit is equally
clear or close, prefer MoonBit `tools/...` packages for repository rules, static
validation, structure scans, deterministic generators, and smoke catalog
planning. Keep existing `node scripts/*.mjs` entrypoints as compatibility
wrappers over `scripts/lib/moonbit-tool-runner.mjs` when CI or users already
call them.

Use Node for browser/CDP, Web smoke, HTTP/GitHub artifacts, npm ecosystem
tools, and command execution that is clearer in JavaScript. Use sh/PowerShell
as thin orchestration for environment variables, platform setup, and OS command
dispatch. Windows MSVC, vcpkg, and zlib setup remains PowerShell-owned;
MoonBit may validate the related manifests or docs but must not install
machine tools.

Use `.mbtx` only for short standalone developer scripts; promote maintained CI
behavior to a `tools/...` package. Use `rule`/`dev_build` only for deterministic
package pre-build input/output generation. Do not use `rule`/`dev_build` to
install MSVC, vcpkg, zlib, Chrome, CI runners, or other machine dependencies,
and do not use it for smoke execution, networking, or global/user environment
mutation.

## Validation

Feature proof coverage is tracked in
[docs/feature-proof-matrix.md](docs/feature-proof-matrix.md) and
[docs/feature-status-dashboard.md](docs/feature-status-dashboard.md). The
`feature-proof-summary.yml` CI workflow generates a proof report after every
`ci.yml` run; the `moui-skia-real-skia-pr-smoke.yml` workflow provides L2
runtime proof on every PR and push-to-main (framework rendering depends on real Skia linking).

Use focused tests while editing. Before handoff, prefer the daily validation
script:

```sh
sh scripts/dev-check.sh
```

The daily validation script includes `moon check`, maintenance baseline guards,
API surface guards, smoke catalog validation, core/view/render/backend package
tests, `moui_tester`, `moui_devtools`, Showcase and Markdown Editor app tests,
and Web wasm-gc builds.

- Root app-loop aliases and domain sugar forwards are enforced by
  `tools/moui/validate_api_surface/main.mbt`. Update `root_app_shape_tokens()` or
  `sugar_<domain>_tokens()` and matching budgets when changing facade surfaces.

Use these additional checks when relevant:

```sh
node scripts/validate-api-surface.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-guidance-consistency.mjs
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

### Decision & Session Records

After significant agent sessions, maintain the three-layer record system:

1. **`memories/repo/`** — Update with quick-reference facts (auto-loaded by agents).
2. **`docs/decisions/`** — Create an ADR for formal decisions (use `TEMPLATE.md`).
3. **`docs/ai-sessions/`** — Log complex sessions (use `TEMPLATE.md`).

See `docs/ai-collaboration.md` § "Decision & Session Logging" for full workflow.

## Artifact Policy

Do not commit artifacts/. Generated logs, screenshots, manifests, and benchmark
scaffolds under `artifacts/` are disposable local or CI evidence. Release notes
should cite the CI run or smoke log that was actually inspected.
