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

<<<<<<< Updated upstream
The script runs local dependency guards, guidance consistency, maintenance
baseline ratchets, API surface checks, renderer provider and native Skia
entrypoint static checks, smoke gate catalog validation, `moon check`, core
package tests, Web wasm-gc package tests, native Skia mainline package tests,
`moui_tester` harness tests, `moui_devtools` snapshot/debug tests, Showcase and
Markdown Editor app tests, and Web builds.

The daily gate includes these command tokens and should stay synchronized with
`scripts/dev-check.sh`:

```sh
=======
This keeps feedback fast by running stable package-level tests for `core`,
`views`, `backend/host`, `backend/web`, the native Skia mainline, the Web
wasm-gc adapter, Showcase, and Markdown Editor without invoking every native or
wasm-gc target. Pass `--wgpu-experimental` when you want native WGPU
diagnostics in the same loop. Pass `--theme-diagnostics` when you want
`moui_theme` and Design Systems addon diagnostic coverage in the same loop.

The daily check also runs
`node scripts/validate-checked-conformance-artifacts.mjs`, which validates the
checked-in conformance capture, Web handoff, Web presentation, platform
runtime evidence, and renderer-proof manifests with the current validators. This
keeps committed evidence artifacts from drifting behind the schema and evidence
rules that release handoffs cite.

It also runs `node scripts/validate-api-surface.mjs`, a thin wrapper around the
MoonBit tool in `tools/moui/validate_api_surface/`, so generated public
interfaces stay inside the documented app/core/host/render package boundaries.
See [Maintenance mainline](maintenance.md) for the `mainline`, `diagnostic`,
and `pending` validation categories.

## Focused Package Tests

Use package-level commands while editing implementation code:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/render/wgpu --target native  # WGPU diagnostic path
moon test moui/tests/tooling --target native
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/design_systems/app --target native  # addon diagnostic
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
```

Run `moon fmt` before handoff so MoonBit source stays normalized.

For PDF Workbench app-only or `pdflite_adapter` checks, set
`MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1` unless the native PDFium raster adapter
is the thing being validated.

Use `moon check --warn-list +unnecessary_annotation` as a cleanup audit before
or during public API reviews. Treat new unnecessary annotations as cleanup work,
but do not require this stricter audit to be warning-free for every inner-loop
change until existing warnings are resolved.

When validating cookbook-style app patterns, start with the package that owns
the contract and then run the shared example that demonstrates it. The common
mapping is:

| Pattern | Focused checks |
| --- | --- |
| Forms | `moon test moui/core --target native`, `moon test moui/views --target native`, `moon test examples/settings/app --target native` |
| Data table | `moon test moui/views --target native`, `moon test examples/data_table/app --target native` |
| Navigation shell | `moon test moui/views --target native`, `moon test examples/showcase/app --target native` |
| Menus and commands | `moon test moui/core --target native`, `moon test moui/views --target native`, `moon test examples/command_palette/app --target native` |
| Program effects and subscriptions | `moon test moui/core --target native` covers TEA model dispatch, effect/task/subscription lifecycle diagnostics, stale callback guards, synchronous click/effect/task/subscription queueing, and the bounded per-turn drain that keeps self-queued messages pending instead of monopolizing the current runtime callback |
| Host services and file workflows | `moon test moui/backend/host --target native`, `moon test moui/backend/web --target wasm-gc`, `moon test examples/file_importer/app --target native`, `moon test examples/pdf_workbench/app --target native`, `moon test examples/pdf_workbench/pdflite_adapter --target native`, `moon test examples/pdf_workbench/pdfium_adapter --target native` |
| Host event, window, timer, and route subscriptions | `moon test moui/core --target native`, `moon test moui/backend/host --target native`, `moon test moui/backend/web --target wasm-gc`, touched native backend checks such as `moon test moui/backend/macos --target native`, `moon test moui/backend/linux --target native`, or `moon check moui/backend/windows --target native` |
| Native async image completion | `moon test moui/render --target native`, `moon test moui/render/skia --target native`, `moon test moui/backend/host --target native`, touched native backend/provider package tests such as `moon test moui/backend/macos --target native`, `moon test moui/backend/macos/skia --target native`, `moon test moui/backend/linux --target native`, or `moon test moui/backend/linux/skia --target native`; add `moon test moui/render/wgpu --target native` plus the matching `backend/<platform>/wgpu` package only for WGPU diagnostic changes. Windows package tests require a Windows/MSVC host, use `moon check moui/backend/windows --target native` and `moon check moui/backend/windows/skia --target native` on non-Windows hosts for static API coverage |
| Virtual lists | `moon test moui/views --target native`, `sh scripts/conformance-check.sh --layout` |

