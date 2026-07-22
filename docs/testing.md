# Testing

MoUI uses bounded validation by default. The main line is package tests, Web
`wasm-gc` builds, static/metadata guards, and explicit manual smoke runs when a
real platform, browser, or renderer must be observed. Do not commit generated
`artifacts/`; they are local or CI evidence only.

## Daily

Run the daily validation script for routine app or framework work:

```sh
sh scripts/check.sh --profile daily
```

The script runs local dependency guards, guidance consistency, maintenance
baseline ratchets, API surface checks, renderer provider and native Skia
entrypoint static checks, generated repository facts and source-file policy,
smoke gate catalog validation, `moon check`, generated
public-interface drift detection, core package tests, Web wasm-gc package tests,
native Skia mainline package tests, `moui_tester` harness tests,
`moui_devtools` snapshot/debug tests, Showcase and Markdown Editor app tests,
and Web builds.

The daily gate is sourced from `checks/profiles.json` and can be inspected with
`node scripts/check.mjs --profile daily --list`. Representative command tokens
that should stay synchronized with the catalog include:

```sh
node scripts/lint-scripts.mjs --profile pr
node scripts/validate-check-profiles.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-api-surface.mjs
node scripts/generate-repo-docs.mjs --check
node scripts/validate-window-dependency.mjs
node scripts/validate-harmonyos-shell.mjs
node scripts/validate-harness-invariants.mjs
node scripts/validate-maintenance-baseline.mjs
moon run tools/moui/validate_source_file_policy --target native
node scripts/check-website-docs.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-skia-entrypoints.mjs
node scripts/validate-gpu-promotion-manifest.mjs docs/gpu-promotion-manifest.example.json
node scripts/test-validate-skia-entrypoints.mjs
moon test tools/moui/generate_repo_docs --target native
moon test tools/moui/validate_source_file_policy --target native
node --check scripts/test-moui-prebuild.mjs
node scripts/test-moui-prebuild.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node scripts/test-web-canvas2d-lazy-fallback.mjs
node scripts/test-web-bundle-tools.mjs
node scripts/test-record-web-runtime-presentation.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
moon test tools/moui/validate_gpu_promotion_manifest --target native
moon test tools/moui/gpu_promotion_scaffold --target native
node scripts/test-gpu-promotion-manifest-lib.mjs
node scripts/test-gpu-performance-metrics.mjs
node scripts/test-check-runner.mjs
node scripts/test-smoke-check.mjs
node scripts/smoke-check.mjs --check
node scripts/test-smoke-gate.mjs
node scripts/smoke-gate.mjs --tier nightly --dry-run --json
moon check
node scripts/check-generated-interfaces.mjs
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/sun --target native
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
`sh scripts/check.sh --profile theme` when changing `moui_theme` or
`examples/design_systems`.

Native WGPU is diagnostic. Use `sh scripts/check.sh --profile full`
when changing that route or when you need the full-workspace hotspot guard.
The full profile runs the daily maintenance baseline plus
`moon run tools/moui/validate_maintenance_baseline --target native -- --scope full`
to report registered large-file hotspots in addon/tool workspaces without
expanding the daily gate.

The generated-interface step snapshots every tracked `pkg.generated.mbti`, runs
one workspace-wide `moon info`, and fails only when generation creates new
differences. This keeps the check useful in a dirty working tree while a clean
CI checkout still rejects uncommitted public-interface drift.

The `external-consumer.yml` workflow copies
`checks/external-consumer` outside the checkout and runs a Linux/macOS/Windows
matrix against both `wzzc-dev/moui@0.1.7` from the registry and the current
`moon package` archive. Its `moon tree` and resolved `.mooncakes` path checks
must report `monorepoSource=false`:

```sh
node scripts/external-consumer-ci.mjs --source registry
node scripts/external-consumer-ci.mjs --source package
```

## Focused

Playground-focused checks should cover both MoonBit editor behavior and the
static browser bundle:

```sh
moon test moui_richtext/code_editor --target native
moon check moui_richtext/code_editor --target wasm-gc
moon test website/playground/app --target native
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
node --check website/playground/host/compiler-worker.js
node --check website/playground/host/playground-bridge.js
node --check website/playground/host/preview-host.js
node scripts/test-playground-assets.mjs --root dist/playground
```

Use smaller package checks while editing implementation code:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/host --target native
moon test moui/backend/android --target native
moon test moui/backend/android/skia --target native
moon test moui/backend/ios --target native
moon test moui/backend/ios/skia --target native
moon test moui/backend/harmonyos --target native
moon test moui/backend/harmonyos/skia --target native
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
moon check examples/counter/android_window_hosted --target native
moon check examples/counter/ios_window_hosted --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/harmonyos_demo/harmonyos_window_hosted --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
```

Use `moon test moui/render/wgpu --target native` only for the native WGPU
diagnostic route. Use `moon fmt` before handoff. Run `moon info` and review
`pkg.generated.mbti` diffs after public API changes.

When splitting oversized implementation or test files, reducing source-level
`pub(all)`, shrinking the root facade, or changing MoonBit-backed validator
wrapper scripts, run the maintenance baseline guard and ratchet the relevant
budget downward in the same change. MoonBit-backed JS validators should stay
thin compatibility shims over `scripts/lib/moonbit-tool-runner.mjs`; avoid
reintroducing local process runners, direct filesystem parsing, or hard-coded
native `_build` executable paths there.

