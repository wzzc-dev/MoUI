# MoUI Agent Guide

Use this file as the first stop for AI/code agents working in this repository.
For task-specific workflows, use the repo-local skills:

- `skills/moui-app-development/SKILL.md` for shared app packages, examples, and
  platform entrypoints.
- `skills/moui-framework-development-skill/SKILL.md` for framework internals,
  public API, runtime/backend/renderer work, maintenance ratchets, and smoke
  gates.

## Read First

<<<<<<< Updated upstream
- `docs/architecture.md` for the current package map and runtime pipeline.
- `docs/moui-app-package-boundary.md` for app-safe package dependencies and
  owning-package rules.
- `docs/development.md` for setup, workspace members, docs sync, and focused
  development loops.
- `docs/testing.md` for the daily validation script, focused checks, and manual
  smoke commands.
- `docs/release-readiness.md` for release gates, smoke gate catalog policy, and
  artifact policy.
=======
- `core/` owns the platform-neutral runtime, state, layout, input, semantics,
  draw command model, opaque public `View[Msg]`, typed events, app-owned
  route/history helpers, `Program`, `Effect`, `Subscription`, and TEA runtime
  diagnostics. Standard `Effect`/`Subscription` helpers may name common
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
- `views/` is a facade over core primitive builders. Public constructors return
  opaque `@core.View[Msg]`; `ViewSpec` and node payloads stay inside `core`.
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
  services, text-input/IME request sync, file drag/drop conversion, and
  scale-factor reporting, while native menu and AT-SPI remain documented
  follow-ups. They must not import `render/wgpu`,
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
  post-present async image loading, but keep this as provider/smoke evidence
  until matching-host off-main runtime artifacts prove real late repaint
  behavior. `backend/macos/wgpu`, `backend/windows/wgpu`, and
  `backend/linux/wgpu` provide native WGPU experimental diagnostic providers,
  including provider-owned `HostAsyncImageLoader` hooks that call
  renderer-owned source decode helpers such as `native_image_load_completion`;
  keep off-main loader/runtime evidence separate from package-level completion
  wiring and do not make these diagnostics release-blocking by default.
- `render/` is the renderer facade and shared reporting layer.
- `render/skia/` is the native Skia raster mainline renderer facade over the
  local `wzzc-dev/moui_skia` binding, including
  renderer-local image-resource lifecycle change callbacks and
  `skia_image_load_completion` source decode completion payloads plus opt-in
  post-present async image loading for native providers. The binding and
  renderer diagnostics may expose an explicit opt-in macOS Metal/Ganesh GPU
  context plus offscreen GPU surface boundary, but platform-window GPU
  presentation remains separate evidence and must not replace the Skia raster
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
>>>>>>> Stashed changes

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

<<<<<<< Updated upstream
The daily validation script includes `moon check`, maintenance baseline guards,
API surface guards, smoke catalog validation, core/view/render/backend package
tests, `moui_tester`, `moui_devtools`, Showcase and Markdown Editor app tests,
and Web wasm-gc builds.
=======
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
or the Design Systems addon diagnostic example; Design Systems is addon
diagnostic coverage, not part of the default daily baseline.
The daily check also runs the MoonBit-backed API surface guard, checked
conformance artifact guard, dedicated checked-artifact validators for
capture/Web/platform/renderer-proof manifests, and app/Web validation for
Showcase and Markdown Editor.
>>>>>>> Stashed changes

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