## Theme Diagnostics

Design Systems is addon diagnostic coverage, not part of the default daily
baseline. Run the opt-in theme diagnostics when changing `moui_theme`,
design-system source mappings, token reports, or the dedicated Design Systems
example:

```sh
sh scripts/dev-check.sh --theme-diagnostics
```

That opt-in path runs the `moui_theme` package checks plus
`examples/design_systems/app` and `examples/design_systems/web_wasm`.
Showcase remains the MoUI framework catalog and must stay independent of
`moui_theme`.

## Platform Validation

When platform behavior matters, include backend tests without forcing native
example builds:

```sh
sh scripts/dev-check.sh --platform-examples-test
```

Before release-style validation on a configured host, build current-platform
examples:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Native builds link platform stubs and renderer-specific native libraries, so
they are intentionally not part of every inner-loop check. By default they
build the Skia native mainline; pass `--wgpu-experimental` to include WGPU
native diagnostics.

Renderer provider packages are platform-specific. Use the current-host helper
above for normal backend/provider validation instead of trying to run every
`moui/backend/<platform>/{wgpu,skia}` test package on every machine.
For example, `moon test moui/backend/macos/wgpu --target native` is a native
WGPU diagnostic provider check, not a default mainline requirement.
The macOS, Windows, and Linux Skia provider packages expose
`macos_skia_provider_preflight_summary()`,
`windows_skia_provider_preflight_summary()`, and
`linux_skia_provider_preflight_summary()` for package-level audits of renderer
availability, `moui_skia/native` availability, selected font resolution, the
presenter path, the renderer-neutral `HostWindowRenderer` bridge used to
forward the Skia text system, image-resource diagnostics, present count, and
disposal hooks, host service/input readiness, clipboard/menu/file-dialog/open
URL/system-theme/async-service readiness, window/multi-window readiness,
text-input/IME/drag-drop readiness, native context-menu readiness, host-modal
file-dialog readiness, native accessibility status, and whether the
matching-host first-frame smoke option is enabled. Their tests prove
provider/preflight wiring only. macOS runtime
presentation still requires the real-Skia renderer smoke or a Showcase
first-frame run; Windows Skia tests require a Windows/MSVC host
because the Win32 stubs include `windows.h`; Linux Skia tests can compile where
the local Linux window package and toolchain are available, but real
presentation still requires a matching Wayland runtime. Windows and Linux Skia
entrypoints expose the same auto-exit path through
`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` and
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1`; passed logs from
those runs are matching-host runtime evidence, not provider evidence.
`node scripts/validate-skia-entrypoints.mjs` statically audits the native Skia
example entrypoint shape for Showcase, Markdown Editor, and Mo Workbench: each
entrypoint must import `render/skia`, the matching `backend/<platform>/skia`
provider, its shared app package, the smoke-only first-frame environment flag,
and the `EmptyTypeface`/`SystemFontMgr` selection. Showcase Skia entrypoints
must also inject the matching platform capability summary so the host
diagnostics card reports the selected host route. That guard is package/wiring
evidence only; runtime presentation still needs the smoke or matching-host
commands above.
After a matching host has produced provider, fallback-unavailable, renderer
smoke, and Showcase first-frame logs under
`artifacts/platform-evidence/<platform>/`, use
`node scripts/record-native-skia-evidence.mjs` to validate those log markers and
update only that platform's `skiaEvidence` block. Provider preflight logs must
include both a platform Skia provider identity and a passing preflight, test, or
build marker; a generic passing test summary is not enough. Showcase
first-frame logs must include the platform first-frame marker with
`title=MoUI Showcase`, so app-swapped artifacts cannot fill the observation. The helper
intentionally leaves the broader platform runtime `status` unchanged; use the
full platform recorder below only after service/input/window observations have
also been collected.
On macOS, the real-Skia helper sets `MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1`
around its focused builds so unrelated PDFium prebuild downloads do not block
Skia renderer evidence collection.
The Skia renderer package also exposes `skia_text_system()` for diagnostic text
contract checks; `moon test moui/tests/text_conformance/native --target native`
includes that path as measurement evidence, not as platform-window runtime
evidence.

On Linux, the platform example build step covers Showcase native entrypoints
plus the Markdown Editor Skia entrypoint:

```sh
moon build examples/showcase/linux_skia --target native
moon build examples/markdown_editor/linux_skia --target native
```

Runtime validation requires a Wayland compositor and configured real Skia link
flags:

```sh
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

## Public API Review

After changing exported types, constructors, functions, package imports, or
public behavior, run:

```sh
moon info
```

Review generated `pkg.generated.mbti` diffs. If no public API changed, generated
interfaces should stay unchanged.

