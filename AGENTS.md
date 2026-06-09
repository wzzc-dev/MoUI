# Project Agents.md Guide

This repository is a MoonBit multi-platform GUI framework prototype. Keep
changes small, package-local, and consistent with the public `View[Msg]` /
internal runtime tree split.

The project is still in an early prototype stage. Backward compatibility is not
a requirement unless a task explicitly asks for it. Prefer clear, simple
architecture and direct API cleanup over compatibility shims, duplicate legacy
paths, or abstractions that only preserve old shapes.

## Project Shape

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
  messages resume FIFO on the next host callback, and runtime dirty
  diagnostics may expose structured
  rebuild/layout/paint/redraw summaries, but concrete timer, host, window,
  route, or service adapters remain outside `core`.
  It remains one MoonBit package; internal files are grouped by responsibility
  (`runtime_state`, `component_context`, `input_*`, `paint_*`, `rich_text_*`,
  etc.) rather than by additional package boundaries.
- `views/` is a facade over core primitive builders. Public constructors return
  opaque `@core.View[Msg]`; `ViewSpec` and node payloads stay inside `core`.
- `backend/host/` defines shared host event, surface, input, async
  host-service including clipboard, file-dialog, text-file, URL, menu, and
  system-theme service contracts, host-event fanout subscription adapters, window-scoped subscription adapters,
  platform event-source bundles for feeding normalized Web/native host and window
  events into app-owned subscriptions,
  scheduler-backed timer subscription adapters, route/deep-link subscription adapters,
  app-owned service completion subscription adapters, window lifecycle, window scene resolution, per-window runtime slot collection,
  platform-window id mapping,
  request/completion, window event conversion, and renderer-neutral
  `HostWindowRenderer` diagnostics and image-resource change callback bridge,
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
  `render/skia`, `wgpu_mbt`, or `moui_skia`. `backend/web/` is the browser
  wasm-gc host, including the browser history route bridge that feeds
  `HostRouteSource`, browser async file-open/save text completion for shared
  text-file reads/writes, and shared app route history that stays app-owned.
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
  Markdown Editor has `macos_skia`, `windows_skia`, and `linux_skia` for
  native Skia renderer entrypoints. Showcase also has `macos_wgpu_cosmic`,
  `windows_wgpu_cosmic`, and `linux_wgpu_cosmic` entrypoints for explicit Moon Cosmic
  text-provider comparison on the native WGPU diagnostic route.
- `website/` is the MoUI-built homepage workspace. Keep shared homepage logic
  in `website/app/` and keep `website/web_wasm/` as a thin Web wasm-gc
  entrypoint; it is not an example-platform matrix.

## Local Dependencies

The project expects the modified local `wzzc-dev/window` checkout at
`.local_repos/window` and the repo-local editable `wzzc-dev/moui_skia`
workspace member at `moui_skia`, as described in `docs/development.md`. Local
`moon.mod`, `moon.work`, and `moon.pkg` files are the source of truth for
imports, workspace members, and supported targets.

Use `sh scripts/setup-local-deps.sh` to create or repair the local window checkout and
`sh scripts/check-local-deps.sh` to verify that `window` points at the
`wzzc-dev/window` fork on the `moui-support` branch and `moui_skia` is present as
the repo-local `wzzc-dev/moui_skia` workspace member. The upstream window remote is
`https://github.com/moonbit-community/window.git`; the MoUI window fork remote
is `git@github.com:wzzc-dev/window.git`.
`scripts/setup-local-deps.sh` also fast-forwards the existing clean window
checkout to its expected origin branch; it stops before overwriting local
changes in `.local_repos/`.
The local-dependency check also verifies the window fork's MoUI-oriented smoke
and evidence files such as `docs/moui-integration-smoke.md`,
`scripts/check_moui_*_smoke.sh`, and `scripts/record_moui_evidence.sh` are
present and still wired to the expected smoke contract: macOS through
`moon run examples/moui_macos_smoke --target native`, Web wasm-gc artifacts
under module-qualified `wzzc-dev/window/examples/...` paths, and MoUI Web smoke
consumer sentinel lines. Treat those as dependency-level matching-host evidence
entrypoints; they do not replace MoUI Showcase or Markdown Editor platform
validation.
It also verifies the Skia binding acceptance surface, including
`skia-platform-status.json`, `skia-provider-lock.json`,
`SKIA_PLATFORM_STATUS.md`, `native/capabilities.json`, `native/ownership.json`,
`moui_skia/scripts/verify-platform-status.sh`, and
`moui_skia/scripts/verify-native-capability-contract.sh`. That
status and native capability contract prove the editable binding workspace has a
pinned platform-status contract, CI evidence wiring, fallback parity, FFI
ownership/borrow checks, and native smoke marker coverage; they do not replace
MoUI real-Skia smoke or platform runtime evidence.
The runnable GitHub Actions workflows for this binding live at the repository
root under `.github/workflows/moui-skia-*.yml`, with
`.github/workflows/copilot-setup-steps.yml` preparing GitHub Copilot coding
agent runs against the `moui_skia` workspace. Do not add workflow files under
`moui_skia`; GitHub will not discover them while the binding is part of this
main repository.

