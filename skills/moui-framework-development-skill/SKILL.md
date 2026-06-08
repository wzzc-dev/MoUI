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
  View[Msg] -> internal view tree -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
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
  element ids for pending rebuild/layout/paint/redraw work; subscription
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
- Renderers consume platform-neutral `@core.DrawCommand` values.
- `examples/*/app` packages own shared app logic.
- Platform example packages should stay thin entrypoints.
- Web is `wasm-gc + window/web + browser WebGPU host imports`; there is no
  JS-target fallback.
- Linux has a Wayland backend with Skia as the native preview mainline,
  host-service wiring for system theme, Wayland clipboard selection, desktop
  URL/file-dialog/text-file services, text-input/IME request sync, file
  drag/drop conversion, and scale-factor reporting. Keep native menu, AT-SPI,
  matching-host runtime evidence, and native WGPU/fontconfig text-provider gaps
  explicit.
- Public API changes require `moon info` and review of `pkg.generated.mbti`
  diffs.
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

- `core/`: one MoonBit package for platform-neutral runtime, view specs, state,
  app-owned route/history helpers, `Program` / `Effect` / `Subscription`,
  layout, input, semantics, rich text editing, draw commands, styles, and theme
  tokens. Keep files grouped by responsibility
  (`runtime_state`,
  `component_context`, `input_*`, `paint_*`, `rich_text_*`) without adding
  subpackages.
- `style/`: visual token and style compatibility aliases.
- `views/`: public view constructors returning opaque `@core.View[Msg]`.
- `backend/host/`: shared `HostEvent`, surface metrics, input contracts,
  window lifecycle registry, window scene resolver, per-window runtime slot
  collection, platform-window id map, renderer-neutral `HostWindowRenderer`
  diagnostics and image-resource change callback bridge, image-resource repaint
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
  async host-service queue, and redraw driver.
- `backend/web/`: wasm-gc Web host, canvas constraints, resolver-backed
  multi-canvas window slots, browser runtime bridge, async browser
  file-open/save text completion for shared text-file reads/writes, and
  accessibility adapter.
- `backend/macos/`: AppKit/window host, resolver-backed multi-window slots,
  and CAMetalLayer WGPU surface creation.
- `backend/windows/`: Win32/window host, resolver-backed multi-window slots,
  and HWND WGPU surface creation.
- `backend/linux/`: Wayland host over `.local_repos/window/linux`, Linux
  host-service bridge, text-input/IME request sync, drag/drop conversion, a
  native Skia mainline presenter path plus native WGPU diagnostic surface path,
  shared host event conversion, and explicit native menu/AT-SPI follow-up
  reporting.
- `render/`: renderer facade, shared draw helpers, and capability report API.
- `render/skia/`: native Skia raster mainline renderer over the local
  `moui_skia` binding, including renderer-local command/reason diagnostics for
  unsupported Skia fallbacks, renderer-local image-resource lifecycle change
  callbacks, and `skia_image_load_completion` source decode completion payloads
  plus opt-in post-present async image loading for native providers. The
  binding/renderer may expose an explicit macOS Metal/Ganesh GPU context and
  offscreen GPU surface preflight, but provider/window GPU presentation remains
  separate matching-host evidence and must not replace the raster mainline
  without real smoke proof. Host-layer completion routing and native
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
- `moui/tests/skia_text_emoji_smoke/native`: opt-in real-Skia text/emoji proof
  smoke that records renderer-proof markers only after captured Skia pixels and
  font/glyph metadata plus text-system evidence prove color emoji, ZWJ
  grapheme, paragraph wrapping, and bidi observations. Native paragraph
  wrapping, bidi layout, and selection-rectangle proof must use the real
  SkParagraph path and include `engine=skparagraph` markers.
- `moui/tests/text_conformance/{native,web}`: opt-in diagnostic text matrix
  packages for comparing supported text systems and documented gaps.
- `examples/*/app`: shared application logic.
- `examples/*/{web_wasm,<platform>_<renderer>}`: platform/renderer profile
  entrypoints where an example has a runnable host package.