Treat generated interfaces as the public API contract baseline. Behavioral
contracts should be covered by focused `*_contract_test.mbt` files or the
conformance matrix; avoid adding long-lived `*_spec.mbt` files for ordinary
implementation structure. Use `*_tree.mbt`, `*_descriptor.mbt`, `*_input.mbt`,
`*_protocol.mbt`, and `*_capabilities.mbt` for package-local source
organization when those names match the responsibility.

Run the API surface guard after `moon info` when public shape may have changed:

```sh
node scripts/validate-api-surface.mjs
```

See [API surface](api-surface.md) for the current app-facing, core,
integration, and addon API tiers. The guard locks current package budgets and
boundary tokens; deliberate API expansion should update the budget and explain
the tradeoff in the same change.

## Documentation And Guidance Checks

For docs-only changes, keep validation lightweight and focused on the edited
surface:

```sh
sh scripts/dev-check.sh --help
sh scripts/conformance-check.sh --help
sh -n scripts/dev-check.sh
sh -n scripts/conformance-check.sh
sh -n scripts/check-local-deps.sh
bash -n scripts/run-window-package-smoke.sh
bash moui_skia/scripts/verify-platform-status.sh
bash moui_skia/scripts/verify-native-capability-contract.sh
sh -n scripts/preview-loop.sh
sh -n scripts/package-macos-app.sh
sh -n scripts/ci-web-runtime-presentation.sh
sh -n scripts/ci-renderer-proof-native.sh
sh -n scripts/ci-renderer-proof-summary.sh
node --check scripts/validate-guidance-consistency.mjs
>>>>>>> Stashed changes
node scripts/validate-guidance-consistency.mjs
node --check scripts/validate-maintenance-baseline.mjs
node scripts/validate-maintenance-baseline.mjs
node --check scripts/validate-api-surface.mjs
node scripts/validate-api-surface.mjs
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
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
```

Use `moon test moui/render/wgpu --target native` only for the native WGPU
diagnostic route. Use `moon fmt` before handoff. Run `moon info` and review
`pkg.generated.mbti` diffs after public API changes.

When splitting oversized implementation or test files, reducing source-level
`pub(all)`, or shrinking the root facade, run
`node scripts/validate-maintenance-baseline.mjs` and ratchet the relevant
budget downward in the same change.

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
node scripts/validate-guidance-consistency.mjs
node scripts/sync-website-docs.mjs --check
```
<<<<<<< Updated upstream
=======

```sh
node scripts/record-native-ime-evidence.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  windows \
  --host "Windows MSVC CI" \
  --consumer-command \
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"" \
  --candidate-anchor-log artifacts/platform-evidence/windows/ime-candidate-anchor.log \
  --surrounding-text-log artifacts/platform-evidence/windows/ime-surrounding-text.log \
  --composition-visual-log artifacts/platform-evidence/windows/ime-composition-visual.log \
  --commit-delete-log artifacts/platform-evidence/windows/ime-commit-delete.log \
  --cursor-update-log artifacts/platform-evidence/windows/ime-cursor-update.log \
  --scroll-anchor-log artifacts/platform-evidence/windows/ime-scroll-anchor.log \
  --scale-dpr-anchor-log artifacts/platform-evidence/windows/ime-scale-dpr-anchor.log \
  --resize-anchor-log artifacts/platform-evidence/windows/ime-resize-anchor.log
