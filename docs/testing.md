# Testing

MoUI uses bounded validation by default. The main line is package tests, Web
`wasm-gc` builds, static/metadata guards, and explicit manual smoke runs when a
real platform, browser, or renderer must be observed. Do not commit generated
`artifacts/`; they are local or CI evidence only.

## Daily

Run the daily validation script for routine app or framework work:

```sh
sh scripts/dev-check.sh
```

The script runs local dependency guards, guidance consistency, maintenance
baseline ratchets, API surface checks, renderer provider and native Skia
entrypoint static checks, smoke gate catalog validation, `moon check`, core
package tests, Web wasm-gc package tests, native Skia mainline package tests,
`moui_tester` harness tests, `moui_devtools` snapshot/debug tests, Showcase and
Markdown Editor app tests, and Web builds.

The daily gate includes these command tokens and should stay synchronized with
`scripts/dev-check.sh`:

```sh
node --check scripts/validate-api-surface.mjs
node scripts/validate-api-surface.mjs
node --check scripts/validate-maintenance-baseline.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-skia-entrypoints.mjs
node scripts/test-validate-skia-entrypoints.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node scripts/test-record-web-runtime-presentation.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
node --check scripts/smoke-check.mjs
node --check scripts/test-smoke-check.mjs
node scripts/test-smoke-check.mjs
node scripts/smoke-check.mjs --check
node --check scripts/smoke-gate.mjs
node --check scripts/test-smoke-gate.mjs
node scripts/test-smoke-gate.mjs
node scripts/smoke-gate.mjs --tier nightly --dry-run --json
sh -n scripts/ci-web-runtime-presentation.sh
moon check
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/backend/host --target native
moon test moui_tester --target native
moon test moui_devtools --target native
moon test moui_skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/test-validate-web-runtime-handoff.mjs
node scripts/validate-web-runtime-handoff.mjs
```

Design Systems is addon diagnostic coverage. Use
`sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme` or
`examples/design_systems`.

Native WGPU is diagnostic. Use `sh scripts/dev-check.sh --wgpu-experimental`
only when changing that route.

## Focused

Use smaller package checks while editing implementation code:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test moui_tester --target native
moon test moui_devtools --target native
moon test moui_skia --target native
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/excel/cell --target native
moon test examples/excel/formula --target native
moon test examples/excel/sheet --target native
moon test examples/excel/xlsx --target native
moon test examples/excel/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
```

Use `moon test moui/render/wgpu --target native` only for the native WGPU
diagnostic route. Use `moon fmt` before handoff. Run `moon info` and review
`pkg.generated.mbti` diffs after public API changes.

When splitting oversized implementation or test files, reducing source-level
`pub(all)`, or shrinking the root facade, run the maintenance baseline guard
and ratchet the relevant budget downward in the same change.

## Conformance Slices

`scripts/conformance-check.sh` remains a focused package-test dispatcher:

```sh
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
```

`--golden` and `--bench` write local scaffold manifests under ignored
`artifacts/` paths for screenshot or benchmark handoff. They are not checked-in
capability declarations.

## Feature Proof Matrix

Every MoUI feature maps to a CI job that proves it. See
[feature-proof-matrix.md](feature-proof-matrix.md) for the full mapping and
[feature-status-dashboard.md](feature-status-dashboard.md) for the current
proof status. The `feature-proof-summary.yml` workflow generates a proof
report after every `ci.yml` run.

Proof levels:

- **L1** (every PR, `ci.yml`): API/algorithm/protocol correctness via package
  tests.
- **L2** (every PR and push-to-main, `moui-skia-real-skia-pr-smoke.yml`): real Skia runtime
  behavior on macOS/Linux/Windows matching hosts.
- **L3** (`feature-proof-summary.yml`): all required L1 and L2 passed.

## Smoke

Use smoke runs when behavior depends on a real renderer, browser, or platform
host:

```sh
sh scripts/dev-check.sh --skia-real-smoke
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
scripts/macos-skia-renderer-smoke.sh --run-ime-smoke
sh scripts/ci-web-runtime-presentation.sh
```

`smoke/gates.json` is the checked-in smoke gate catalog. It describes the daily,
nightly, and release smoke tiers, each suite command, the structured result
shape, the owning workflow, and the docs that explain the gate. Validate it
without running platform smoke:

```sh
node --check scripts/smoke-check.mjs
node --check scripts/test-smoke-check.mjs
node scripts/test-smoke-check.mjs
node scripts/smoke-check.mjs --check
node scripts/smoke-check.mjs --tier nightly --list
node scripts/smoke-check.mjs --tier release --json
node scripts/smoke-gate.mjs --tier nightly --dry-run --json
node scripts/smoke-gate.mjs --suite web.runtime-presentation --run
```

The catalog check is part of the default `dev-check`; real browser/platform
smoke remains opt-in. `scripts/smoke-gate.mjs` is the unified runner for suites
selected from the catalog; it defaults to dry-run and requires `--allow-manual`
before running commands marked manual. The scheduled/manual
`.github/workflows/moui-runtime-smoke-gates.yml` workflow is the CI entrypoint
for the Web runtime presentation nightly smoke and the manual macOS real-Skia
release smoke.

The Web script builds Showcase, serves the repository, records a Chrome/CDP
browser-session manifest under `artifacts/smoke/web-runtime-presentation/`, and
validates it with `validate-web-runtime-presentation-manifest.mjs`. Treat the
result as a manual smoke log for that browser session.

Native Skia smoke logs can show renderer pixels, async image second-frame
behavior, optional SkParagraph text behavior, and tester-owned first-frame or
IME observations. They are direct pass/fail runtime logs, not a repository
manifest gate.

For Linux Skia first-frame evidence, use the matching Wayland host and keep
Showcase, Markdown Editor, and window-package smoke logs separate:

```sh
MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/showcase/linux_skia --target native
MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \
  moon run examples/markdown_editor/linux_skia --target native
scripts/run-window-package-smoke.sh linux --run
```

## Release Notes

Release readiness should cite the relevant CI run, uploaded artifact, or smoke
log. Do not commit generated `artifacts/` JSON as the long-term source of truth.

## Agent And Skill Checks

When changing repository guidance, update the synchronized surfaces together:

- `docs/`
- `AGENTS.md`
- `skills/moui-app-development/SKILL.md`
- `skills/moui-framework-development-skill/SKILL.md`
- `tools/moui/validate_guidance_consistency/*`

Then run:

```sh
node scripts/sync-website-docs.mjs --check
```
