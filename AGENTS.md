# Project Agents.md Guide

This repository is a MoonBit multi-platform GUI framework prototype. Keep
changes small, package-local, and consistent with the public `View[Msg]` /
internal runtime tree split.

The project is still in an early prototype stage. Backward compatibility is not
a requirement unless a task explicitly asks for it. Prefer clear, simple
architecture and direct API cleanup over compatibility shims, duplicate legacy
paths, or abstractions that only preserve old shapes.

## Project Shape

- `core/` owns the platform-neutral contract model, state, layout, input,
  semantics, draw command model, opaque public `View[Msg]`, typed events,
  app-owned route/history helpers, `Program`, `Effect`, `Subscription`, and
  the transitional runtime kernel while implementation moves to
  `moui/runtime`. Standard `Effect`/`Subscription` helpers may name common
  descriptor kinds, subscription reuse is keyed by the stable key plus source
  kind, effect-task lifecycle diagnostics may distinguish same-key descriptor
  kind changes from ordinary same-kind task replacement, program diagnostics
  may count late dispatches ignored after runtime destruction, program message
  drains are bounded runtime turns so synchronous click/effect/task/subscription
  self-queues cannot monopolize the current host callback and remaining
  messages resume FIFO on the next host callback, runtime dirty
  diagnostics may expose structured
  rebuild/layout/paint/redraw summaries plus damage/cache summaries, and
  retained redraw may expose `DrawFrame`, `DamageRegion`, repaint-boundary
  cache keys, cached-layer draw commands, and platform-view placements such as
  WebView rectangles, but concrete timer, host, window, route, platform
  WebView, or service adapters remain outside `core`.
  It remains one MoonBit package; internal files are grouped by responsibility
  (`runtime_state`, `component_context`, `input_*`, `paint_*`, `rich_text_*`,
  etc.) rather than by additional package boundaries.
- `runtime/` is the app/host runtime entrypoint package. It exposes an opaque
  `@runtime.AppRuntime` wrapper over the current core runtime kernel. New app,
  backend, smoke, and tooling code should type and construct runtimes through
  `@runtime.AppRuntime`, `@runtime.new_view`, or `@runtime.new_program`
  instead of direct `@core.AppRuntime`; this keeps the call surface ready for
  moving runtime logic out of `core` without exposing core private trees.
- `views/` is a facade over core primitive builders. Public constructors return
  opaque `@core.View[Msg]`; app, host, smoke, and cross-package tests should
  use `views` widget-level entrypoints instead of direct `@core.View::*`
  control constructors. `ViewSpec` and node payloads stay inside `core`.
- `moui_theme/common/` owns the repo-local addon design-system common surface:
  shared source-mapped design-system
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
  `@core.Theme` values. `moui_theme` may depend on `wzzc-dev/moui/core`, but
  `moui/core`, `moui/views`, and the root `wzzc-dev/moui` workspace member must
  not depend on `moui_theme`. `moui_theme/material`, `moui_theme/carbon`,
  `moui_theme/primer`, and `moui_theme/fluent` expose package-local
  `light_theme`/`dark_theme`/`high_contrast_theme`/`system_theme`,
  token, manifest, report, and component-matrix entrypoints over the shared
  common model; keep concrete design-language names such as
  Material, Carbon, Primer, and Fluent out of `core` and `views`; views should
  keep consuming plain `@core.Theme` or neutral style contracts. Do not promote
  an external preset from source-mapped preview to official-complete status
  without tests tying
  token, variant, component, customization, official-token golden mapping
  coverage, source usage coverage, stable source version locks,
  source-package import coverage, source-imported token source-lock coverage,
  source-imported token official-anchor coverage, source-imported token
  manifest/golden integrity, runtime token alignment, token taxonomy parity,
  semantic palette role parity, typography role parity,
  component-token matrix coverage, and
  adaptation-difference closure to official source anchors.