```

Each supplied log must stay under `artifacts/platform-evidence/<platform>/` and
must contain common runtime markers: `MoUI native IME runtime`,
`matching-host`, `native-app`, `renderer=skia`, an app marker matching the
consumer command (`app=showcase`), and the platform protocol marker
`platform-protocol=macos-marked-text`, `platform-protocol=windows-ime`, or
`platform-protocol=wayland-text-input` (the helper also accepts documented
platform aliases). The `renderer=skia`, `app=...`, and `platform-protocol=...`
markers are matched as exact whitespace-delimited tokens, so suffixed labels do
not satisfy matching-host IME evidence. `--consumer-command` must name the platform's
`examples/showcase/<platform>_skia` entrypoint. The log must
also contain the strong marker tokens for its observation. For example,
candidate-anchor logs must include
`candidate-anchor`, `candidate-window`, `caret-rect`, and `surrounding-text`;
surrounding-text logs must include `selection-anchor`, `utf8-offsets`, and
`grapheme`; composition-visual logs must include `composition-range`,
`composition-cursor`, `preedit-underline`, `preedit-pixels`, and
`selection-highlight`; scale/DPR logs must include `scale`, `dpr`,
`candidate-anchor`, and `candidate-window`. Generic host unit-test output or
package logs are rejected. macOS logs have an extra AppKit boundary:
candidate-anchor, surrounding-text, and composition-visual logs must include
`NSTextInputClient`, `appkit-setMarkedText`, and
`appkit-firstRectForCharacterRange`; commit/delete, cursor-update,
scroll-anchor, scale/DPR-anchor, and resize-anchor logs must
include `NSTextInputClient` and `appkit-insertText`.

When collecting release evidence on a configured host, update or regenerate the
platform runtime evidence manifest with that host's results and validate it:

```sh
node scripts/record-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  windows \
  --status passed \
  --host "Windows MSVC CI" \
  --window-evidence-command \
    "wzzc-dev/window@0.5.1-0.1.4 package evidence windows --status passed --host 'Windows MSVC CI'" \
  --consumer-command \
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"" \
  --set windowOpened=yes \
  --set resizeRedraw=yes \
  --set representativeInput=yes \
  --set cleanExit=yes \
  --set surface=yes \
  --set redraw=yes \
  --set resizeScale=yes \
  --set consumerInput=yes \
  --set textInput=yes \
  --set rendererHandle=yes \
  --set monitorCursor=yes \
  --set cleanShutdown=yes \
  --set imeCandidateAnchor=yes \
  --set imeSurroundingText=yes \
  --set imeCompositionVisual=yes \
  --set imeCommitDelete=yes \
  --set imeCursorUpdate=yes \
  --set imeScrollAnchor=yes \
  --set imeScaleDprAnchor=yes \
  --set imeResizeAnchor=yes \
  --artifact artifacts/platform-evidence/windows/window-smoke.md \
  --artifact artifacts/platform-evidence/windows/showcase-run.log \
  --note "matching-host Windows evidence observed" \
  --provenance-kind github-actions \
  --provenance-host "Windows MSVC CI" \
  --provenance-workflow "MoUI CI" \
  --provenance-job "Windows MSVC native smoke" \
  --provenance-run-url "https://github.com/wzzc-dev/MoUI/actions/runs/<run-id>" \
  --provenance-run-id "<run-id>" \
  --provenance-runner "windows-2022" \
  --provenance-artifact artifacts/platform-evidence/windows/window-smoke.md \
  --provenance-artifact artifacts/platform-evidence/windows/showcase-run.log \
  --provenance-note "Windows runtime evidence came from a successful non-skipped CI job" \
  --skia-status passed \
  --skia-set providerPreflight=yes \
  --skia-set fallbackUnavailable=yes \
  --skia-set realRendererSmoke=yes \
  --skia-set showcaseFirstFrame=yes \
  --skia-artifact artifacts/platform-evidence/windows/skia-provider.log \
  --skia-artifact artifacts/platform-evidence/windows/showcase-skia-first-frame.log \
  --skia-note "matching-host Windows Skia first-frame evidence observed" \
  --skia-provenance-kind matching-host-artifact \
  --skia-provenance-host "Windows MSVC CI" \
  --skia-provenance-artifact artifacts/platform-evidence/windows/skia-provider.log \
  --skia-provenance-artifact artifacts/platform-evidence/windows/showcase-skia-first-frame.log \
  --skia-provenance-note "Windows Skia route evidence came from matching-host first-frame artifacts"
