---
name: moui-framework-development-skill
description: Use this skill when developing or maintaining the MoUI MoonBit GUI framework itself, including core runtime, opaque View/layout/state/input, renderers, platform backends, examples used as framework validation, renderer capability tracking, documentation, and validation commands.
version: 0.1.0
---

# MoUI Framework Development Skill

## Purpose

This skill is for developing MoUI itself. It complements general MoonBit
guidance by pinning MoUI's package boundaries, runtime invariants, renderer
capability rules, platform contract, and validation commands.

## When To Use

Use this skill when editing or reviewing:

- `core/` runtime, state, layout, input, semantics, or draw commands.
- `views/` public constructors and modifiers.
- `backend/host`, `backend/web`, `backend/macos`, `backend/windows`, or
  `backend/linux`.
- `render/`, `render/wgpu`, `render/skia`, or `render/webgpu_adapter`.
- `backend/<platform>/wgpu` or `backend/<platform>/skia` native renderer
  provider packages.
- `examples/*/app` shared app logic or platform example entrypoints when they
  are being used as framework examples or validation coverage.
- `docs/*`, README, roadmap, testing docs, or AI collaboration materials.
- Renderer capability status, Showcase capability display, or validation
  scripts.

## First Files To Read

1. `AGENTS.md`
2. `README.md`
3. `docs/architecture.md`
4. `docs/development.md`
5. `docs/platform-notes.md`
6. `docs/text-system.md` when touching text measurement, shaping, fonts, or
   provider startup options
7. `docs/renderer-capability-report.md`
8. `docs/testing.md` when validation scope matters
9. `docs/release-readiness.md` when planning preview-release gates or gap
   closure
10. `docs/view-catalog.md` when touching `views/`
11. `docs/examples.md` when touching examples
12. `docs/markdown-editor.md` when touching the Markdown Editor

## Project Invariants

- Public view constructors return opaque `@core.View[Msg]`.
- Runtime pipeline:

  ```text
  View[Msg] -> internal view tree -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawFrame(commands + platform_views) -> renderer + host platform views
  ```

- `core/` stays platform-neutral.
- `BuildContext`-owned state listeners from `watch`, `watch_derived`,
  `binding`, and `saveable` must be stored in `BuildContext.subscriptions` so
  rebuild and unmount cancel stale handles.
- `Program`, `Effect[Msg]`, and `Subscription[Msg]` are the default app model
  surface: pure apps use `Program::simple`, environment-aware apps use the
  `*_with_environment` constructors, effect-capable apps use `Program::new`
  with `Effect::send`, `Effect::dispatch`, structured `Effect::run`,
  structured host-service `Effect::host_service`, standard service-like
  cancellable `Effect::service_task`, or custom one-shot cancellable
  `Effect::task`, and app-level ongoing event sources use
  `subscriptions=model => ...` with stable keys so callbacks re-enter the typed
  message loop without exposing runtime internals. `Subscription::timer`,
  `Subscription::animation_tick`, `Subscription::window_event`,
  `Subscription::host_event`, `Subscription::route_event`, and
  `Subscription::service_completion` standardize common descriptor kinds while
  concrete event adapters remain outside `core`. Effect diagnostics stay
  platform-neutral through `Effect::plan_summary`, distinct anonymous-dispatch
  vs structured-run/task counters, `Effect::run` / `Effect::host_service` /
  `Effect::service_task` / `Effect::task` descriptors,
  duplicate descriptor-key counts/names in effect summaries plus aggregate
  duplicate descriptor-key counters/names on program-runtime and inspector
  snapshots, active/completed/cancelled effect-task lifecycle snapshots, stale
  effect-task dispatch counters, same-key task descriptor-kind changes reported
  with `EffectTaskKindChanged`, ignored program-dispatch counters for late
  callbacks after runtime destruction, and aggregate program-runtime inspector
  counters; message queue drains are bounded runtime turns so synchronous
  click/effect/task/subscription self-queues keep FIFO order but leave excess
  work pending instead of monopolizing the current host callback, then resume
  that pending work FIFO on the next host callback; message queue diagnostics
  stay platform-neutral through enqueue/drain/pending counters;
  pipeline cost
  diagnostics stay platform-neutral through rebuild/layout/paint/draw-command
  pass counters and non-mutating structured dirty-state summaries with dirty
  element ids, damage kind/rect/full-reason summaries, cache epoch, and
  cached-layer counts for pending rebuild/layout/paint/redraw work; subscription
  diagnostics stay
  platform-neutral through
  `Subscription::plan_summary`, planned and active subscription descriptors,
  active subscription kind-count summaries, duplicate subscription-key
  counts/names in plan summaries plus aggregate
  duplicate subscription-key counters/names on program-runtime and inspector
  snapshots, subscription lifecycle/plan counters, same-key kind-change
  restarts reported with `SubscriptionKindChanged`, and ignored stale-dispatch
  counters for
  callbacks captured by canceled or destroyed subscription lifetimes; effect
  runners and subscription adapters still own any concrete async work outside
  `core`.