When asked to update the repository, treat it as a multi-checkout update:
update the main MoUI checkout, initialize/update any Git submodules such as
`.agents/skills/moonbit-skills`, and update every editable checkout under
`.local_repos/`. `moui_skia` now updates with the main checkout rather than as a
nested repository. Do not assume updating the root repository also updates
remaining nested repositories. On Windows, use
`powershell -ExecutionPolicy Bypass -File .\scripts\windows\update_repositories.ps1`
from the repository root for this routine; it also creates or updates
`.local_repos/window` on `moui-support`.

`.local_repos/window` is an editable local dependency, not a vendored snapshot
or submodule. It exists because upstream `moonbit-community/window` currently
only covers macOS, while MoUI needs Web, Windows, and Linux support. Changes in
that checkout should stay limited to the `web/`, `windows/`, and `linux/`
platform packages and their package-local tests/docs when possible. Avoid
changing `macos/`, shared packages such as `core/` and `dpi/`, or common
behavior unless the task explicitly requires it; keeping the fork narrow makes
future upstreaming safer. The local checkout must declare
`name = wzzc-dev/window` in `moon.mod` or `moon.mod.json` so workspace imports
bind to the editable fork.

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
dependency evidence for the Skia binding, provider artifact lock, and FFI
surface coverage, not as MoUI Showcase/Markdown Editor runtime evidence.

When asked to merge upstream `window` changes, work inside `.local_repos/window`
on `moui-support`, fetch `upstream`, and merge the upstream branch into the fork
branch. Preserve upstream macOS and shared behavior where possible; resolve
conflicts by keeping MoUI-specific additions scoped to Web, Windows, and Linux
unless the user explicitly approves broader fork changes.

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

Useful focused checks:

```sh
moon check
moon check --warn-list +unnecessary_annotation
moon test moui/core --target native
moon test moui/views --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
moon test moui/render/skia --target native
moon check moui/tests/skia_text_emoji_smoke/native --target native
moon test moui_skia --target native
moon test moui/render/wgpu/cosmic_text --target native
node scripts/test-webgpu-runtime-radial.mjs
node scripts/validate-renderer-provider-manifests.mjs
sh scripts/conformance-check.sh --input
sh scripts/conformance-check.sh --layout
sh scripts/conformance-check.sh --render
sh scripts/conformance-check.sh --platform-services
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon build examples/showcase/web_wasm --target wasm-gc
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
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_break_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_break_fixture --test-name "unicode 17 grapheme break fixture samples" --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_editing_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_editing_fixture --test-name "unicode 17 grapheme editing fixture samples" --actual-kind core-editing --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_layout_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_layout_fixture --test-name "unicode 17 grapheme layout fixture samples" --actual-kind core-layout --check
node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/render/skia/skia_grapheme_break_unicode_17_wbtest.mbt --helper-name assert_skia_unicode_17_grapheme_break_fixture --test-name "skia unicode 17 grapheme break fixture samples" --actual-kind skia-clusters --check
node --check scripts/generate-grapheme-property-data.mjs
node scripts/generate-grapheme-property-data.mjs --grapheme-property <Unicode-17.0.0-GraphemeBreakProperty.txt> --emoji-data <Unicode-17.0.0-emoji-data.txt> --derived-core-properties <Unicode-17.0.0-DerivedCoreProperties.txt> --check
node --check scripts/ci-renderer-proof-native.mjs
sh -n scripts/ci-renderer-proof-native.sh
sh -n scripts/ci-renderer-proof-summary.sh
node --check scripts/validate-package-manifest.mjs
```