node scripts/validate-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json
node scripts/validate-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  --platform windows
```

The manifest complements Markdown snippets generated from the
`wzzc-dev/window@0.5.1-0.1.4` package smoke artifacts. Keep both scoped:
window package smoke proves dependency behavior, while MoUI platform evidence
must also name the Showcase consumer run that exercised the framework
entrypoint.
Use `--status failed` with at least one `--set <observation>=no` to record a
matching-host failure without weakening the release claim; the validator keeps
failed and pending entries distinct from passed runtime evidence.

CI runs several bounded jobs from `.github/workflows/ci.yml`:

- `Core conformance` runs the daily check, text conformance plus the diagnostic
  text matrix, and the Showcase golden build scaffold.
- `Public API surface` runs `moon info` and fails if generated
  `pkg.generated.mbti` files drift.
- `Linux platform contracts` installs Wayland development packages and runs the
  current-platform Skia/backend checks on Ubuntu. Vulkan/WGPU setup is reserved
  for the native WGPU diagnostic matrix.
- `Web runtime presentation` builds Showcase Web wasm-gc
  targets, serves the repository root, starts a Chrome DevTools Protocol
  browser session with `fonts-noto-color-emoji` installed, runs
  `record-web-runtime-presentation.mjs --require-passed`, validates the
  browser-session manifest, folds it into the Web platform entry with
  `record-platform-evidence-manifest.mjs ... web
  --web-presentation-manifest ...`, validates that Web entry, and uploads the
  presentation manifest, screenshots, browser/server logs, copied platform
  Web evidence, and `platform-runtime-evidence.json` as the
  `moui-web-runtime-presentation` artifact. Showcase's first Advanced
  Rendering card is the Web renderer-proof probe scene; passed Web proof
  requires screenshot markers plus runtime evidence events for RGBA color emoji
  glyph atlas pixels with font metadata plus glyph key/size metadata,
  one-cluster ZWJ layout, bidi visual-order reordering, paragraph line metrics
  with later-line pixels, selection rectangles with line ranges, grapheme edit
  boundaries with edit actions, IME candidate anchors with surrounding text,
  composition ranges with preedit pixels, and placeholder -> image load ->
  repaint -> ready second-frame image ordering.
- `macOS platform runtime evidence` runs automatically on `push` and can also
  be invoked manually with `run_macos_platform_runtime_evidence=true`. It initializes the platform
  evidence manifest, runs the AppKit/window package smoke, records macOS Skia
  provider/fallback/renderer/Showcase first-frame evidence, records the
  Showcase native IME runtime markers, folds the macOS platform entry with
  `github-actions` provenance, validates the macOS entry, records and validates
  `skia-native-macos.json` with `--require-passed`, and uploads
  `moui-macos-platform-runtime-evidence`. A successful non-skipped job proves
  macOS-only platform runtime readiness for that run's head SHA; it does not
  prove Windows/Linux native behavior or make the whole workflow green when
  unrelated renderer-proof summary jobs fail.
- `Native Skia renderer proof` runs macOS, Windows, and Linux matrices, writes
  renderer-proof manifests under `artifacts/conformance/renderer-proof/`,
  uploads matching `artifacts/platform-evidence/<platform>/` logs such as
  `skia-renderer-smoke.log` and `skia-text-emoji-smoke.log`, and intentionally
  leaves manifests failed until true radial/transform pixels, text/emoji glyph
  or raster evidence, and async image second-frame artifacts exist for that
  backend/platform. The Skia proof matrix configures the locked release Skia
  artifact with `--enable-skparagraph --require-skparagraph` before running the
  proof helper, so missing SkParagraph headers or libraries fail before any
  fallback paragraph geometry can be recorded. It then builds and runs
  `moui/tests/skia_renderer_smoke/native` plus
  `moui/tests/skia_text_emoji_smoke/native`; those smokes print renderer-proof
  markers only after captured Skia pixels, glyph/layout evidence, text-system
  evidence, and color emoji font/glyph metadata prove radial, transform, color
  emoji, ZWJ grapheme, bidi visual order, paragraph wrapping, selection
  rectangles plus hit testing, grapheme editing, IME candidate anchors,
  composition visuals, and async second-frame observations. Native Skia
  paragraph wrapping, bidi layout, and selection/hit-test observations must use
  the real SkParagraph path:
  `paragraphWrapping` needs `engine=skparagraph native_paragraph_ready=true
  line-metrics later-line-pixels`, `bidiLayout` needs `engine=skparagraph
  bidi_visual_order_ready=true visual-order`, and `selectionRects` needs
  `engine=skparagraph selection-rects line-range rect-geometry hit-test`.
- `Native WGPU renderer diagnostic` still runs the macOS, Windows, and Linux
  WGPU matrices and uploads artifacts, but it is `continue-on-error` and does
  not define the mainline renderer-proof summary. It records renderer-proof
  manifests without `--require-passed`, so missing experimental proof evidence
  such as native WGPU color-emoji font/glyph metadata stays visible in the
  uploaded manifest without turning the diagnostic job into a red CI gate.
- `Renderer proof summary` downloads those artifacts, requires
  `webgpu-wasm-web.json` and `skia-native-{macos,windows,linux}.json`, then runs
  `validate-renderer-proof-manifest.mjs --require-passed` on each one. This job
  runs with `always()` so skipped or failed upstream proof jobs produce an
  explicit missing/failed mainline renderer-proof signal.
- `macOS packaging smoke` packages Showcase as a local `.app`, validates the
  package manifest, and uploads the bundle artifact.
- `Benchmark scaffold` runs `sh scripts/conformance-check.sh --bench` to keep
  benchmark build targets healthy.
- `Windows MSVC native smoke` installs vcpkg `zlib:x64-windows`, imports the
  Visual Studio C++ toolchain, runs Windows backend and Skia provider tests,
  builds the Skia Showcase, packages it under `dist/windows-msvc`, validates
  the package manifest, and uploads the portable
  folder artifact.

`moui_skia` binding CI is also rooted in `.github/workflows` so GitHub Actions
can discover it while the binding is a workspace member:

- `.github/workflows/moui-skia-fallback.yml` runs fallback-safe formatting,
  check, native-smoke scaffold, status, capability, ownership, and artifact-lock
  gates from the `moui_skia` working directory on Ubuntu and Windows.
- `.github/workflows/moui-skia-real-skia-acceptance.yml` runs the release Skia
  acceptance matrix from `moui_skia` on Linux, macOS, and Windows.
- `.github/workflows/moui-skia-linux-real-skia-smoke.yml`,
  `.github/workflows/moui-skia-macos-real-skia-smoke.yml`, and
  `.github/workflows/moui-skia-windows-real-skia-smoke.yml` expose the
  platform real-Skia smoke workflows with their original manual or scheduled
  trigger shape.
- `.github/workflows/copilot-setup-steps.yml` keeps GitHub Copilot coding agent
  setup discoverable and runs MoonBit dependency setup from `moui_skia`.

Manual `workflow_dispatch` entrypoints add heavier coverage when needed:

- `run_slow_native_examples` builds current-platform native examples in the
  macOS packaging and Linux platform jobs.
- `.github/workflows/moui-real-skia-smoke.yml` runs the opt-in macOS real Skia
  renderer smoke as a separate manual workflow so the required `MoUI CI` jobs do
  not create a skipped real-Skia check on ordinary push or pull request runs.
  Its `run_showcase_smoke` and `run_markdown_smoke` inputs map to the local
  helper's `--run-showcase-smoke` and `--run-markdown-smoke` flags when a
  handoff needs current-host first-frame Showcase runtime evidence plus optional
  Markdown Editor example smoke; the workflow uploads the `moui-macos-real-skia-smoke`
  artifact with platform evidence logs under `artifacts/platform-evidence/macos/`
  and optional Markdown Editor example-smoke logs under
  `artifacts/example-smoke/macos/`.

CI now runs browser-session Web presentation automation for Showcase, including
nonblank screenshots and Web platform evidence folding. CI still does not run deterministic golden pixel diffing; the golden
job remains a build-and-capture handoff for approved screenshot comparison.
The handoff writes and validates an ignored capture manifest under
`artifacts/conformance/` so golden screenshot and benchmark captures have an
explicit, script-checked place to record the render inspector counters that
travel with the artifacts.

## Golden Screenshots And Benchmarks

Showcase is the golden source of truth for visible component coverage. Golden
tests should capture the catalog at stable desktop, tablet, and mobile
viewports, then compare screenshots against approved artifacts. Until a browser
screenshot runner is checked in, `sh scripts/conformance-check.sh --golden`
verifies that the Showcase Web wasm-gc target builds, writes and validates
`artifacts/conformance/showcase-golden-capture.json`, and prints the manual
capture handoff point. The manifest schema is guarded by
`node scripts/validate-conformance-capture-manifest.mjs`, which checks the
canonical viewports, screenshot artifact paths, render inspector counters, and
benchmark target/metric names before the scaffold reports success.

The scaffold's canonical handoff is:

```sh
sh scripts/conformance-check.sh --golden
python3 -m http.server 18080
```

Then open `http://127.0.0.1:18080/examples/showcase/web_wasm/`, capture
`1440x900`, `1024x768`, and `390x844`, and save artifacts under
`artifacts/golden/showcase-web-wasm/<viewport>.png`. Store the render inspector
counters named in `artifacts/conformance/showcase-golden-capture.json` with the
same capture set. This is deliberately a non-rendering scaffold: it does not
introduce browser automation, pixel diffing, or renderer golden assertions.