- Platform packages normalize native events into `@host.HostEvent`.
- Backends do not mutate element or render trees directly.
- Renderers consume platform-neutral `@core.DrawCommand` values. Native
  platform views such as `web_view` travel through `DrawFrame.platform_views`
  and are synced by host backends, not by renderer packages or `DrawCommand`.
- `examples/*/app` packages own shared app logic.
- Platform example packages should stay thin entrypoints.
- Web is `wasm-gc + window/web + browser WebGPU host imports`; there is no
  JS-target fallback.
- Linux has a Wayland backend with Skia as the native preview mainline,
  host-service wiring for system theme, Wayland clipboard selection, desktop
  URL/file-dialog/text-file/menu services, text-input/IME request sync, file
  drag/drop conversion, AT-SPI accessibility binding, and scale-factor
  reporting. Keep matching-host runtime observation and native WGPU/fontconfig
  text-provider gaps explicit.
- Public API changes require `moon info` and review of `pkg.generated.mbti`
  diffs, followed by `node scripts/validate-api-surface.mjs` so the root
  facade, `views`, `core`, host contracts, and renderer packages stay within
  their documented tiers.
- Maintenance baseline changes require `node scripts/validate-maintenance-baseline.mjs`;
  when splitting oversized files, reducing source-level `pub(all)`, moving
  widget-level entrypoints from `core` to `views`, or shrinking root facade
  forwards, lower the matching ratchet budget in the same change.
- Renderer capability changes require synchronized updates to code, tests, docs,
  and Showcase when visible.
- Conformance work uses four layers: `core` contract tests, `backend/host` and
  platform routing tests, renderer/provider implementation tests, and matrix or
  diagnostic tests under `moui/tests/*_conformance` plus
  `scripts/conformance-check.sh`.
- Guidance changes are part of the maintenance surface: when architecture,
  package layout, validation commands, docs placement, examples, renderer
  capabilities, platform behavior, or text architecture changes, check
  `AGENTS.md` and repo-local skills too.

## Package Map

- `core/`: one MoonBit package for platform-neutral contracts, view specs,
  state, app-owned route/history helpers, `Program` / `Effect` /
  `Subscription`, layout, input, semantics, rich text editing, draw commands,
  styles, theme tokens, and the transitional runtime kernel while implementation
  moves to `moui/runtime`. Keep files grouped by responsibility
  (`runtime_state`,
  `component_context`, `input_*`, `paint_*`, `rich_text_*`) without adding
  subpackages.
- `runtime/`: app/host runtime entrypoint package exposing an opaque
  `AppRuntime` wrapper over the current core runtime kernel. New app, backend,
  smoke, and tooling code should use `@runtime.AppRuntime`,
  `@runtime.new_view`, or `@runtime.new_program` instead of direct
  `@core.AppRuntime`.
- root `moui`: public facade over curated
  `View`/`Program`/`Effect`/`Subscription`/`Theme` aliases. Neutral
  default/light/dark theme helpers and custom `@core.Theme` builder APIs live
  in `moui/views`.
  Diagnostics, draw-command records, renderer-facing records, and low-level
  implementation payloads stay in their owning packages. It does not import
  `moui_theme`.