- `backend/host/` defines shared host event, surface, input, async
  host-service including clipboard, file-dialog, text-file, binary-file, URL, menu, and
  system-theme service contracts, host-event fanout subscription adapters, window-scoped subscription adapters,
  platform event-source bundles for feeding normalized Web/native host and window
  events into app-owned subscriptions,
  scheduler-backed timer subscription adapters, route/deep-link subscription adapters,
  app-owned service completion subscription adapters, window lifecycle, window scene resolution, per-window runtime slot collection,
  platform-window id mapping,
  native WebView capability/command/event contracts,
  request/completion, window event conversion, renderer-neutral frame redraw
  scheduling with idle/scheduled/in-frame/follow-up states, and renderer-neutral
  `HostWindowRenderer` diagnostics, render-frame cached-layer fallback command replay,
  and image-resource change callback bridge,
  image-resource load completion apply bridge,
  image-resource repaint routing contracts,
  native async image loading-record scheduler,
  native provider async-image scheduling hooks,
  native async image completion source and deferred native completion request source,
  tracked-window image-resource repaint diagnostics with revision and lifecycle
  status counts, and repaint-result previous/current lifecycle status counts.
- `backend/macos/`, `backend/windows/`, and `backend/linux/` are native host
  cores: platform windows, event conversion, services, lifecycle, runtime slots,
  and renderer-neutral provider hooks. Linux owns host service wiring for
  system theme, Wayland clipboard selection, desktop URL/file-dialog/text-file
  services, desktop native menu selection, text-input/IME request sync, file
  drag/drop conversion, AT-SPI accessibility binding, and scale-factor
  reporting. They must not import `render/wgpu`,
  `render/skia`, `wgpu_mbt`, or `moui_skia`. Native WebView support is a host
  platform-view overlay synced from `DrawFrame.platform_views`; it must not
  become a renderer capability or `DrawCommand`. `backend/web/` is the browser
  wasm-gc host, including the browser history route bridge that feeds
  `HostRouteSource`, browser async file-open/save text completion for shared
  text-file reads/writes, and shared app route history that stays app-owned;
  it reports WebView unavailable instead of using an iframe overlay.
- `backend/macos/skia`, `backend/windows/skia`, and `backend/linux/skia`
  provide the native Skia raster mainline renderer providers, including
  provider-owned `HostAsyncImageLoader` hooks around
  `skia_image_load_completion`; provider-created Skia renderers opt into
  post-present async image loading, but keep this as provider/smoke log
  until matching-host off-main runtime artifacts prove real late repaint
  behavior. `backend/macos/wgpu`, `backend/windows/wgpu`, and
  `backend/linux/wgpu` provide native WGPU experimental diagnostic providers,
  including provider-owned `HostAsyncImageLoader` hooks that call
  renderer-owned source decode helpers such as `native_image_load_completion`;
  keep off-main loader/runtime observation separate from package-level completion
  wiring and do not make these diagnostics release-blocking by default.
- `render/` is the renderer facade and shared reporting layer.
- `render/skia/` is the native Skia raster mainline renderer facade over the
  local `wzzc-dev/moui_skia` binding, including
  renderer-local image-resource lifecycle change callbacks and
  `skia_image_load_completion` source decode completion payloads plus opt-in
  post-present async image loading for native providers. The binding and
  renderer diagnostics may expose an explicit opt-in macOS Metal/Ganesh GPU
  context plus offscreen GPU surface boundary, but platform-window GPU
  presentation remains separate observation and must not replace the Skia raster
  mainline until matching-host smoke proves it; host-layer completion routing
  and native provider/platform redraw scheduling from async image load/error
  notifications remain outside `render/skia`.
  `render/webgpu_adapter/` is the wasm-gc browser WebGPU host-import bridge.
  `render/wgpu/` is the experimental native wgpu renderer.
- Native text providers live in `render/wgpu/cosmic_text/`,
  `render/wgpu/coretext/`, `render/wgpu/directwrite/`,
  `render/wgpu/fontconfig/`, and the shared `render/wgpu/text_protocol/`
  package. `core/` owns only the neutral `TextSystem` contract.