Benchmarks should use the same examples and record comparable counters:
frame-time, dirty-count, draw-command count, render inspector scope diagnostics,
startup, and memory. Until native profiling hooks are wired into CI,
`sh scripts/conformance-check.sh --bench` keeps the benchmark build targets
healthy and writes plus validates
`artifacts/conformance/showcase-benchmark-capture.json` with the Showcase and
Markdown Editor Web wasm-gc benchmark targets, metrics artifact paths, and
render-inspector metrics to collect. The canonical metrics paths are
`artifacts/benchmarks/showcase-web-wasm.json` and
`artifacts/benchmarks/markdown-editor-web-wasm.json`.

Native Skia cached-layer work also has a focused opt-in renderer benchmark:

```sh
moon run moui/tests/skia_cached_layer_benchmark/native --target native
```

It renders a fixed complex static repaint boundary plus a small animated
overlay, then compares measured `DrawCachedLayer` hit frames against full
static-content repaint frames. The benchmark prints both a readable summary and
a JSON line with frame count, average frame time, cache hit/miss/update/evict
counts, present counts, and full-repaint-to-cached speedup. Override
`MOUI_SKIA_CACHED_LAYER_BENCH_FRAMES` and
`MOUI_SKIA_CACHED_LAYER_BENCH_WARMUP` for longer local runs.