- `moui_theme/common/`: repo-local addon common package for shared
  source-mapped design-system
  manifests, golden token mappings, golden source-usage audits,
  source-lock quality reports, source-package inventories,
  source-imported token records with pinned file shas, raw source expressions,
  official-anchor coverage gaps, manifest/golden integrity reports, runtime
  token alignment reports for resolved source values,
  official-token/source-lock coverage, adaptation-difference reports,
  token taxonomy reports, semantic palette role reports, typography role reports,
  component-token matrices, semantic/component token models, density and
  variant adapters, coverage metadata, and custom token/theme helpers that return
  platform-neutral
  `@core.Theme` values; it may depend on `wzzc-dev/moui/core`, while
  `moui/core`, `moui/views`, and the root `wzzc-dev/moui` workspace member must
  not depend on `moui_theme`. `moui_theme/material`, `moui_theme/carbon`,
  `moui_theme/primer`, and `moui_theme/fluent` expose package-local
  official-system entrypoints over the common model for light/dark/high-contrast
  and system themes, tokens, manifests, reports, and component matrices.
  Concrete design-language names stay here rather than in `core` or `views`.
  External presets stay source-mapped previews until
  tests prove
  official source, token category, variant, component-token, customization,
  official-token golden mapping coverage, golden mapping source usage, stable
  source version locks, source-package import coverage,
  source-imported token source-lock coverage, source-imported token
  official-anchor coverage, source-imported token manifest/golden integrity,
  runtime token alignment, token taxonomy parity, semantic palette role parity,
  typography role parity,
  component-token matrix coverage plus
  adaptation-difference closure.
- `views/`: public view constructors returning opaque `@core.View[Msg]`. App,
  host, smoke, and cross-package tests should use `views` widget-level
  entrypoints instead of direct `@core.View::*` control constructors while core
  still owns internal node payloads.
- `backend/host/`: shared `HostEvent`, surface metrics, input contracts,
  window lifecycle registry, window scene resolver, per-window runtime slot
  collection, platform-window id map, renderer-neutral `HostWindowRenderer`
  diagnostics, render-frame cached-layer fallback command replay, image-resource change callback bridge, image-resource repaint
  routing and tracked-window revision/status diagnostics plus repaint-result
  previous/current status counts,
  image-resource load completion apply bridge,
  native async image loading-record scheduler,
  native provider async-image scheduling hooks,
  native async image completion source and deferred native completion request source,
  host-event subscription source fanout, window-scoped subscription source,
  platform event-source bundles for feeding normalized Web/native host and window
  events into app-owned subscriptions,
  scheduler-backed timer subscription source, route/deep-link subscription source,
  window request/completion queue, text-input session, window-event conversion,
  async host-service queue, and frame-aware redraw driver with
  idle/scheduled/in-frame/follow-up coalescing, and native WebView
  capability/command/event contracts.
- `backend/web/`: wasm-gc Web host, canvas constraints, resolver-backed
  multi-canvas window slots, browser runtime bridge, async browser
  file-open/save text completion for shared text-file reads/writes, and
  accessibility adapter. Web reports `web_view` unavailable and must not use an
  iframe overlay as a substitute for native WebView.
- `backend/macos/`: AppKit/window host, resolver-backed multi-window slots,
  native WKWebView platform-view sync, and CAMetalLayer WGPU surface creation.
- `backend/windows/`: Win32/window host, resolver-backed multi-window slots,
  optional WebView2 platform-view sync, and HWND WGPU surface creation.
- `backend/linux/`: Wayland host over `wzzc-dev/window@0.5.1-0.1.4`, Linux
  host-service bridge, text-input/IME request sync, drag/drop conversion, a
  native Skia mainline presenter path plus native WGPU diagnostic surface path,
  optional WebKitGTK platform-view sync, shared host event conversion, and
  AT-SPI accessibility binding.
- `render/`: renderer facade, shared draw helpers, and capability report API.
- `render/skia/`: native Skia raster mainline renderer over the local
  `moui_skia` binding, including renderer-local command/reason diagnostics for
  unsupported Skia fallbacks, renderer-local image-resource lifecycle change
  callbacks, and `skia_image_load_completion` source decode completion payloads
  plus opt-in post-present async image loading for native providers. The
  binding/renderer may expose an explicit macOS Metal/Ganesh GPU context and
  offscreen GPU surface preflight, but provider/window GPU presentation remains
  separate matching-host smoke and must not replace the raster mainline without
  real smoke logs. Host-layer completion routing and native
  provider/platform redraw scheduling from async image load/error notifications
  remain outside `render/skia`.