- `examples/*/app/` packages are shared app logic. Platform subpackages are
  entrypoints only. Showcase has `macos_skia`, `windows_skia`, and
  `linux_skia` entrypoints for the recommended native Skia renderer mainline.
  Showcase is the MoUI framework capability catalog and must not import
  `moui_theme`. `examples/design_systems/app` is the dedicated addon diagnostic
  design-system preview/parity example and may import both `wzzc-dev/moui` and
  `wzzc-dev/moui_theme`; `examples/design_systems` has `macos_skia`,
  `windows_skia`, `linux_skia`, and `web_wasm` entrypoints.
  Markdown Editor has `macos_skia`, `windows_skia`, and `linux_skia` for
  native Skia renderer entrypoints. PDF Workbench has a lightweight shared
  `examples/pdf_workbench/app` package, a separate
  `examples/pdf_workbench/pdflite_adapter` package for real PDF engine checks,
  `examples/pdf_workbench/pdflite_service_protocol` and
  `examples/pdf_workbench/pdflite_service_native_transport` packages for
  helper-process document service isolation,
  a native-only `examples/pdf_workbench/pdfium_adapter` package for PDFium page
  rasterization, and `macos_skia`, `windows_skia`, and `linux_skia`
  entrypoints. Showcase also has `macos_wgpu_cosmic`,
  `windows_wgpu_cosmic`, and `linux_wgpu_cosmic` entrypoints for explicit Moon Cosmic
  text-provider comparison on the native WGPU diagnostic route.
  WebView Demo has a shared `examples/webview_demo/app` package plus
  `macos_skia`, `windows_skia`, `linux_skia`, and Web fallback entrypoints for
  the native WebView host contract.
- `website/` is the MoUI-built homepage and runtime docs workspace. Keep
  shared homepage/docs logic in `website/app/` and keep `website/web_wasm/` as
  a thin Web wasm-gc entrypoint; it is not an example-platform matrix. The
  Docs page reads Markdown from same-origin static `docs/*.md` files at
  runtime rather than compiling those files into wasm.

## Local Dependencies

The project now resolves `wzzc-dev/window` from the MoonBit registry as
`wzzc-dev/window@0.5.1-0.1.4`; `moon.work` must not include an editable
`.local_repos/window` member. The repo-local editable dependency is
`wzzc-dev/moui_skia` at `moui_skia`, as described in `docs/development.md`.
Local `moon.mod`, `moon.work`, and `moon.pkg` files remain the source of truth
for imports, workspace members, and supported targets.

Use `moon update` to refresh registry dependencies and
`sh scripts/check-local-deps.sh` to verify that `moui/moon.mod` and
`moui_skia/moon.mod` both import `wzzc-dev/window@0.5.1-0.1.4`, `moon.work`
does not reintroduce `.local_repos/window`, and `moui_skia` is present as the
repo-local `wzzc-dev/moui_skia` workspace member. The MoonBit ecosystem and
package registry are still maturing; if a build or smoke starts failing without
a local code change, treat dependency resolution, registry cache state, and
package-version regressions as plausible causes before assuming the MoUI code is
wrong.