The renderer-local cache is also wired into reproducible real app scenarios:

```sh
moon run benchmarks/app_cached_layer/native --target native
```

This runs Showcase runtime scrolling, Showcase sidebar hover, Markdown Editor
text input, Markdown Editor scrolling, and Markdown Editor caret-overlay
interactions against both `draw_frame`/Skia cached-layer rendering and a
full-repaint `draw_commands` baseline. It records cache hit/miss/update/evict
counts, `BeginCachedLayer`/`DrawCachedLayer` command counts, overlay-only frame
counts, draw/render time, damage kind/dirty-rect counts, draw command counts,
rebuild/layout/paint and draw-command-build pass counters, present counts, and
a cached-vs-full speedup. Treat timing as diagnostic only. The structural
expectation is that Showcase sidebar hover stays in sibling-boundary cached
draws with local damage, Showcase runtime scrolling records stable cache hits,
Markdown Editor text input updates only the active editing content while
keeping toolbar/sidebar/outer chrome and unchanged rich-text blocks cached,
Markdown Editor scrolling reuses cached content layers, and caret/selection
overlay changes do not update the body layer. Remaining full-damage causes such
as broad dirty regions or unavailable dirty bounds should stay visible in the
printed diagnostics. Override `MOUI_APP_CACHED_LAYER_BENCH_FRAMES` and
`MOUI_APP_CACHED_LAYER_BENCH_WARMUP` for longer local runs.

The Web runtime handoff validator checks that selected Web wasm-gc examples
have HTML boot pages, browser runtime assets, wasm artifacts, and expected
compiled WebAssembly event/completion exports after build:

```sh
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/validate-web-runtime-handoff.mjs \
  --manifest artifacts/conformance/web-runtime-handoff.json
node scripts/validate-web-runtime-handoff-manifest.mjs \
  artifacts/conformance/web-runtime-handoff.json
python3 -m http.server 18080
node scripts/validate-web-runtime-handoff.mjs --base-url http://127.0.0.1:18080
```

This is still a static delivery and HTTP availability check. It does not claim
that Browser WebGPU device creation, wasm instantiation, canvas presentation, or
pixel output succeeded; collect those with browser automation or manual browser
evidence before changing Web runtime entries from pending to passed.
Run `sh scripts/dev-check.sh --theme-diagnostics` first when you need the
Design Systems addon Web target included in local validation.

The optional manifest records the checked runtime assets, target HTML/wasm
paths, compiled WebAssembly exports, file/HTTP checks, and the same evidence
boundary so release handoffs can cite a structured artifact rather than console
output alone.

When a local browser with Chrome DevTools Protocol access is available, collect
browser-session Web runtime presentation evidence separately from the static
handoff check:

```sh
python3 -m http.server 18080 --bind 127.0.0.1
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless=new \
  --remote-debugging-port=9223 \
  --user-data-dir=/tmp/moui-web-runtime-presentation \
  about:blank
node scripts/record-web-runtime-presentation.mjs \
  --base-url http://127.0.0.1:18080 \
  --cdp-url http://127.0.0.1:9223 \
  --manifest artifacts/conformance/web-runtime-presentation.json \
  --require-passed
node scripts/validate-web-runtime-presentation-manifest.mjs \
  artifacts/conformance/web-runtime-presentation.json \
  --require-passed
node scripts/record-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  web \
  --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json
node scripts/validate-platform-evidence-manifest.mjs \
  artifacts/conformance/platform-runtime-evidence.json \
  --platform web
```

The presentation recorder opens Showcase's Advanced Rendering section through
the named browser session, injects a read-only
browser-runtime event observer, waits for the page status, records
WebGPU/wasm/canvas signals, performs a viewport resize, representative pointer
and keyboard/text input, closes the CDP target, writes
screenshots under
`artifacts/conformance/web-runtime-presentation/`, and validates
`artifacts/conformance/web-runtime-presentation.json`. A passed manifest is
stronger than the handoff artifact because it proves browser-local WebGPU
startup, wasm app startup, canvas sizing, resize/input event-bridge delivery,
clean target close, clean console, nonblank screenshot thresholds, and Showcase
transform-scene pixel markers for that Chrome session. It is still not
cross-browser coverage, deterministic pixel-golden proof beyond the recorded
marker thresholds, or native platform runtime evidence. If the local browser
cannot create a WebGPU adapter or device, keep the manifest failed or omit it
from release claims; do not use the static handoff artifact as a substitute for
passed browser presentation evidence. The platform recorder can also consume a
failed presentation manifest; it then marks the Web platform entry failed and
records the negative observations so release notes can cite a structured reason.
If the CDP browser is unavailable during recorder startup, the recorder still
writes a failed `web-runtime-presentation.json` with negative Showcase
observations before exiting nonzero; validate that artifact without
`--require-passed` when documenting the environment limit.
When the presentation manifest passes with all browser-observable platform
observations set to `yes`, `record-platform-evidence-manifest.mjs ... web
--web-presentation-manifest ...` records the Web platform entry as passed for
that browser session. The Web entry may keep `monitorCursor` pending because
browser CDP evidence does not prove native monitor/current-monitor or cursor
probes. The browser-session manifest remains the runtime evidence artifact:
GitHub Actions provenance is added only when the fold runs inside a non-skipped
successful Actions job that also uploads those artifacts. A CI run URL, runner,
or job name is not a substitute for a passed browser-session manifest.