- `render/wgpu/`: experimental native wgpu renderer, including source decode
  completion helpers used by provider-owned native image loader hooks.
- `render/wgpu/cosmic_text/`: standalone Moon Cosmic provider.
- `render/wgpu/coretext/`: macOS CoreText provider.
- `render/wgpu/directwrite/`: Windows DirectWrite scaffold.
- `render/wgpu/fontconfig/`: Linux fontconfig/FreeType provider boundary with
  a narrow native color-emoji path and Cosmic fallback for general text.
- `render/wgpu/text_protocol/`: shared native text provider payload protocol.
- `render/webgpu_adapter/`: wasm-gc bridge to browser WebGPU host imports.
- `moui/tests/skia_renderer_smoke/native`: opt-in real-Skia renderer smoke that
  verifies MoUI draw commands against captured Skia presenter pixels and checks
  async image second-frame repaint through the host completion route.
- `moui/tests/skia_text_emoji_smoke/native`: opt-in real-Skia text/emoji smoke
  that reports captured Skia pixels, font/glyph metadata, color emoji, ZWJ
  grapheme, paragraph wrapping, bidi layout, selection rectangles, grapheme
  editing, IME geometry, and async image second-frame markers. Native paragraph
  wrapping, bidi layout, and selection-rectangle smoke should use the real
  SkParagraph path and include `engine=skparagraph` markers.
- `moui/tests/text_conformance/{native,web}`: opt-in diagnostic text matrix
  packages for comparing supported text systems and documented gaps.
- `examples/*/app`: shared application logic.
- `examples/*/{web_wasm,<platform>_<renderer>}`: platform/renderer profile
  entrypoints where an example has a runnable host package.
- `examples/webview_demo/{app,macos_skia,windows_skia,linux_skia,web_wasm}`:
  native WebView host-contract demo; Web wasm is an unavailable fallback and
  not an iframe implementation.
- `examples/showcase/{macos_skia,windows_skia,linux_skia}` and
  `examples/markdown_editor/{macos_skia,windows_skia,linux_skia}`: recommended
  native Skia renderer example entrypoints.
- `examples/design_systems/{web_wasm,macos_skia,windows_skia,linux_skia}`:
  dedicated design-system addon diagnostic sampler entrypoints over the shared
  `examples/design_systems/app` logic.
- `examples/pdf_workbench/app`, `examples/pdf_workbench/pdflite_adapter`, and
  `examples/pdf_workbench/macos_skia`: lightweight PDF UI shell, separate
  `pdflite` adapter checks, and native Skia mainline entrypoint.
- `examples/showcase/{macos_wgpu_cosmic,windows_wgpu_cosmic,linux_wgpu_cosmic}`: explicit Moon
  Cosmic text-provider comparison entrypoints on the native WGPU diagnostic
  route.

## Development Workflow

1. Confirm the user goal and non-goals.
2. Read the relevant docs and `moon.pkg` package boundary.
3. Prefer `moon ide doc`, `moon ide outline`, `moon ide peek-def`, and
   `moon ide find-references` for MoonBit API discovery.
4. Keep edits small and package-local.
5. Preserve `///|` delimiters.
6. Add or update focused package tests.
7. Run targeted validation first.
8. Run `moon fmt`.
9. Run `moon info` after public API changes.
10. Update docs, `AGENTS.md`, and repo-local skills when guidance changes.
11. Report changed files, validation commands, and remaining risks.

## Validation Commands

Daily check:

```sh
sh scripts/dev-check.sh
```