Conformance work should stay layered: `core` owns platform-neutral contracts,
`backend/host` owns event/service/window routing, renderer/provider packages own
implementation validation, and `moui/tests/*_conformance` plus
`scripts/conformance-check.sh` own cross-engine or cross-platform matrix
evidence. Platform runtime claims should use the validated
`artifacts/conformance/platform-runtime-evidence.json` contract generated by
`scripts/conformance-check.sh --platform-services` and updated through
`scripts/record-platform-evidence-manifest.mjs`; pending entries are not runtime
proof until a matching host records passed observations and artifacts. Passed
entries must also include `evidenceProvenance` that traces the claim to a
non-skipped successful GitHub Actions job/run or to a matching-host artifact
bundle; a host label, skipped CI job, build-only/package-only job, provider
preflight, or dependency smoke is not enough for `status=passed` runtime
evidence. `artifacts/platform-evidence/*/README.md` files are placeholder
documentation and must not be used as passed platform, Skia, or provenance
artifacts. The
manifest is schema v2 and mirrors the local window recorder's monitor/cursor
field as `monitorCursor`; native passed evidence must set it to `yes`, while
Web browser evidence may leave it pending because CDP does not prove native
monitor/current-monitor or cursor behavior. Native passed evidence must also
set `imeCandidateAnchor`, `imeSurroundingText`, `imeCompositionVisual`,
`imeCommitDelete`, `imeCursorUpdate`, `imeScrollAnchor`,
`imeScaleDprAnchor`, `imeResizeAnchor`, and `imeMarkdownEditor` to `yes` from
matching-host Showcase or Markdown Editor runtime artifacts; host-core unit
tests, package logs, provider preflights, and coarse `textInput` observations
are not enough. Native platform entries also carry
`skiaEvidence`, which separately records Skia provider/preflight commands,
fallback-unavailable checks, real-renderer smoke, async image second-frame
smoke, and Showcase/Markdown first-frame status. A native platform entry cannot
be marked `passed` unless
that native Skia evidence is also `passed`; a passed `skiaEvidence` block is
still Skia-route evidence, not full platform service/runtime proof by itself.
Native Skia provider preflight summaries also audit the renderer-neutral
`HostWindowRenderer` bridge used to forward Skia text-system, image-resource,
image-resource change callback, present-count, and disposal diagnostics. Treat those bridge fields as
provider/package evidence, not as proof that a matching platform window
presented a frame.
The Web runtime handoff validator
checks static HTML/runtime/wasm delivery for Showcase and Markdown Editor, not
browser WebGPU presentation. Use
`scripts/record-web-runtime-presentation.mjs` and
`scripts/validate-web-runtime-presentation-manifest.mjs` to collect passed
browser-session WebGPU, wasm startup, canvas, resize/input event-bridge,
Markdown Editor text input, clean target close, console, nonblank screenshots,
and Showcase transform-scene pixel marker evidence; fold that artifact into
`artifacts/conformance/platform-runtime-evidence.json` with
`scripts/record-platform-evidence-manifest.mjs ... web
--web-presentation-manifest ...`. Failed or missing presentation manifests must
stay out of passed Web runtime claims. Passed Web entries must retain the
validated browser-session manifest plus `evidenceProvenance`: GitHub Actions
folds record `github-actions` provenance with run URL/run id/workflow/job/runner
and uploaded artifact paths, while local folds record `matching-host-artifact`
provenance with the host label and artifact bundle.
The repository CI job `web-runtime-presentation` is the canonical GitHub
Actions path for Web browser-session evidence: it builds Showcase and Markdown
Editor Web wasm-gc targets, starts local HTTP plus Chrome CDP, records and
folds the presentation manifest, validates the Web platform evidence entry, and
uploads the `moui-web-runtime-presentation` artifact bundle.
Renderer proof uses a separate schema v1 manifest under
`artifacts/conformance/renderer-proof/<backend>-<platform>.json`, validated by
`scripts/validate-renderer-proof-manifest.mjs`. A passed renderer-proof entry
must have GitHub Actions provenance and exactly `radialGradient`,
`transformPixels`, `colorEmojiPixels`, `zwjGrapheme`, `bidiLayout`,
`paragraphWrapping`, `selectionRects`, `graphemeEditing`,
`imeCandidateAnchor`, `imeCompositionVisual`, and `asyncImageSecondFrame`
observations with strong marker tokens; passed `colorEmojiPixels` observations
must also include
`font-metadata` / `glyph-metadata` evidence and structured metadata fields
including a non-empty glyph key plus positive glyph width/height, so emoji
pixels remain tied to the font/glyph path that produced them; native Skia color
emoji proof must also include `fallback-request`, `emoji-hint`, and
`stable-glyph-key` tokens plus fallback script/language-count metadata,
fallback request character metadata, resolved missing-glyph count,
missing-glyph recovery readiness, and a glyph key that contains the recorded
source/text-system/shaper/script/language-count/fallback-request-character/format
metadata. Skipped
jobs, package-only tests, missing uploaded artifacts, blank
screenshots, caret-only diagnostics, coverage-only font matching,
package-only checks, provider preflights, preflight-only checks, and
fallback-safe descriptor audits must remain failed proof. The
recorder may preserve complete local observations for debugging, but without
GitHub Actions provenance the manifest status must stay failed. The
native Skia proof matrix configures the locked release Skia artifact with
required SkParagraph support before running its real renderer/text smokes.
Native Skia `graphemeEditing`, `imeCandidateAnchor`, and
`imeCompositionVisual` renderer-proof markers come from the text/emoji smoke's
shared grapheme-boundary contract, host IME request diagnostics including UTF-8
cursor/anchor offsets plus composition cursor evidence, Skia caret geometry,
and captured text-field composition pixels; they do not replace matching-host
native IME runtime evidence.
Native WGPU proof remains a non-blocking
diagnostic and still requires a usable runner WGPU adapter for offscreen
readback. The `renderer-proof-summary` CI job requires the native Skia macOS,
Windows, Linux, and WebGPU wasm manifests to validate as passed before any
mainline capability promotion can cite them; native WGPU diagnostic artifacts
are uploaded separately but do not block the summary.
Examples demonstrate workflows but should not be the only proof for a
shared contract.
If CDP is unavailable during Web presentation startup, the recorder writes a
validated failed manifest before exiting nonzero; use that artifact to document
the environment limit without broadening it into passed Web runtime evidence.

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
For renderer-proof text/emoji work, `moui/tests/skia_text_emoji_smoke/native`
is the opt-in real-Skia proof entrypoint; it writes proof markers only when
captured Skia pixels, font/glyph metadata, and text-system evidence prove color
emoji, ZWJ grapheme, paragraph wrapping, and bidi observations, and otherwise keeps the corresponding
renderer-proof observations failed. Native Skia paragraph and bidi readiness
requires the SkParagraph path: `paragraphWrapping` markers must include
`engine=skparagraph native_paragraph_ready=true line-metrics
later-line-pixels`, `bidiLayout` markers must include `engine=skparagraph
bidi_visual_order_ready=true visual-order`, and `selectionRects` markers must
include `engine=skparagraph selection-rects line-range hit-test`. Fallback geometry,
caret-only diagnostics, heuristic visual-order logs, package-only tests, and
provider preflights are not passed proof for those observations.
On macOS, `scripts/macos-skia-renderer-smoke.sh` can resolve Skia from an
existing build, the pinned JetBrains binary provider, or a source build; it then
temporarily wires the resolved link flags into the local `moui_skia` and MoUI
packages, runs the renderer pixel smoke, builds `examples/showcase/macos_skia`,
and restores the package files. Pass `--run-showcase-smoke` to also launch the
Showcase entrypoint, verify that the macOS Skia renderer presents its first
frame, and exit automatically. Pass `--run-markdown-smoke` to add the same
first-frame check for `examples/markdown_editor/macos_skia`. Pass
`--run-gpu-smoke` to add the explicit macOS Metal/Ganesh GPU route smoke; that
temporary build enables `MOUI_SKIA_ENABLE_GPU_METAL`, requires the renderer
smoke log to include the `MoUI Skia GPU Metal renderer smoke passed` marker,
sets `MOUI_MACOS_SKIA_SURFACE_ROUTE=metal-gpu` for the Showcase/Markdown
first-frame runs, and requires those first-frame logs to include
`surface_route=metal-gpu; surface_gpu=true` provider diagnostics. This proves
GPU surface rendering/readback through the existing pixel presenter plus app
first-frame presentation, but not direct platform-window GPU presentation. Pass
`--enable-skparagraph` to wire optional SkParagraph into the temporary real-Skia
configuration, and pass `--require-skparagraph` for paragraph/bidi proof runs
that must fail when the selected Skia headers or libraries do not provide
SkParagraph, SkShaper, SkUnicode, HarfBuzz, and ICU. With explicit
`--smoke-log`, `--showcase-log`, and `--markdown-log` paths under
`artifacts/platform-evidence/macos/`, pass `--record-platform-evidence
artifacts/conformance/platform-runtime-evidence.json` to update the macOS
`skiaEvidence` block after a successful full smoke; the renderer smoke log must
also include the async image second-frame marker, and omitted provider/fallback
observations remain pending until their own artifacts are supplied. That still
records Skia route evidence only. Direct Skia `moon run`/`moon build` commands
resolve real Skia through the `moui_skia` prebuild hook and choose the library
mode through `MOUI_SKIA_LINK_MODE=dynamic|static|auto`; helper smoke runs can
still use `--link-mode dynamic|static|auto` to override the environment for that
invocation. Pass `--write-local-config` only when intentionally persisting local
absolute Skia paths, and keep those machine-local `moon.pkg` edits out of
commits. Normal macOS Skia
entrypoints default to the system `FontMgr` text path; first-frame smoke
entrypoints explicitly select `EmptyTypeface` only while their
exit-after-first-present flag is set.
The GitHub Actions wrapper for this MoUI-level macOS real-Skia smoke lives in
`.github/workflows/moui-real-skia-smoke.yml` as a separate manual workflow, not
as a skipped job in the required `MoUI CI` workflow.
Windows/Linux Skia entrypoints expose matching-host first-frame flags
(`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT`,
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT`,
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT`, and
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT`) and follow the same
smoke-only `EmptyTypeface` switch; passed artifacts still belong to the
matching host that produced them. After a matching host writes provider,
fallback-unavailable, renderer-smoke, Showcase first-frame, and Markdown Editor
first-frame logs under `artifacts/platform-evidence/<platform>/`, use
`node scripts/record-native-skia-evidence.mjs` to validate those markers and
update only the platform's `skiaEvidence` block. Provider preflight logs must
name the matching Skia provider package or preflight summary and include a
passing preflight/test/build marker; generic passing test output is not enough.
Showcase first-frame logs must include the platform first-frame marker with
`title=MoUI Showcase`, and Markdown Editor first-frame logs must include the
same marker with `title=MoUI Markdown Editor`; app-swapped first-frame logs are
not valid for the opposite observation.
After a matching host writes native IME Showcase or Markdown Editor logs under
the same artifact root, use `node scripts/record-native-ime-evidence.mjs` to
validate candidate-anchor, surrounding-text, composition-visual, commit/delete,
cursor-update, scroll-anchor, scale/DPR-anchor, resize-anchor, and Markdown
Editor dogfood markers and update only the native IME observations. Supplied
logs must also identify matching-host runtime, native app, `renderer=skia`, the
matching app marker (`app=showcase` or `app=markdown-editor`), and platform protocol
markers such as `platform-protocol=macos-marked-text`,
`platform-protocol=windows-ime`, or `platform-protocol=wayland-text-input`.
The `renderer=skia`, app, and platform-protocol markers are exact
whitespace-delimited tokens; suffixed labels such as `renderer=skia-preview` or
`app=showcase-debug` are not runtime IME evidence. The
helper does not promote full platform status, and generic host unit-test or
package logs are not runtime IME proof.
Full platform runtime status still requires the broader platform observations.

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
contract/conformance tests as behavior evidence. Do not add long-lived
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
- `docs/release-readiness.md` tracks preview-release gates, current evidence,
  known gaps, and next implementation slices.

## Editing Notes

- Preserve the `///|` delimiter style in MoonBit files.
- Keep public API additions intentional and covered by tests.
- Put new tests in focused `*_test.mbt` files inside the package being changed.
- Do not remove generated `pkg.generated.mbti` files.
- Do not run platform entrypoint tests through the generic wasm-gc runner when
  they require browser host imports.