The window package still carries MoUI-oriented smoke and observation files such as
`docs/moui-integration-smoke.md`, `scripts/check_moui_*_smoke.sh`, and
`scripts/record_moui_evidence.sh`. Use
`scripts/run-window-package-smoke.sh <platform>` to run those helpers from the
resolved registry package without creating a local checkout. Treat those as
dependency-level matching-host observation entrypoints; they do not replace MoUI
Showcase platform validation.
The dependency check also verifies the Skia binding acceptance surface, including
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`,
`moui_skia/scripts/verify-platform-status.sh`, and
`moui_skia/scripts/verify-native-capability-contract.sh`. That
status and native capability contract prove the editable binding workspace has a
pinned platform-status contract, CI smoke wiring, fallback parity, FFI
ownership/borrow checks, and native smoke marker coverage; they do not replace
MoUI real-Skia smoke or platform runtime observation.
The runnable GitHub Actions workflows for this binding live at the repository
root under `.github/workflows/moui-skia-*.yml`, with
`.github/workflows/copilot-setup-steps.yml` preparing GitHub Copilot coding
agent runs against the `moui_skia` workspace. Do not add workflow files under
`moui_skia`; GitHub will not discover them while the binding is part of this
main repository.

When asked to update the repository, treat it as a multi-checkout update:
update the main MoUI checkout, initialize/update any Git submodules such as
`.agents/skills/moonbit-skills`, run `moon update` for registry packages, and
remember that `moui_skia` updates with the main checkout rather than as a
nested repository. On Windows, use
`powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1`
from the repository root when you need the Windows helper for root/submodule
updates; it no longer needs to create a local window checkout for normal MoUI
builds.

`moui_skia` is also an editable local dependency, now stored as a repo-local
workspace member rather than a submodule or nested Git checkout.
It carries native Skia binding work needed by `render/skia`, including
fallback-safe APIs that compile when real Skia link flags are absent. Keep
missing Skia FFI surface area in `moui_skia` instead of adding large private Skia
stubs inside MoUI. Renderer-local fallbacks should expose structured
diagnostics such as command/reason payloads instead of only aggregate counts.
A fallback compile is not renderer readiness:
`skia_available() == false` must keep Skia renderer creation unavailable.
The checkout owns its binding-level platform acceptance status in
`skia-platform-status.json` and `SKIA_PLATFORM_STATUS.md`, plus its native
capability contract in `native/capabilities.json` and `native/ownership.json`,
validated by `scripts/verify-platform-status.sh`/`.ps1` and
`scripts/verify-native-capability-contract.sh`/`.ps1`. Treat those files as
dependency observation for the Skia binding, provider artifact lock, and FFI
surface coverage, not as MoUI Showcase runtime observation.

When asked to change the `window` dependency itself, work in the separate
`wzzc-dev/window` repository, publish a new fork package version, then update
MoUI's `moon.mod` imports and package-smoke expectations. Do not reintroduce a
repo-local window workspace member for routine MoUI development.

## MoonBit Package Rules

MoonBit package boundaries are directories with `moon.pkg` files. File names do
not create modules or namespaces, and declarations in the same package can
refer to each other regardless of file. Imports use module/package paths such
as `wzzc-dev/moui/core`, never source file names.

Before adding new APIs or refactoring existing ones, discover local symbols with
the MoonBit IDE tools where practical:

```sh
moon ide doc <query>
moon ide outline <file>
moon ide peek-def <file>:<line>:<col>
moon ide find-references <file>:<line>:<col>
```

## Development Checks

Use the daily validation script for routine work:

```sh
sh scripts/dev-check.sh
```

This intentionally avoids all-repository `moon test --target native`,
`moon test --target wasm-gc`, and native platform example builds by default.
Those commands can pull in incompatible platform stubs, browser-only wasm-gc
host imports, or slow native links. Prefer package-level tests and Web wasm-gc
example builds for daily work. Use
`sh scripts/dev-check.sh --platform-examples-test` when you need
current-platform backend tests too. Use
`sh scripts/dev-check.sh --platform-examples-build` only when you explicitly
need slow current-platform native example builds.
Use `sh scripts/dev-check.sh --theme-diagnostics` when changing `moui_theme`
or the Design Systems addon diagnostic example; Design Systems is addon diagnostic coverage, not part of the default daily baseline.
The daily check also runs the MoonBit-backed maintenance baseline ratchets,
API surface guard, guidance consistency, renderer/provider and native Skia
entrypoint static checks, and app/Web validation for Showcase and Markdown
Editor. The maintenance baseline locks current oversized file, source-level
`pub(all)`, and root facade forwarding budgets; when a refactor splits files or
shrinks public surface area, lower the relevant budget in the same change. It
does not validate checked-in conformance artifacts, because `artifacts/` is now
ignored by default. Do not commit artifacts/ JSON as capability claims; use
manual smoke logs, CI runs, or uploaded artifacts when a release note needs
runtime context.

Useful focused checks:

```sh
moon check
moon check --warn-list +unnecessary_annotation
moon test moui/core --target native
moon test moui/runtime --target native
moon test moui/views --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test moui/render/skia --target native
moon run moui/tests/skia_cached_layer_benchmark/native --target native
moon run benchmarks/app_cached_layer/native --target native
moon check moui/tests/skia_text_emoji_smoke/native --target native
moon test moui_skia --target native
moon test moui/render/wgpu/cosmic_text --target native
node scripts/test-webgpu-runtime-radial.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-renderer-provider-manifests.mjs
node scripts/validate-api-surface.mjs
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/design_systems/web_wasm --target wasm-gc
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