The daily check runs `sh scripts/check-local-deps.sh`, which verifies
`wzzc-dev/window@0.5.1-0.1.4`, confirms `moon.work` does not include a local
window checkout, verifies the repo-local `moui_skia` workspace, and checks the
window package's MoUI-oriented smoke/observation files when the package is present
in the MoonBit registry cache, including `scripts/record_moui_evidence.sh`.
Use `scripts/run-window-package-smoke.sh <platform>` for matching-host smoke
runs from the resolved package instead of creating a local window checkout. Run
`moon update` if the package cache is stale or missing. The MoonBit package
ecosystem is still maturing, so dependency resolution, registry cache state, and
package regressions are plausible causes for otherwise surprising failures.
Treat those window smoke helpers as dependency-level matching-host observation,
not as a replacement for MoUI Showcase/Markdown Editor platform entrypoint
validation.
The same local-dependency check also requires the `moui_skia` binding workspace's
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`,
and verifier scripts, then runs
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`. Treat
that as binding-level Skia provider/status and native capability observation; MoUI
renderer pixels and platform runtime behavior still need the opt-in real-Skia
smoke or matching-host example runs.
The runnable `moui_skia` GitHub Actions workflows live in the repository root
as `.github/workflows/moui-skia-*.yml`, and Copilot setup lives at root
`.github/workflows/copilot-setup-steps.yml`. Keep workflow files there while
`moui_skia` is a workspace member; nested workflow files are not discovered by
GitHub Actions in the monorepo.
Daily `dev-check` also runs the MoonBit-backed maintenance baseline ratchets,
API surface guard, guidance consistency, renderer/provider and native Skia
entrypoint static checks, and app/Web checks for Showcase and Markdown Editor. Use
`sh scripts/dev-check.sh --theme-diagnostics` for `moui_theme` and Design
Systems addon diagnostic coverage. Keep `docs/testing.md` and repo-local skills
synchronized when adding or removing daily quality gates. It also validates the
checked-in `smoke/gates.json` smoke gate catalog with
`node scripts/smoke-check.mjs --check`; default `dev-check` checks the catalog
shape, not real browser or platform smoke execution. The scheduled/manual CI
entrypoint for those opt-in gates is
`.github/workflows/moui-runtime-smoke-gates.yml`.

Manual smoke is opt-in. Browser-session smoke uses
`scripts/ci-web-runtime-presentation.sh`, which builds Showcase, starts a local
HTTP server and Chrome CDP, records a local manifest under
`artifacts/smoke/web-runtime-presentation/`, and validates that browser
session. `smoke/gates.json` maps daily, nightly, and release suites to their
commands, structured result shapes, docs, workflows, and ignored artifact
outputs. Native renderer/platform smoke should cite the CI run, uploaded
artifact, or local smoke log that was actually inspected. Do not commit
generated `artifacts/` JSON as the long-term capability source of truth.

Focused checks:

```sh
moon test moui/core --target native
moon test moui/runtime --target native
moon test moui/views --target native
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test moui/render --target native
moon test moui/render/skia --target native
moon run moui/tests/skia_cached_layer_benchmark/native --target native
moon run benchmarks/app_cached_layer/native --target native
moon check moui/tests/skia_text_emoji_smoke/native --target native
moon test moui/render/webgpu_adapter --target wasm-gc
node scripts/test-webgpu-runtime-radial.mjs
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
node scripts/validate-skia-entrypoints.mjs
node scripts/test-validate-skia-entrypoints.mjs
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/design_systems/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/design_systems/web_wasm --target wasm-gc
moon build examples/markdown_editor/macos_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/pdf_workbench/windows_skia --target native
moon build examples/pdf_workbench/linux_skia --target native
moon build examples/markdown_editor/windows_skia --target native
moon build examples/markdown_editor/linux_skia --target native
node --check scripts/validate-conformance-capture-manifest.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/validate-web-runtime-handoff.mjs
node scripts/test-validate-web-runtime-handoff.mjs
node --check scripts/test-browser-runtime-events.mjs
node scripts/test-browser-runtime-events.mjs
node --check scripts/validate-web-runtime-handoff-manifest.mjs
node scripts/test-validate-web-runtime-handoff-manifest.mjs
node --check scripts/record-web-runtime-presentation.mjs
node scripts/test-record-web-runtime-presentation.mjs
node --check scripts/validate-web-runtime-presentation-manifest.mjs
node scripts/test-validate-web-runtime-presentation-manifest.mjs
node --check scripts/smoke-check.mjs
node --check scripts/test-smoke-check.mjs
node scripts/test-smoke-check.mjs
node scripts/smoke-check.mjs --check
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_break_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_break_fixture --test-name "unicode 17 grapheme break fixture samples" --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_editing_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_editing_fixture --test-name "unicode 17 grapheme editing fixture samples" --actual-kind core-editing --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_layout_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_layout_fixture --test-name "unicode 17 grapheme layout fixture samples" --actual-kind core-layout --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/render/skia/skia_grapheme_break_unicode_17_wbtest.mbt --helper-name assert_skia_unicode_17_grapheme_break_fixture --test-name "skia unicode 17 grapheme break fixture samples" --actual-kind skia-clusters --check
node --check scripts/generate-grapheme-property-data.mjs
node scripts/generate-grapheme-property-data.mjs --grapheme-property <Unicode-17.0.0-GraphemeBreakProperty.txt> --emoji-data <Unicode-17.0.0-emoji-data.txt> --derived-core-properties <Unicode-17.0.0-DerivedCoreProperties.txt> --check
sh -n scripts/ci-web-runtime-presentation.sh
node --check scripts/validate-package-manifest.mjs
```

