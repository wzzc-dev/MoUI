# Testing

MoUI now uses lightweight validation by default. The main line is package
tests, Web wasm-gc builds, and a few explicit manual smoke runs when real
platform behavior matters. We do not commit long-lived `artifacts/conformance`
JSON, and generated files under `artifacts/` are local or CI logs only.

## Daily

Run the bounded daily check for routine framework work:

```sh
sh scripts/dev-check.sh
```

This runs local dependency guards, guidance consistency, API surface checks,
renderer provider and native Skia entrypoint static checks, `moon check`, core
package tests, Web wasm-gc package tests, native Skia mainline package tests,
Showcase and Markdown Editor app tests, and Web builds:

```sh
node scripts/validate-guidance-consistency.mjs
node --check scripts/validate-api-surface.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-skia-entrypoints.mjs
node scripts/test-validate-skia-entrypoints.mjs
node scripts/validate-web-runtime-handoff.mjs
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node scripts/test-record-web-runtime-presentation.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
sh -n scripts/ci-web-runtime-presentation.sh
moon check
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/backend/host --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Design Systems is addon diagnostic coverage. Use
`sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme` or
`examples/design_systems`.

## Focused

Use smaller package checks while editing implementation code:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
```

Use `moon test moui/render/wgpu --target native` only for the native WGPU
diagnostic route. Use `moon fmt` before handoff. Run `moon info` and review
`pkg.generated.mbti` diffs after public API changes.

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
capability evidence.

## Smoke

Use smoke runs when behavior depends on a real renderer, browser, or platform
host:

```sh
sh scripts/dev-check.sh --skia-real-smoke
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
sh scripts/ci-web-runtime-presentation.sh
```

The Web script builds Showcase, serves the repository, records a Chrome/CDP
browser-session manifest under `artifacts/smoke/web-runtime-presentation/`, and
validates it with `validate-web-runtime-presentation-manifest.mjs`. Treat the
result as a manual smoke log for that browser session.

Native Skia smoke logs can show renderer pixels, async image second-frame
behavior, optional SkParagraph text behavior, and first-frame example
presentation. They are direct pass/fail runtime logs, not a repository
manifest gate.

## Release Notes

Release readiness should cite the relevant CI run, uploaded artifact, or smoke
log. Do not commit generated `artifacts/` JSON as the long-term source of truth.