## Script Tooling Policy

Script changes follow the same clarity-first rule as framework code. Prefer a
MoonBit `tools/...` package when the work is repository validation, source or
manifest scanning, deterministic generation, or smoke catalog planning that can
be covered by `moon check` and `moon test`. Keep existing `node scripts/*.mjs`
commands as stable wrappers when CI or users already depend on them.

Keep Node for browser/CDP, Web smoke, HTTP/GitHub artifacts, npm ecosystem
work, and the `scripts/smoke-gate.mjs` execution layer. Keep sh/PowerShell thin
for environment setup and platform dispatch; Windows MSVC, vcpkg, and zlib
setup remains PowerShell-owned. Use `.mbtx` for short standalone scripts only,
then graduate maintained CI behavior to `tools/...`.

`rule`/`dev_build` is not a task runner. Use it only when a package build needs
a deterministic pre-build input/output generation step. Do not use it to install
MSVC, vcpkg, zlib, Chrome, CI runners, or other machine dependencies, and do not
use it for smoke execution, networking, or global environment mutation.

## Check Profiles

`scripts/check.mjs` is the checked profile runner:

```sh
node scripts/check.mjs --profile pr --list
sh scripts/check.sh --profile daily
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile theme
sh scripts/check.sh --profile full
```

CI profile jobs use the shell wrapper to express gate intent:
`ci.yml` runs `sh scripts/check.sh --profile pr` for the PR profile gate and
`sh scripts/check.sh --profile platform` for Linux platform contracts. The
Windows MSVC job keeps its MSVC/build/package steps explicit and only verifies
the PowerShell wrapper can parse the PR profile with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\check.ps1 -Profile Pr -DryRun -Json -SkipSubmoduleInit
```

Use focused `moon test ...` package commands while editing. The `platform`
profile starts with shared platform service checks for host/Web contracts and
opportunistic Linux protocol/cache sanity, then `checks/profiles.json` owns the
host-specific backend/provider package steps. `theme` covers Design Systems
addon diagnostics, and `full` adds full-workspace hotspot scanning, text
diagnostics, capture scaffolds, theme checks, platform checks, and current-host
native example builds.

Capture scaffolds write local manifests under ignored `artifacts/` paths for
screenshot or benchmark handoff. They are not checked-in capability
declarations:

```sh
node scripts/conformance-capture-scaffold.mjs --mode golden
node scripts/conformance-capture-scaffold.mjs --mode benchmark
```

## Feature Proof Matrix

Every MoUI feature maps to a CI job that proves it. See
[feature-proof-matrix.md](feature-proof-matrix.md) for the full mapping and
[feature-status-dashboard.md](feature-status-dashboard.md) for the current
proof status. The `feature-proof-summary.yml` workflow generates a proof
report after every `ci.yml` run.

Proof levels:

- **L1** (every PR, `ci.yml`): API/algorithm/protocol correctness via package
  tests.
- **L2** (every PR and push-to-main, `moui-renderer-real-skia-ci.yml`): real Skia runtime
  behavior on macOS/Linux/Windows matching hosts.
- **L3** (`feature-proof-summary.yml`): all required L1 and L2 passed.

## Smoke

### GPU promotion scaffolds (Wave A)

Pending manifests and gap reports (does **not** flip `gpu_promoted`):

```sh
node scripts/record-gpu-promotion-smoke.mjs --platform macos
node scripts/validate-gpu-promotion-manifest.mjs docs/gpu-promotion-manifest.example.json
```

See [gpu-promotion-runbook.md](gpu-promotion-runbook.md).


Use smoke runs when behavior depends on a real renderer, browser, or platform
host:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
scripts/macos-skia-renderer-smoke.sh --run-ime-smoke
sh scripts/ci-web-runtime-presentation.sh
```

### Window-hosted mobile hosts

Android, iOS, and HarmonyOS all use `wzzc-dev/window` `HostCmd` → `EventLoop`
→ `ApplicationHandler` → MoUI `*WindowHostedApp`. Run the portable host-sim
gate after changing a mobile template, entrypoint, or backend adapter:

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

It covers the three window host simulators, the MoUI backend packages, and the
Counter mobile entrypoints. `--fallback-skia` builds remain packaging-only
diagnostics and cannot establish a presenter or runtime claim.

For a connected matching target, build and run one platform at a time, then
record the generated window-hosted verification manifest:

```sh
moui run android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json" --device <adb-serial>
moui verify android showcase --device <adb-serial> --require-passed
```

Use the equivalent `ios` or `harmonyos` commands for those targets. A passed
claim requires observed presentation, input, surface detach/recreate, IME,
clipboard, accessibility, and async-image behavior. GPU seven-gate quality
claims remain separate from runtime readiness.

The VM facade always runs host-sim first. Enable only one optional device leg:

```sh
WINDOW_HOSTED_ANDROID_AVD=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_IOS_SIM=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_HARMONYOS_HVD=1 sh scripts/window-hosted-vm-smoke.sh
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

The catalog check is part of the daily profile; real browser/platform
smoke remains opt-in. `scripts/smoke-gate.mjs` is the unified runner for suites
selected from the catalog; it defaults to dry-run and requires `--allow-manual`
before running commands marked manual. The scheduled/manual
`.github/workflows/moui-runtime-gates.yml` workflow is the CI entrypoint
for the Web runtime presentation nightly smoke and the manual macOS real Skia
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
node scripts/check-website-docs.mjs
```