For PDF Workbench app-only or `pdflite_adapter` checks, set
`MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1` unless the native PDFium raster adapter
is under test.

Run `sh scripts/dev-check.sh --wgpu-experimental`,
`sh scripts/conformance-check.sh --render --wgpu-experimental`, or focused
`moui/render/wgpu` / WGPU-provider tests only when touching the native WGPU
diagnostic route.

Platform validation:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
```

Use `--platform-examples-test` for normal current-host backend/provider checks.
Skia providers are the native mainline; run `moui/backend/<platform>/wgpu`
tests directly only on the matching host/toolchain when investigating the
native WGPU diagnostic provider.
macOS/Windows/Linux Skia provider tests cover the public
`*_skia_provider_preflight_summary()` package-audit surface for renderer
availability, `moui_skia/native` availability, selected font resolution, and
presenter identity, the `HostWindowRenderer` bridge that forwards Skia
text-system, image-resource snapshots, image-resource change callbacks,
present-count, and disposal diagnostics, inherited host service/input/window readiness,
clipboard/menu/file-dialog/open URL/system-theme/async-service readiness,
text-input/IME/drag-drop readiness, native context-menu readiness, host-modal
file-dialog readiness, native accessibility status, and the
first-frame smoke option state. Treat those
summaries as preflight diagnostics only; macOS first-frame and IME smoke now
run through `moui_tester`, while ordinary Showcase and Markdown Editor
entrypoints stay as direct app entrypoints. Windows/Linux ordinary Skia
entrypoints do not carry auto-exit smoke flags; add matching tester/backend
smoke runners when platform first-frame logs are needed. Windows/Linux Skia entrypoints use
`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1`, or
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for matching-host
auto-exit first-frame logs. For Linux, keep Showcase, Markdown Editor, and
`scripts/run-window-package-smoke.sh linux --run` logs separate because the
first two are app-level Skia evidence and the window package smoke is
dependency-level Wayland evidence.

Windows native uses Visual Studio C++ build tools and vcpkg `zlib:x64-windows`.
Use `scripts/windows/msvc_env.ps1` through the renderer-aware MSVC helpers and
validate with `scripts/windows/build_windows_msvc.ps1` or
`scripts/windows/package_windows_app_msvc.ps1`. Native Skia packages are the
mainline and do not bundle `wgpu_native.dll`; explicit native WGPU diagnostic
packages keep the MSVC dynamic WGPU path.

Real macOS Skia renderer smoke:

```sh
scripts/macos-skia-renderer-smoke.sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-gpu-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke \
  --markdown-log artifacts/example-smoke/macos/markdown-macos-skia-first-frame.log
