# Testing

MoUI uses bounded validation by default. The main line is package tests, Web
`wasm-gc` builds, static/metadata guards, and explicit manual smoke runs when a
real platform, browser, or renderer must be observed. Do not commit generated
`artifacts/`; they are local or CI evidence only.

<!-- BEGIN GENERATED PLATFORM TIER MATRIX -->
| Tier | Canonical routes | Gate |
|---|---|---|
| Tier 1 | `macOS Skia`, `Web wasm-gc WebGPU (Canvas2D fallback)` | Blocking: PR build/test, daily presentation, and release evidence |
| Tier 2 | `Windows Skia`, `Linux Skia` | Blocking: L0-L2 and first frame; complete L3 may remain partial |
| Tier 3 | `macOS WGPU (CoreText, Cosmic fallback)`, `Windows WGPU (DirectWrite, Cosmic fallback)`, `Linux WGPU (Fontconfig, Cosmic fallback)`, `Android window-hosted Skia`, `iOS window-hosted Skia`, `HarmonyOS window-hosted Skia`, `macOS Sun`, `Windows Sun`, `Linux Sun`, `WeChat Skyline Canvas2D` | Non-blocking: scheduled/manual build, run, and evidence |

Tier, L0-L3 evidence, and `product_class`/`ready` are independent. Source: `checks/platform-matrix.json`; actual observations remain in `checks/platforms/*.json`.
<!-- END GENERATED PLATFORM TIER MATRIX -->

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
native Skia mainline package tests, internal `moui_tests/tester` harness tests,
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
node scripts/validate-viewnode-declaration-coverage.mjs   # ViewNode struct fields are keyed or exempt (ADR 0034, P17)
moon test tools/moui/validate_viewnode_declaration_coverage --target native
node scripts/generate-repo-docs.mjs --check
node scripts/validate-window-dependency.mjs
node scripts/validate-harness-invariants.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-backend-renderer-boundary.mjs
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-backend-common-boundary.mjs
node scripts/validate-window-lifecycle-boundary.mjs
node scripts/validate-core-theme-no-control-surface.mjs
node scripts/validate-host-import-baseline.mjs
moon run tools/moui/validate_source_file_policy --target native
node scripts/check-website-docs.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-skia-entrypoints.mjs
node scripts/validate-gpu-promotion-manifest.mjs docs/gpu-promotion-manifest.example.json
node --check scripts/test-moui-prebuild.mjs
node scripts/test-moui-prebuild.mjs
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node scripts/test-web-canvas2d-lazy-fallback.mjs
node scripts/test-web-bundle-tools.mjs
node scripts/smoke-check.mjs --check
moon check
node scripts/check-generated-interfaces.mjs
moon test moui/core --target native
moon test moui/views --target native
moon test moui/runtime --target native
moon test moui_richtext --target native
moon test moui_webview --target native
moon test moui_agent --target native
moon test moui_agent_mcp --target native
moon test examples/agent_counter --target native
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_sun_renderer --target native
moon test moui/backend --target native
moon test moui_tests/tester --target native
moon test moui_devtools --target native
moon test moui_skia --target native
moon test moui_web_renderer --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon check moui/runtime --target wasm-gc
moon check moui_richtext --target wasm-gc
moon check moui_webview --target wasm-gc
moon test moui_agent --target wasm-gc
moon test moui_agent_mcp --target wasm-gc
moon test examples/agent_counter --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
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

### Accessibility evidence

Accessibility has three separate evidence levels. L1 package tests validate
the committed semantics contract, generation checks, focus/modal behavior,
and Agent wire shape. L2 must query and operate the real platform tree through
AX, UIA, AT-SPI, or Chrome's accessibility tree. L3 records navigation and
spoken output from a matching screen reader; an L2 client cannot substitute
for it.

Windows and Linux candidate adapters remain below L2. Windows requires an MSVC
plus Windows SDK build against a released window-host message hook, followed by
a UIA client action/query trace. Linux requires AT-SPI accessibility-bus and
Registry registration followed by a real AT-SPI client trace. A process-local
hook preflight or ordinary session-bus object export does not promote either
platform's native capability.

On macOS, grant Accessibility permission to the shell or Agent host that runs
the probe, then use:

```sh
scripts/macos-accessibility-probe.sh --require-passed
node scripts/validate-accessibility-foundation.mjs \
  --evidence artifacts/accessibility/macos/manifest.json \
  --require-native-client
```