Renderer-proof manifests are separate from the platform runtime manifest. They
live under `artifacts/conformance/renderer-proof/<backend>-<platform>.json` and
use schema v1 with exactly these observations: `radialGradient`,
`transformPixels`, `colorEmojiPixels`, `zwjGrapheme`, `bidiLayout`,
`paragraphWrapping`, `selectionRects`, `graphemeEditing`,
`imeCandidateAnchor`, `imeCompositionVisual`, and `asyncImageSecondFrame`.
Passed manifests must carry GitHub Actions provenance and strong marker tokens;
`colorEmojiPixels` also
requires `font-metadata` / `glyph-metadata` evidence plus structured
`metadata.font` and `metadata.glyph` fields so high-saturation emoji pixels can
be traced to the font/glyph path that produced them. Native Skia
`colorEmojiPixels` additionally requires `fallback-request`, `emoji-hint`, and
`stable-glyph-key` tokens, tying the proof to the FontMgr fallback request and
the stable glyph metadata path. Passed native Skia manifests must also preserve
fallback script/language tag-list/count metadata, fallback request character metadata,
resolved missing-glyph metadata, and missing-glyph recovery metadata, and the
glyph key must include the recorded source, text-system, shaper, script,
language tags, language-count, fallback request character, and format fields before the color
emoji observation can pass.
The text/IME observations
must prove selection rectangles with line ranges, positive geometry, and hit testing, grapheme edit
boundaries with edit actions, IME candidate anchors with surrounding text, and
composition ranges with preedit pixels. Native Skia `imeCandidateAnchor`
observations must also include grapheme-boundary cursor/anchor evidence and
UTF-8 offset evidence from host IME diagnostics, including normalized
`nearest_boundary_utf8_offset` conversion. Native Skia
`imeCompositionVisual` observations must also include `composition-cursor`
evidence. Native Skia `paragraphWrapping`,
`bidiLayout`, and `selectionRects` must be SkParagraph observations with
`engine=skparagraph` markers, not fallback paragraph geometry or heuristic
visual-order logs; the
native Skia CI proof job configures `moui_skia` with required SkParagraph
support before running these smokes.
Native Skia `graphemeEditing`, `imeCandidateAnchor`, and
`imeCompositionVisual` markers come from the text/emoji smoke's shared
grapheme-boundary contract, host IME request diagnostics including UTF-8 cursor
and anchor offsets plus composition cursor geometry, Skia caret geometry, and
captured text-field composition pixels. They are renderer-proof
observations only; matching-host platform IME evidence is still recorded in the
platform runtime manifest through `record-native-ime-evidence.mjs`.
Package tests, skipped jobs, blank screenshots,
missing uploaded artifacts, caret-only diagnostics, coverage-only font
matching, package-only checks, provider preflights, preflight-only checks, and
fallback-safe descriptor audits remain failed renderer proof. CI summary
validates them with the
downloaded artifact directory as `--artifact-root`, so a manifest cannot pass
unless its referenced logs/artifacts were actually uploaded. When the recorder
runs outside GitHub Actions, complete observation markers are still preserved in
the manifest, but the manifest-level status remains `failed`; local
renderer-proof files are diagnostics until the CI proof matrix records them
with GitHub Actions provenance. Use the recorder tests before changing the
schema or marker vocabulary:

```sh
node scripts/test-validate-renderer-proof-manifest.mjs
node scripts/test-record-renderer-proof-manifest.mjs
node scripts/test-record-web-renderer-proof-manifest.mjs
sh -n scripts/ci-renderer-proof-native.sh
sh -n scripts/ci-renderer-proof-summary.sh
```

## Release-Oriented Checklist

Before a broad handoff or release candidate:

```sh
sh scripts/dev-check.sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
moon info
```

Also confirm README and docs mention current commands, platform constraints,
example paths, and renderer capability status. If the release includes warning
cleanup, include `moon check --warn-list +unnecessary_annotation` and review the
remaining diagnostics explicitly.
>>>>>>> Stashed changes