scripts/macos-skia-renderer-smoke.sh --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
scripts/macos-skia-renderer-smoke.sh --skia-provider source
```

The GitHub Actions wrapper for this MoUI-level macOS real-Skia smoke is
`.github/workflows/moui-real-skia-smoke.yml`. Keep it as a separate
`workflow_dispatch` workflow so ordinary required `MoUI CI` push and pull
request checks do not report a skipped real-Skia job.

The helper resolves JetBrains, existing, or source-built Skia providers,
temporarily configures the local `moui_skia` and MoUI Skia smoke packages, runs
the renderer pixel smoke, optionally builds Showcase and runs the
`moui_tester` first-frame smoke, optionally builds Markdown Editor with
`--run-markdown-smoke` and runs the same tester-owned marker, optionally
runs the explicit macOS Metal/Ganesh route smoke with `--run-gpu-smoke`, and
restores touched `moon.pkg` files. The GPU route smoke enables
`MOUI_SKIA_ENABLE_GPU_METAL`, requires the
`MoUI Skia GPU Metal renderer smoke passed` marker, sets
`MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu` for tester-owned first-frame/IME
smoke runs, and requires those logs to include
`surface_route=metal-gpu; surface_gpu=true` provider diagnostics. That proves
offscreen GPU surface rendering/readback through the existing pixel presenter
plus app first-frame presentation; it is still separate from direct
platform-window GPU presentation observations. Direct Skia
`moon run`/`moon build` commands use the
`moui_skia` prebuild hook for real Skia and choose the library mode through
`MOUI_SKIA_LINK_MODE=dynamic|static|auto`; helper smoke runs can pass
`--link-mode dynamic|static|auto` to override the environment for that
invocation. For paragraph/bidi smoke runs, pass `--enable-skparagraph` and
`--require-skparagraph` so missing SkParagraph, SkShaper, SkUnicode, HarfBuzz,
or ICU headers/libraries fail before the smoke can pass. Normal macOS Skia
entrypoints default to the system
`FontMgr` text path; first-frame smoke entrypoints explicitly select
`EmptyTypeface`. Windows and Linux should keep the same smoke-only
font-resolution switch in tester/backend smoke runners rather than ordinary
example entrypoints.

Public API review:

```sh
moon info
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
```

## Playbooks

### Add A View

- Implement in `views/` using public `@core.View[Msg]` constructors and modifiers,
  styles, and bindings.
- Add focused tests in `views/views_test.mbt`.
- Add Showcase coverage if the view is user-facing and visual.
- Update `docs/view-catalog.md`.
- Run `moon test moui/views --target native`, `moon fmt`, and `moon info` if public.

### Change Renderer Capability

- Keep the boundary at `@core.DrawCommand`.
- Update renderer implementation and tests.
- Update `render/capabilities.mbt`.
- Update `render/capabilities_test.mbt`.
- Update `docs/renderer-capability-report.md`.
- Update Showcase if the capability is visible.
- Run renderer tests and a Showcase Web wasm-gc build.

### Change Text System Or Provider

- Keep `core/` limited to `TextSystem`, `FontSpec`, fallback measurement,
  paragraph layout geometry, and platform-neutral text geometry.
- Put native provider work in the relevant `render/wgpu/*` package.
- Put Skia-backed measurement, glyph-run, font fallback, and diagnostic text
  system work in `render/skia`.
- Keep `render/wgpu` responsible for provider validation, fallback composition,
  glyph atlas upload, and cache-key discipline.
- Keep Web measurement and glyph drawing aligned through `backend/web` and
  `render/webgpu_adapter`.
- Update `docs/text-system.md` and renderer capability docs when shaping,
  provider behavior, embedded fonts, or text gaps change.
- Run focused core, renderer, Web adapter, backend, provider, and text
  conformance tests.

### Change Backend Event Handling

- Keep platform-specific code inside the platform backend.
- Normalize through `backend/host` and `HostEvent`.
- Add or update `backend/host` tests when shared behavior changes.
- Use `HostServiceAsyncQueue` for permission- or callback-driven services
  instead of pretending browser/platform async work completed synchronously.
- For app-owned pending services, expose a typed completion path through
  `HostAppServices::completion_subscription` so callbacks re-enter an app
  `Program` subscription instead of teaching `HostRuntimeDriver` about app
  messages. Subscription cleanup should release the host queue handler so late
  platform responses remain available as completed records instead of
  dispatching into stale app state. Keep lower-level
  `HostAppServices::on_completed` available for custom adapters.
- For app-owned host-event sources, use `HostEventSource::subscription` in
  `backend/host` so normalized `HostEvent` values can fan out to typed
  `Program` messages through `Subscription::host_event`. Keep platform event
  conversion in platform packages, and make adapter cleanup remove the publisher
  handler so late host events do not reach stale app subscriptions.
- For app-owned window-event sources, use `HostWindowEventSource::subscription`
  in `backend/host` so normalized `HostEvent` values keep their `HostWindowId`
  while entering typed `Program` messages through `Subscription::window_event`.
  Keep raw platform event conversion in platform packages, and make adapter
  cleanup remove the publisher handler so late window events do not reach stale
  app subscriptions.
- Use `HostPlatformEventSources` when a Web or native platform app needs to
  expose its normalized runtime host/window event stream to app-owned
  subscriptions. The backend should publish only after raw platform events have
  been converted and dispatched through the matching `HostRuntimeDriver`;
  route/history and timer adapters remain separate platform/app concerns.
  `backend/web` owns the browser history bridge for initial route,
  `pushState`/`replaceState`, `back`/`forward`, and `popstate` publication
  through `HostRouteSource`.
- For app-owned route/deep-link sources, use `HostRouteSource::subscription` in
  `backend/host` so published `HostRouteEvent` values can map to typed
  `Program` messages through `Subscription::route_event`. Keep Web browser
  history wiring in `backend/web`, native URL bars, OS deep-link dispatch, and
  app history mutation in platform/app code, and make adapter cleanup remove
  the publisher handler so late route events do not reach stale app
  subscriptions.
- For app-owned timer sources, use `HostTimerSource::subscription` in
  `backend/host` so platform/app schedulers can map `@core.Frame` ticks to typed
  `Program` messages through `Subscription::timer`. Keep platform clock
  scheduling outside `core`, pass the requested interval to the host scheduler,
  and make adapter cleanup cancel the scheduler so late callbacks hit the stale
  subscription-dispatch guard instead of live app state.
- For native async image completions, route provider/platform loader completion
  results through `ImageResourceLoadCompletion` and
  `HostWindowRenderer::apply_image_resource_load_completion`, then route the returned
  snapshots through `HostImageResourceCompletionSource` in `backend/host`. Use
  `HostAsyncImageLoader` for host-side loading-record scans, in-flight
  de-duplication, cancellation cleanup, and late-completion gating before
  concrete platform loaders call into that completion source. Use
  `HostNativeAsyncImageSource` when a platform loader needs to capture pending
  native `(window, source)` requests and deliver ready/failed completions later
  from an independent callback.
  Native WGPU providers may use renderer-owned helpers such as
  `native_image_load_completion` to convert PNG/JPEG/BMP data URI and local-file
  decode results into completion payloads, but matching-host off-main runtime
  observation is still required before claiming full native async image readiness.
  Native Skia providers may use `skia_image_load_completion` for provider-owned
  completion payloads from Skia encoded-image source decode, and provider-created
  Skia renderers opt into post-present async image loading so a matching smoke
  can prove second-frame repaint after completion. This remains provider/smoke
  observation until a matching host records true off-main late repaint behavior.
  Native macOS, Windows, and Linux host cores should invoke optional
  provider-owned image loaders only after the image-resource presented revision
  has been baselined, and cancel in-flight window loads during disposal.
  Keep decoding/cache mutation in renderer/provider packages, route redraw via
  `HostImageResourceRepaintTracker`, discard closed-window or stale-revision
  completions, and require matching-host runtime artifacts before claiming full
  native async image readiness.
- Run the affected backend package tests.
- Update `docs/platform-notes.md` when constraints or setup change.

### Update Examples

- Keep shared behavior under `examples/<name>/app`.
- Keep platform packages as entrypoints.
- Add app-package tests for model or runtime behavior.
- Build the affected Web wasm-gc entrypoint when browser output changes.
- Update `docs/examples.md` when commands, paths, or coverage change.

### Update Documentation

- Keep the root `README.md` short; its source is `moui/README.mbt.md`.
- Put architecture in `docs/architecture.md`.
- Put setup and command loops in `docs/development.md`.
- Put platform caveats in `docs/platform-notes.md`.
- Put example scope in `docs/examples.md`.
- Put text architecture in `docs/text-system.md`.
- Put Markdown Editor behavior in `docs/markdown-editor.md`.
- Put validation policy in `docs/testing.md`.
- Put renderer status in `docs/renderer-capability-report.md`.
- Put preview-release gates and gap-closure slices in
  `docs/release-readiness.md`.
- Check `AGENTS.md` and repo-local skills for stale guidance.

## Common Mistakes

- Adding platform logic to `core/`.
- Returning anything other than `@core.View[Msg]` from public view constructors.
- Skipping `moon info` after public API changes.
- Updating renderer support without updating capability docs and tests.
- Treating Linux Skia Preview Ready as complete platform support while
  matching-host runtime observation and native font provider work remain.
- Moving shared example logic into platform entrypoints.
- Running broad native checks before focused package validation.
- Letting `AGENTS.md` or repo-local skills drift after package, docs, example,
  validation, renderer, platform, or text-system changes.