The producer launches the Showcase Accessibility Probe, queries the external
AX tree by stable `a11y.*` identifiers, performs actions, and matches each
native action to the bridge request and exact-generation runtime receipt. It
also observes `AXAnnouncementRequested` without moving focus. Missing TCC
permission or incomplete evidence produces a failed manifest under
`artifacts/accessibility/macos/`; it never promotes capability. VoiceOver L3
remains the separate release gate:

```sh
node scripts/validate-accessibility-foundation.mjs \
  --evidence artifacts/accessibility/macos/manifest.json \
  --require-screen-reader
```

### Linux RISC-V64 Experimental Route

The RISC-V64 route is a non-blocking scheduled/manual architecture variant of
`linux/skia`; it does not change the generated 14-route canonical matrix. Its
locked Ubuntu sysroot and Zig toolchain are described in
`checks/toolchains/linux-riscv64.json`.

```sh
bash scripts/prepare-linux-riscv64-sysroot.sh \
  --output .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64
bash scripts/linux-riscv64-cross-build.sh \
  --sysroot .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64 \
  --target-dir _build/riscv64-linux-gnu \
  --log-dir artifacts/linux-riscv64 \
  --run-qemu
```

The helper's L0 evidence is the Showcase ELF architecture report. L2 requires
QEMU markers from both real-Skia offscreen smokes, including the async image
second frame and SkParagraph text/emoji output. QEMU evidence is
renderer-only; it must not be folded into Linux Wayland L3 status. Validate
metadata and helper failure contracts without a sysroot with:

```sh
node scripts/validate-platform-matrix.mjs
moon test tools/moui/validate_platform_matrix --target native
bash scripts/test-linux-riscv64-cross-build.sh
```

`.github/workflows/moui-linux-riscv64-cross-build.yml` is the non-blocking
scheduled/manual producer. It uploads the sysroot package/checksum manifests,
Release build log, ELF reports and checksums, renderer smoke log, and
SkParagraph text/emoji smoke log. L3 remains a separate matching-device gate.

The `external-consumer.yml` workflow copies the selected base, Skia, or Web
fixture outside the checkout. Until 0.2 is published, registry mode validates
the stable base `wzzc-dev/moui@0.1.7`; package mode validates the 0.2 head
archives for base-only, Skia, and Web consumers. Package-mode `moon tree`
checks also reject concrete renderers and diagnostic/test dependencies from
the base closure. Every resolved `.mooncakes` path must report
`monorepoSource=false`:

```sh
node scripts/external-consumer-ci.mjs --source registry --profile base
node scripts/external-consumer-ci.mjs --source package --profile base
node scripts/external-consumer-ci.mjs --source package --profile skia
node scripts/external-consumer-ci.mjs --source package --profile web
```

## Focused

Provider composition and backend common boundary edits use the following minimum loop
before broader profiles:

```sh
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_wgpu_renderer --target native
moon test moui_sun_renderer --target native
moon test moui_web_renderer --target wasm-gc
moon check moui_web_renderer/canvas2d --target wasm-gc
moon test moui/backend/wechat --target wasm-gc
node scripts/test-web-canvas2d-lazy-fallback.mjs
moon test moui/backend/common --target native
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-backend-common-boundary.mjs
node scripts/validate-window-lifecycle-boundary.mjs
```

The backend common boundary validator is a required PR-profile failure gate. It checks
direct bridge use by desktop/Web backends, shared embedded-runtime use by the
three mobile backends, forbidden bridge-helper redefinitions, and the fixed
WeChat `direct-canvas-callback` boundary. It has no similarity score, threshold,
budget, allowlist, or expiry date. Rendering-composition changes also require
the path-triggered macOS Skia and Web presentation smokes before a runtime claim.

### Architecture convergence validators (ADR 0017–0024)

The four architecture validators from the convergence plan are enforced gates
(PR profile per `checks/profiles.json`; also in the daily token list above)
and map to invariants P3/P5/P6/M6:

```sh
node scripts/validate-core-theme-no-control-surface.mjs  # core keeps no control-only theme/API surface (ADR 0017, P3)
node scripts/validate-host-import-baseline.mjs           # backend default imports stay contracts-only (ADR 0018, P5)
node scripts/validate-renderer-provider-open-extension.mjs  # render providers stay open-extension; no central matrix (ADR 0019, P6)
node scripts/validate-backend-common-boundary.mjs       # platform adapters use the single backend/common owner (ADR 0025, P10)
node scripts/validate-window-lifecycle-boundary.mjs     # seven backends share lifecycle/frame ownership; window dispatch is physical-only
```

Run them when touching their change surface: core/theme layering, host
contracts, renderer provider composition, or platform adapters — the same
surfaces the PR profile gates. Platform duplication is resolved in code when
found; it is not recorded as an accepted similarity budget. Renderer-provider
manifest budgets remain a separate ADR 0019 policy.

**Platform profile expectation.** `sh scripts/check.sh --profile platform`
runs shared platform service checks for host/Web contracts and opportunistic
Linux protocol/cache sanity, then `checks/profiles.json` owns the
host-specific backend/provider package steps. The four validators above are
PR/daily gates; the platform profile adds the matching backend/provider
package tests, and path-triggered platform smokes remain required before a
runtime claim.

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
moon test moui_richtext --target native
moon test moui_webview --target native
moon test moui_agent --target native
moon test moui_agent_mcp --target native
moon test examples/agent_counter --target native
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_web_renderer --target wasm-gc
moon test moui/backend --target native
moon test moui/backend/common --target native
moon test moui/backend/common/lifecycle --target native
moon test moui/backend/common/frame --target native
moon test moui/backend/common/image --target native
moon test moui/backend/common/input --target native
moon test moui/backend/common/services --target native
moon test moui/backend/common/services/desktop --target native
moon test moui/backend/common/services/embedded --target native
moon test moui/backend/common/services/native --target native
moon test moui/backend/common/image/native --target native
moon test moui/backend/common/embedded --target native
moon test moui/backend/android --target native
moon check examples/showcase/android_window_hosted --target native
moon test moui/backend/ios --target native
moon check examples/showcase/ios_window_hosted --target native
moon test moui/backend/harmonyos --target native
moon check examples/showcase/harmonyos_window_hosted --target native
moon test moui/backend/web --target wasm-gc
moon test moui_tests/renderer_contract --target native
moon test moui_tests/tester --target native
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
moon check examples/showcase/android_window_hosted --target native
moon check examples/showcase/ios_window_hosted --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
```

Use `moon test moui_wgpu_renderer --target native` only for the native WGPU
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

The PR profile validates the checked-in performance budget catalog and its
MoonBit validator without downloading a renderer. The macOS `benchmark-scaffold`
job is the canonical measured producer: it runs the native Skia Raster workloads
for Showcase, Markdown Editor, Excel, a 100k-row virtual list, and four runtime
windows, then uploads `artifacts/performance/result.json`. Run the same gate
locally when the locked real Skia provider is available:

```sh
node scripts/validate-performance-budgets.mjs
moon test tools/moui/validate_performance_budgets --target native
node scripts/run-performance-budgets.mjs
```

The runner records build/layout/paint/present/frame samples plus peak RSS, live
allocation blocks, cache hit rate, startup time, and executable size. Initial
catalog values are reviewed guardrails rather than machine-portable claims.
Change them only with a matching `native-skia-raster` artifact, runner identity,
and the approval/reason required by `checks/performance-budgets.json`.

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

### Embedded runtime backends

Android, iOS, and HarmonyOS all use `wzzc-dev/window` `HostCmd` → `EventLoop`
→ `ApplicationHandler` → MoUI `*EmbeddedRuntimeBackend`. Run the portable host-sim
gate after changing an embedded-runtime template, entrypoint, or backend:

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

It covers the three window host simulators, the MoUI backend packages, and the
Counter embedded-runtime entrypoints. It runs nightly in CI as the
`window-hosted-hostsim` job of `moui-runtime-gates.yml` (dev mode is enabled for
the run and disabled afterwards, so the check never leaves an editable `window`
workspace behind). `--fallback-skia` builds remain packaging-only
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
node scripts/smoke-check.mjs --check
node scripts/smoke-check.mjs --tier nightly --list
node scripts/smoke-check.mjs --tier release --json
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
Showcase and window-package smoke logs separate:

```sh
MOUI_FIRST_FRAME_EXIT=1 MOUI_SKIA_RENDERER=auto \
  moon run examples/showcase/linux_skia --target native
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