- `examples/showcase/{macos_skia,windows_skia,linux_skia}` and
  `examples/markdown_editor/{macos_skia,windows_skia,linux_skia}`: recommended
  native Skia renderer example entrypoints.
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

The daily check runs `sh scripts/check-local-deps.sh`, which verifies the local
`window` fork, repo-local `moui_skia` workspace, and the `window` fork's MoUI-oriented smoke
and evidence files are present, including `scripts/record_moui_evidence.sh`.
It also checks that the fork's current MoUI smoke contract still uses the
`moon run examples/moui_macos_smoke --target native` macOS path, the
module-qualified `wzzc-dev/window/examples/...` Web wasm-gc artifact paths, and
the MoUI Web smoke consumer sentinel lines.
Run `sh scripts/setup-local-deps.sh` first when the window checkout is missing or stale;
it fast-forwards the clean local window dependency checkout and refuses to overwrite
local `.local_repos/` edits.
Treat those window smoke helpers as dependency-level matching-host evidence,
not as a replacement for MoUI Showcase/Markdown Editor platform entrypoint
validation.
The same local-dependency check also requires the `moui_skia` binding workspace's
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`,
and verifier scripts, then runs
`moui_skia/scripts/verify-platform-status.sh` and
`moui_skia/scripts/verify-native-capability-contract.sh`. Treat
that as binding-level Skia provider/status and native capability evidence; MoUI
renderer pixels and platform runtime behavior still need the opt-in real-Skia
smoke or matching-host example runs.
The runnable `moui_skia` GitHub Actions workflows live in the repository root
as `.github/workflows/moui-skia-*.yml`, and Copilot setup lives at root
`.github/workflows/copilot-setup-steps.yml`. Keep workflow files there while
`moui_skia` is a workspace member; nested workflow files are not discovered by
GitHub Actions in the monorepo.
For Web runtime evidence, use `record-web-runtime-presentation.mjs` to collect
the browser-session artifact, then fold it into
`platform-runtime-evidence.json` with
`record-platform-evidence-manifest.mjs ... web --web-presentation-manifest ...`.
When Web folding runs in GitHub Actions, expect `github-actions` provenance
from the successful non-skipped job/run. When it runs locally, expect
`matching-host-artifact` provenance for the browser-session manifest and
screenshots. Do not invent CI run URL, runner, or job fields for local
artifacts.
The canonical Actions job for Web browser-session evidence is
`web-runtime-presentation`; it runs `scripts/ci-web-runtime-presentation.sh` to
build Showcase and Markdown Editor Web wasm-gc targets, serve the repository,
start Chrome CDP, record and fold the presentation manifest, validate the Web
platform entry, and upload `moui-web-runtime-presentation` artifacts.
Renderer proof is tracked separately in schema v1 manifests under
`artifacts/conformance/renderer-proof/<backend>-<platform>.json`. Validate them
with `scripts/validate-renderer-proof-manifest.mjs`; passed entries require
GitHub Actions provenance plus exactly `radialGradient`, `transformPixels`,
`colorEmojiPixels`, `zwjGrapheme`, `bidiLayout`, `paragraphWrapping`,
`selectionRects`, `graphemeEditing`, `imeCandidateAnchor`,
`imeCompositionVisual`, and `asyncImageSecondFrame` observations with strong
marker tokens. Passed
`colorEmojiPixels` observations must also include `font-metadata` /
`glyph-metadata` evidence and structured metadata fields, including a non-empty
glyph key plus positive glyph width/height; native Skia color emoji proof must
also include `fallback-request`, `emoji-hint`, and `stable-glyph-key` tokens. Native Skia `paragraphWrapping`,
`bidiLayout`, and `selectionRects` observations must include SkParagraph
markers such as `native_paragraph_ready=true`, `bidi_visual_order_ready=true`,
`line-metrics`, `later-line-pixels`, `visual-order`, `selection-rects`, and
`line-range` as appropriate. Package-only tests, skipped jobs,
missing uploaded artifacts, blank screenshots, caret-only
diagnostics, heuristic visual-order logs, fallback paragraph geometry,
coverage-only font matching, provider preflights,
preflight-only checks, and fallback-safe descriptor audits must stay failed
proof. Complete local observations may be
preserved for debugging, but without GitHub Actions provenance the manifest
status stays failed. The native Skia proof matrix
configures the locked release Skia artifact with required SkParagraph support
before running real renderer/text smokes. Native WGPU proof remains a
non-blocking diagnostic and still requires a
usable runner WGPU adapter for offscreen readback. The `renderer-proof-summary`
job requires the native Skia macOS, Windows, Linux, and WebGPU wasm proof
artifacts to validate as passed before mainline capability promotion; native
WGPU diagnostic artifacts are uploaded separately but do not block the summary.
The platform evidence manifest is schema v2 and records the window fork's
monitor/cursor probe as `monitorCursor`; native passed entries must set it to
`yes`, while Web browser-session evidence may leave it pending. Native passed
entries must also set `imeCandidateAnchor`, `imeSurroundingText`,
`imeCompositionVisual`, `imeCommitDelete`, `imeCursorUpdate`,
`imeScrollAnchor`, `imeScaleDprAnchor`, `imeResizeAnchor`, and
`imeMarkdownEditor` to `yes` from matching-host Showcase or Markdown Editor
runtime artifacts; host-core unit tests, package logs, provider preflights, and
coarse `textInput` observations are not enough. Native entries
also record a `skiaEvidence` block for Skia provider/preflight commands,
fallback-unavailable checks, real-renderer smoke, async image second-frame
smoke, and Showcase/Markdown first-frame status. Any `status=passed` platform
entry, and any
`skiaEvidence.status=passed` route, must include `evidenceProvenance` that
traces the claim to a non-skipped successful GitHub Actions job/run or to a
matching-host artifact bundle. Build-only jobs, package-only jobs,
provider/preflight summaries, dependency smokes, and skipped workflow-dispatch
paths are not runtime proof. `artifacts/platform-evidence/*/README.md` files
are placeholder documentation and must not be used as passed platform, Skia, or
provenance artifacts. `skiaEvidence.status=passed` is Skia-route
evidence, not a complete platform-services claim by itself, but native platform
entries cannot be marked `passed` unless their Skia evidence is also `passed`.
Use `record-native-ime-evidence.mjs` for matching-host IME logs when you only
want to validate and update native IME observations; it deliberately leaves the
broader platform runtime status unchanged and rejects generic host unit-test or
package logs without matching-host runtime, native-app, platform-protocol,
candidate-anchor, surrounding-text, composition, commit/delete, cursor, scroll,
scale/DPR, resize, and Markdown Editor markers.
Use
`record-native-skia-evidence.mjs` for matching-host Skia logs when you only
want to validate and update `skiaEvidence`; it deliberately leaves the broader
platform runtime status unchanged. Its provider-preflight log check requires
both the matching Skia provider identity and a passing preflight, test, or build
marker; do not use generic passing test output as provider evidence.
A passed presentation manifest must include WebGPU startup, wasm startup,
canvas sizing, resize/input event-bridge delivery, Markdown Editor text input,
clean target close, clean console, nonblank screenshots, and Showcase
transform-scene pixel markers for the named browser session before the Web
platform entry can be marked passed.

Focused checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test moui/render --target native
moon test moui/render/skia --target native
moon check moui/tests/skia_text_emoji_smoke/native --target native
moon test moui/render/webgpu_adapter --target wasm-gc
node scripts/test-webgpu-runtime-radial.mjs
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
node scripts/validate-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json
node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...
node scripts/record-native-ime-evidence.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...
node scripts/record-native-skia-evidence.mjs artifacts/conformance/platform-runtime-evidence.json <platform> ...
node scripts/validate-skia-entrypoints.mjs
node scripts/test-validate-skia-entrypoints.mjs
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/markdown_editor/macos_skia --target native
moon build examples/markdown_editor/windows_skia --target native
moon build examples/markdown_editor/linux_skia --target native
node --check scripts/validate-conformance-capture-manifest.mjs
node scripts/test-validate-conformance-capture-manifest.mjs
node --check scripts/validate-platform-evidence-manifest.mjs
node scripts/test-validate-platform-evidence-manifest.mjs
node --check scripts/record-platform-evidence-manifest.mjs
node scripts/test-record-platform-evidence-manifest.mjs
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
node --check scripts/validate-renderer-proof-manifest.mjs
node scripts/test-validate-renderer-proof-manifest.mjs
node --check scripts/record-renderer-proof-manifest.mjs
node scripts/test-record-renderer-proof-manifest.mjs
node --check scripts/record-web-renderer-proof-manifest.mjs
node scripts/test-record-web-renderer-proof-manifest.mjs
node --check scripts/generate-grapheme-break-fixtures.mjs
node scripts/generate-grapheme-break-fixtures.mjs --check
node --check scripts/ci-renderer-proof-native.mjs
sh -n scripts/ci-renderer-proof-native.sh
sh -n scripts/ci-renderer-proof-summary.sh
node --check scripts/validate-package-manifest.mjs
```

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
summaries as preflight evidence only; the macOS first-frame smoke and matching
Windows/Linux Showcase or Markdown Editor runtime runs are still required before
claiming Skia presentation. Windows/Linux Skia entrypoints use
`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1`,
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1`, or
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for matching-host
auto-exit first-frame logs.

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
  --smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log \
  --showcase-log artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log \
  --markdown-log artifacts/platform-evidence/macos/markdown-macos-skia-first-frame.log \
  --record-platform-evidence artifacts/conformance/platform-runtime-evidence.json
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
the renderer pixel smoke, optionally launches `examples/showcase/macos_skia` to
verify its first presented frame, optionally launches
`examples/markdown_editor/macos_skia` with `--run-markdown-smoke`, optionally
runs the explicit macOS Metal/Ganesh route smoke with `--run-gpu-smoke`, and
restores touched `moon.pkg` files. The GPU route smoke enables
`MOUI_SKIA_ENABLE_GPU_METAL`, requires the
`MoUI Skia GPU Metal renderer smoke passed` marker, sets
`MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu` for Showcase/Markdown first-frame
runs, and requires their logs to include
`surface_route=metal-gpu; surface_gpu=true` provider diagnostics. That proves
offscreen GPU surface rendering/readback through the existing pixel presenter
plus app first-frame presentation; it is still separate from direct
platform-window GPU presentation evidence. Direct Skia
`moon run`/`moon build` commands use the
`moui_skia` prebuild hook for real Skia and choose the library mode through
`MOUI_SKIA_LINK_MODE=dynamic|static|auto`; helper smoke runs can pass
`--link-mode dynamic|static|auto` to override the environment for that
invocation. For paragraph/bidi proof runs, pass `--enable-skparagraph` and
`--require-skparagraph` so missing SkParagraph, SkShaper, SkUnicode, HarfBuzz,
or ICU headers/libraries fail before proof markers are recorded. With explicit artifact log paths,
`--record-platform-evidence` updates only the macOS `skiaEvidence` block after a
successful full smoke; the renderer smoke log must include the async image
second-frame marker, and omitted provider/fallback observations remain pending
until their own artifacts are supplied. It does not mark the broader
platform-service entry passed. Normal macOS Skia entrypoints default to the system
`FontMgr` text path; first-frame smoke entrypoints explicitly select
`EmptyTypeface` only while their exit-after-first-present flag is set. Windows
and Linux Skia entrypoints follow the same smoke-only font-resolution switch.

Public API review:

```sh
moon info
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
  evidence is still required before claiming full native async image readiness.
  Native Skia providers may use `skia_image_load_completion` for provider-owned
  completion payloads from Skia encoded-image source decode, and provider-created
  Skia renderers opt into post-present async image loading so a matching smoke
  can prove second-frame repaint after completion. This remains provider/smoke
  evidence until a matching host records true off-main late repaint behavior.
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
- Treating Linux Skia Preview Ready as complete platform support while native
  menu, AT-SPI, matching-host runtime evidence, and native font provider work
  remain.
- Moving shared example logic into platform entrypoints.
- Running broad native checks before focused package validation.
- Letting `AGENTS.md` or repo-local skills drift after package, docs, example,
  validation, renderer, platform, or text-system changes.