Conformance work should stay layered: `core` owns platform-neutral contracts,
`backend/host` owns event/service/window routing, renderer/provider packages own
implementation validation, and `moui/tests/*_conformance` plus
`scripts/conformance-check.sh` own cross-engine or cross-platform package
checks. Platform/runtime behavior is now handled as manual smoke: run the
matching host, keep the generated logs under ignored `artifacts/`, and cite the
CI run or smoke log directly in release notes. The Web runtime handoff
validator checks static HTML/runtime/wasm delivery; `scripts/ci-web-runtime-presentation.sh`
is an optional browser-session smoke that records and validates a local
presentation manifest under `artifacts/smoke/web-runtime-presentation/`.
Native Skia provider preflight summaries audit wiring only; real presentation
still requires a renderer smoke or matching-host first-frame run.

Run `moon info` after public API changes and review generated
`pkg.generated.mbti` diffs.

For narrow validation, prefer package or file scoped tests:

```sh
moon test <dir-or-file> --target native
moon test <dir-or-file> --filter '<glob>'
```

If a change touches `render/wgpu/`, also run:

```sh
moon test moui/render/wgpu --target native
```

If a change touches `render/skia/` or `moui_skia`, also run the
fallback-safe Skia checks. Use `sh scripts/dev-check.sh --skia-real-smoke` only
after configuring real native Skia link flags; that opt-in path also runs
`moui/tests/skia_renderer_smoke/native` to verify MoUI `DrawCommand` rendering
against captured Skia presenter pixels.
For real-Skia text and emoji work, `moui/tests/skia_text_emoji_smoke/native`
is the opt-in smoke entrypoint. It reports pass/fail markers for captured Skia
pixels, font/glyph metadata, color emoji, ZWJ grapheme, paragraph wrapping,
bidi layout, selection rectangles, grapheme editing, IME geometry, and async
image second-frame behavior. Native Skia paragraph and bidi readiness still
requires the SkParagraph path and should be cited as a smoke log from the host
that ran it, not as a checked-in manifest.
On macOS, `scripts/macos-skia-renderer-smoke.sh` can resolve Skia from an
existing build, the pinned JetBrains binary provider, or a source build; it then
temporarily wires the resolved link flags into the local `moui_skia` and MoUI
packages, runs the renderer pixel smoke, builds `examples/showcase/macos_skia`,
and restores the package files. Pass `--run-showcase-smoke` to also build and
run the `moui_tester` first-frame smoke after the Showcase build. Pass
`--run-markdown-smoke` to build Markdown Editor and run the same tester-owned
first-frame check. Pass
`--run-gpu-smoke` to add the explicit macOS Metal/Ganesh GPU route smoke; that
temporary build enables `MOUI_SKIA_ENABLE_GPU_METAL`, requires the renderer
smoke log to include the `MoUI Skia GPU Metal renderer smoke passed` marker,
sets `MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu` for the tester-owned
first-frame run and optional tester IME run, and
requires those first-frame logs to include
`surface_route=metal-gpu; surface_gpu=true` provider diagnostics. This records
GPU surface rendering/readback through the existing pixel presenter plus a
tester first-frame presentation, but not direct platform-window GPU
presentation. Pass
`--enable-skparagraph` to wire optional SkParagraph into the temporary real-Skia
configuration, and pass `--require-skparagraph` for paragraph/bidi smoke runs
that must fail when the selected Skia headers or libraries do not provide
SkParagraph, SkShaper, SkUnicode, HarfBuzz, and ICU. Direct Skia
`moon run`/`moon build` commands resolve real Skia through the `moui_skia`
prebuild hook and choose the library mode through
`MOUI_SKIA_LINK_MODE=dynamic|static|auto`; helper smoke runs can still use
`--link-mode dynamic|static|auto` to override the environment for that
invocation. Pass `--write-local-config` only when intentionally persisting
local absolute Skia paths, and keep those machine-local `moon.pkg` edits out of
commits. Normal macOS Skia entrypoints default to the system `FontMgr` text
path; tester-owned first-frame smoke entrypoints explicitly select
`EmptyTypeface`.
The GitHub Actions wrapper for this MoUI-level macOS real-Skia smoke lives in
`.github/workflows/moui-real-skia-smoke.yml` as a separate manual workflow, not
as a skipped job in the required `MoUI CI` workflow.
Windows/Linux Skia entrypoints expose matching-host first-frame flags
(`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT`,
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT`,
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT`, and
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT`) and follow the same
smoke-only `EmptyTypeface` switch; logs belong to the matching host that
produced them. For Linux, keep Showcase, Markdown Editor, and
`scripts/run-window-package-smoke.sh linux --run` logs separate so app-level and
dependency-level evidence are not conflated. When recording platform behavior
for a release note, keep logs under ignored `artifacts/` paths and cite the CI
run or smoke log directly.

Windows native uses Visual Studio C++ build tools and vcpkg `zlib:x64-windows`.
Use `scripts/windows/setup_msvc_deps.ps1`,
`scripts/windows/build_windows_msvc.ps1`, and
`scripts/windows/package_windows_app_msvc.ps1` for setup, build, and packaging.
Those helpers are renderer-aware: native Skia packages are the mainline and do
not download or package `wgpu_native.dll`; explicit native WGPU diagnostic
packages keep the `wgpu_mbt` dynamic mode with the official MSVC
`wgpu_native.dll`. When changing Windows native setup, keep docs, CI, and
repo-local skills aligned with this renderer-aware route.

## Renderer Capability Tracking

Renderer feature status is tracked per backend in `render/capabilities.mbt` and
summarized in `docs/renderer-capability-report.md`. Update both the structured
report and tests when changing image, clip, opacity, transform, or other draw
command support. `RendererDescriptor` and `RendererSelection` are reporting and
matching concepts, not native host runtime assembly. Native runtime assembly
belongs to `backend/<platform>/wgpu` or `backend/<platform>/skia` renderer
provider packages; `core`, `ViewSpec`, `Program`, and host cores must not depend
on concrete renderer choices.

Use `pkg.generated.mbti` as the public API contract baseline and focused
contract/conformance tests as behavior observation. Do not add long-lived
`*_spec.mbt` files for ordinary implementation structure; prefer responsibility
names such as `*_tree.mbt`, `*_descriptor.mbt`, `*_input.mbt`, `*_protocol.mbt`,
or `*_capabilities.mbt` when organizing package-local source.

## Documentation Updates

When development changes affect package layout, build commands, validation
commands, platform setup, renderer capabilities, or user-facing behavior, update
the relevant files under `docs/` in the same change. Keep the root `README.md`
as a short entry point; its source is `moui/README.mbt.md`. Move detailed
development guidance into `docs/development.md`.

The project moves quickly, so guidance files are part of the maintenance
surface. When changes affect architecture, package boundaries, docs placement,
validation commands, platform behavior, examples, renderer capabilities, or the
text system, also check whether `AGENTS.md` and the repo-local skills under
`skills/` need updates. If they do not need edits, say they were checked and
left unchanged in the handoff.

Current focused docs:

- `docs/text-system.md` covers `TextSystem`, native provider composition,
  Web text measurement/drawing, embedded fonts, and shaping gaps.
- `docs/markdown-editor.md` covers the WYSIWYG Markdown Editor model,
  source/visual mapping, commands, platform entrypoints, and validation.
- `docs/release-readiness.md` tracks preview-release gates, current observation,
  known gaps, and next implementation slices.

## Editing Notes

- Preserve the `///|` delimiter style in MoonBit files.
- Keep public API additions intentional and covered by tests.
- Put new tests in focused `*_test.mbt` files inside the package being changed.
- Do not remove generated `pkg.generated.mbti` files.
- Do not run platform entrypoint tests through the generic wasm-gc runner when
  they require browser host imports.
