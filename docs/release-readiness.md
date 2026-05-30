# Release Readiness

This page turns the 2026 roadmap into an auditable preview-release checklist.
It does not replace `docs/roadmap-2026.md`; it records the current evidence,
known gaps, and next implementation slices needed before MoUI can be presented
as a preview baseline for real MoonBit app development.

## Preview Baseline Definition

MoUI is preview-ready when the repository can demonstrate all of these claims
with current files and validation output:

- The platform-neutral runtime pipeline remains explicit:
  `View[Msg] -> internal view tree -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer`.
- Public view constructors return opaque `@core.View[Msg]`; app code uses typed
  messages and shared logic through Web wasm-gc, macOS native, and Windows
  native entrypoints where those platforms are supported.
- Renderer capability status is synchronized between
  `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
  `docs/renderer-capability-report.md`.
- High-risk behavior uses the same four-layer conformance model: `core`
  contract tests, host routing tests, implementation/provider tests, and
  matrix/diagnostic conformance entrypoints.
- Showcase and Markdown Editor serve as runnable documentation rather than
  hidden smoke tests.
- Showcase remains the preferred visible validation surface for framework
  features: new user-facing views, renderer capabilities, host-service flows, or
  example-worthy platform behaviors should add Showcase coverage unless they are
  impossible or misleading to demonstrate there.
- Platform backends stay adapters around `backend/host`; unsupported platform
  paths are marked as scaffolds instead of implied as complete.
- Development validation is bounded, repeatable, and documented.
- `AGENTS.md` and repo-local skills remain aligned with package boundaries,
  validation commands, examples, renderer capability rules, and text-system
  architecture.

## Current Evidence

| Area | Evidence | Status |
| --- | --- | --- |
| Daily validation | `sh scripts/dev-check.sh` passes after the Windows Showcase unused import cleanup. | ready |
| Package boundaries | `docs/architecture.md`, `AGENTS.md`, and repo-local skills describe the same `core` / `views` / `backend` / `render` / `examples` split. | ready |
| Public view model | `views/` constructors are documented as returning opaque `@core.View[Msg]`; public API edits require `moon info`. | ready |
| Example shape | Showcase and Markdown Editor keep shared app logic under `examples/*/app/` with platform entrypoints as wiring. | ready |
| Renderer capability tracking | Capability status is recorded in code, tests, and `docs/renderer-capability-report.md`. | ready with tracked gaps |
| Platform contracts | `backend/host` owns shared events, services, windows, redraw, and request/completion contracts. | ready with tracked Linux service gaps |
| Text system | `docs/text-system.md` documents `TextSystem`, provider composition, embedded fonts, and shaping gaps; stable and diagnostic text conformance checks pass. | ready with tracked gaps |
| Devtool counters | Core inspector snapshots expose runtime, layout, semantics, frame, and render command counters; render snapshots also report open clip/layer/filter scopes and unbalanced pops. | ready for command-level diagnostics |
| Guidance surface | `docs/ai-collaboration.md`, `AGENTS.md`, and `skills/` define focused agent workflows. | ready |

## Required Gates

Before calling a preview-release handoff complete, collect fresh evidence for:

| Gate | Required Evidence | Command Or Artifact |
| --- | --- | --- |
| Daily baseline | Bounded package checks and Web wasm-gc example builds pass. | `sh scripts/dev-check.sh` |
| Public API audit | Generated interfaces reviewed after public API changes. | `moon info` plus `pkg.generated.mbti` diff review |
| Renderer sync | Capability code, tests, docs, and visible Showcase coverage agree. | `moon test moui/render --target native`, `moon test moui/render/wgpu --target native`, `moon test moui/render/webgpu_adapter --target wasm-gc`, Showcase Web build |
| Focused conformance | Input/focus, layout, render, platform service, and text slices pass at their owning layer. | `sh scripts/conformance-check.sh --input`, `--layout`, `--render`, `--platform-services`, `--text`, `--text-diagnostic` |
| Text conformance | Stable text contracts and diagnostic gaps are current. | `sh scripts/conformance-check.sh --text`, `sh scripts/conformance-check.sh --text-diagnostic` |
| Platform contracts | Shared host and active backend behavior stay covered. | `moon test moui/backend/host --target native`, `moon test moui/backend/web --target wasm-gc`, `sh scripts/dev-check.sh --platform-examples-test` when platform behavior changes |
| Examples | Showcase and Markdown Editor remain runnable docs; new user-facing features have visible Showcase coverage or a recorded reason to skip it. | App package tests plus Web wasm-gc builds |
| Guidance freshness | Docs, `AGENTS.md`, and repo-local skills agree after guidance-affecting changes. | `node scripts/validate-guidance-consistency.mjs` plus manual audit notes in the handoff |

## Current Evidence Snapshot

This snapshot records the current preview-readiness evidence gathered on
2026-05-26. Refresh it before a release candidate handoff.

| Gate | Current evidence | Status |
| --- | --- | --- |
| Daily baseline | `sh scripts/dev-check.sh` passed on 2026-05-26 after conformance layering and example evidence updates. | current |
| Public API audit | The async image diagnostics slice added `ImageResourceLifecycle::snapshot` and `WgpuRenderer::image_resources`; the Web ready/failed diagnostics refresh also ran `moon info` and produced no generated interface diff. | current |
| Renderer sync | `render/capabilities.mbt`, `render/capabilities_test.mbt`, and `docs/renderer-capability-report.md` remain the source of truth. `sh scripts/conformance-check.sh --render` passed after follow-up evidence was tightened for transform, text shaping, emoji text, and async image. | current with tracked renderer gaps |
| Focused conformance | `sh scripts/conformance-check.sh --input`, `--layout`, `--platform-services`, `--text`, and `--text-diagnostic` passed. Platform-services skipped Linux only because the local window checkout lacks generated Wayland protocol sources. | current with host/setup-scoped Linux service evidence |
| Text conformance | Stable text conformance covers core, native renderer/provider validation, Web adapter, and Web backend. Diagnostic matrix tests cover core fallback, Cosmic, platform-default composed fallback/scaffolds, malformed-provider fallback, and Web text systems where available. | current with shaping/color-emoji gaps documented |
| Platform contracts | `backend/host` now covers post-close queued window command rejection and completion recording. `--platform-services` passed on the current host with host/Web/macOS service evidence and explicit Linux skip wording. | current for macOS host; Windows/Linux runtime evidence remains host-limited |
| Examples | `moon test examples/showcase/app --target native`, `moon test examples/markdown_editor/app --target native`, and both Web wasm-gc builds passed. Showcase capability cards now surface follow-up rows first; Markdown Editor app tests cover Unicode paste through runtime undo/redo. | current |
| Guidance freshness | `AGENTS.md`, framework skill, app skill, docs, README entrypoint wording, provider package paths, and example entrypoints are covered by `scripts/validate-guidance-consistency.mjs` after guidance-affecting updates. | current |

## Platform Validation Matrix

Preview handoffs must say which host produced platform evidence. Platform
claims should be scoped to the host that ran them; do not use a macOS check as
runtime evidence for Windows or Linux native behavior.

| Host | Routine command | What it proves | What remains out of scope |
| --- | --- | --- | --- |
| macOS / Darwin | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/macos` native backend tests on the current macOS host. | Windows native backend/runtime behavior, Windows packaging helper runtime behavior, Linux runtime backend behavior, and slow native example builds unless `--platform-examples-build` is also run. |
| Windows / MSYS/UCRT64 | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/windows` native backend tests on a Windows toolchain with Windows headers and runtime dependencies. | macOS AppKit behavior, Linux backend behavior, and slow Windows example builds unless `--platform-examples-build` is also run. |
| Linux | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/linux` native backend tests on a Linux host with Wayland headers. | Real Wayland compositor/runtime behavior unless the Showcase `moon run` commands are also run under Wayland with a usable Vulkan stack; clipboard, menu, dialog, drag/drop, IME, AT-SPI, and native font provider work remain tracked gaps. |

For release candidates on a configured host, add:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Record any skipped native example builds as host/setup limits rather than
silently broadening the evidence claim.

## Showcase Capability Alignment

Showcase is the visual catalog and the preferred place to verify new
user-facing framework features. When adding a public view, visible renderer
capability, host-service workflow, or platform behavior that users can
reasonably inspect, add a Showcase demo plus app-level assertions in
`examples/showcase/app` and keep the Web wasm-gc build passing. If a feature is
not useful or possible to demonstrate there, record the reason in the relevant
docs or handoff.

Showcase is still not automatically proof that every renderer feature has an
end-to-end visual demo. Treat the Showcase renderer section as two surfaces:

- The capability card lists `render.renderer_feature_capability_report()` so
  users can inspect the current status data. It shows follow-up rows before
  ready rows so visible docs keep partial and gap items in view.
- The visual cards and app tests provide stronger evidence only for the draw
  commands they actually emit.

Current alignment:

| Renderer feature | Showcase visibility | Current app-level evidence | Release-readiness note |
| --- | --- | --- | --- |
| Rect / rounded rect | Visual panels and layout tiles. | Showcase app tests inspect rounded-rect marker output. | Covered as ordinary surface/control drawing. |
| Gradient | Visual styling and sparkline/card brushes. | Showcase app tests assert `FillRoundedRectBrush` with `LinearGradient`. | Covered by visible demo plus command-level app test. |
| Shadow | Theme/renderer cards and panels. | Showcase app tests assert `DrawShadow`. | Covered by visible demo plus command-level app test. |
| Text | Most catalog sections. | Showcase app tests assert many section labels and renderer report text. | Covered broadly as view output, while shaping conformance remains tracked in text tests. |
| Image | Text/media and visual correctness cards. | Showcase app tests assert `DrawImage`; renderer/Web adapter tests cover image lifecycle snapshots. | Covered for visible image commands; async diagnostics are partial but Web snapshots now refresh ready/failed records from the browser image cache after host submission. |
| Clip | Scroll/capability card and clipped image demos. | Showcase app tests assert `PushClip` and clipped long renderer content; Web adapter tests preserve rounded clip host calls. | Covered for visible clipping; Web rounded clip submit uses the browser layer-mask path. |
| Transform | Capability card lists follow-up status first while WGPU/Web remain partial; visual correctness image uses scale/offset. | Native renderer tests cover scoped layer/filter transform/clip inheritance, transformed filter child vertices/scissors, shader-effect advanced-vertex transform state, and masked layer composite vertices; Skia real smoke covers translated, scaled-and-clipped, layer-masked opacity, and filter-scoped transform pixels; Web adapter tests preserve transform scope around layer, filter, and shader-effect commands, and the browser runtime now applies transform to shader-effect advanced vertices; Showcase app tests assert the follow-up row is visible. | Skia is ready; keep overall follow-up visible until WGPU/Web broader render-pass transform pixel evidence exists. |
| Opacity | Visual correctness image and state-driven visuals. | Showcase app tests assert `PushOpacity`. | Covered for view-level opacity emission; renderer-specific blending remains renderer evidence. |
| Layer compositing | Used indirectly by advanced renderer scopes where applicable. | Capability report card lists status; no dedicated Showcase assertion. | Keep primary evidence in renderer tests/report unless a visible layer demo is added. |
| Blend mode | Capability card lists status. | No dedicated Showcase visual assertion. | Renderer tests/report are primary evidence; add Showcase only if a visible comparison demo is useful. |
| Filter effect | Capability card lists status. | No dedicated Showcase visual assertion. | Renderer tests/report are primary evidence; add Showcase only if a visible comparison demo is useful. |
| Path/vector | Theme/renderer section includes a vector path card that emits filled and stroked `DrawPath` commands. | Renderer tests cover `PathSpec` tessellation, native draw-plan path items, Web host-call forwarding, and fallback planning that keeps visible `DrawPath` out of fallback diagnostics; Showcase app tests assert `DrawPath` emission. | Covered by visible Showcase demo plus renderer/Web adapter command-level evidence. |
| Shader effect | Capability card lists status. | No dedicated Showcase visual assertion. | Renderer tests/report are primary evidence; add Showcase only for user-inspectable built-ins. |
| Text shaping | Capability card lists follow-up status first; text/media section exercises text views. | Text conformance tests are primary evidence; Skia text now resolves `FontSpec` family, weight, and style through Skia `FontMgr`/`Font`, returns Skia font-metric baseline/height plus measured prefix caret positions for basic input geometry, and renders through optional SkShaper shaped glyph runs when linked or positioned glyph runs otherwise; the macOS Skia showcase first-frame path uses `EmptyTypeface` startup text resolution to avoid layout-time CoreText/Skia FontMgr and SkShaper crashes, with measurement and drawing retrying Skia's default font when the empty typeface would produce blank glyphs so text-field carets stay aligned, and default renderer smoke remains the Skia FontMgr/SkShaper evidence; provider validation rejects non-empty run-layout carets that do not cover the input, and Cosmic run-layout tests assert glyph output plus monotonic caret coverage through the provider-safe mapped layout path for representative emoji clusters. Showcase app tests assert the follow-up row is visible. | Do not use Showcase labels or basic Skia font matching/metrics/caret measurement as proof of bidi/line-breaking/typography parity. |
| Emoji text | Capability card lists follow-up status first. | Diagnostic text conformance covers single-codepoint, variation-selector, and ZWJ emoji measurement/caret invariants; renderer tests now cover native RGBA color glyph payload parsing/upload, text vertex shader marking, Cosmic platform emoji fallback loading/resolution, provider-safe Cosmic run-layout caret coverage, Cosmic color swash preservation, and CoreText AppleColorEmoji format selection. Showcase app tests assert the partial follow-up row is visible. | Keep native/Web `partial`: the evidence does not prove full native emoji font fallback across all providers, ZWJ/color emoji conformance, browser rasterization determinism, or full grapheme shaping parity. |
| Async image | Capability card lists follow-up status first; image demos render ordinary images. | Native/Web renderer tests expose image resource snapshots; backend Web tests cover app/host-visible `WebRenderer::image_resources`; Web records submitted sources as loading, refreshes ready/failed records from the browser image cache, and the canonical Web boot path schedules a redraw after browser image load/error notifications; Showcase app tests assert the follow-up row is visible. | Still partial while broader native/general repaint policy and fresh release evidence remain outstanding; Web no longer depends on a manual app action to observe browser image completion. |

If renderer support changes, update this alignment only when Showcase coverage
or its evidence level changes. Otherwise keep the authoritative support status
in `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
`docs/renderer-capability-report.md`.

## Work Queue

These slices are intentionally scoped so each can land with focused tests and
documentation evidence.

### Renderer

1. Layer-level transform state
   - Current status: affine transforms are folded into visual, image, text,
     shader-effect advanced vertices, and masked native layer composite
     vertices. Native scoped layer/filter child plans inherit transform and
     clip while outer opacity is applied at composite time, including
     transformed filter child vertices/scissors; Web scoped layer/filter
     commands clone current transform/clip state through the browser runtime,
     and Web adapter tests preserve transform scope around shader-effect
     commands. Skia real smoke now covers translated, scaled-and-clipped,
     layer-masked opacity, and filter-scoped transform output.
   - Done when: WGPU/Web broader render-pass transform visible/pixel evidence
     is in place, or their remaining limits are explicitly documented for the
     preview handoff.
   - Evidence: renderer tests, `render/capabilities.mbt`,
     `render/capabilities_test.mbt`, `docs/renderer-capability-report.md`, and
     Showcase if visible.

2. Async image diagnostics
   - Current status: renderer-neutral lifecycle records model loading, ready,
     failed, disposed, and eviction. Native/Web renderer facades expose image
     resource snapshots, and the backend WebRenderer facade forwards Web
     snapshots to app/host integration code. Web refreshes submitted sources
     from the browser image cache that is updated by `Image.onload` /
     `Image.onerror`. The canonical Web boot path now schedules a redraw when
     those browser image events report a resource change.
   - Done when: preview handoff has fresh focused renderer/Web adapter
     evidence and any remaining native/general repaint policy is recorded as
     out of scope for renderer-local diagnostics.
   - Evidence: focused renderer/Web adapter tests, docs, and capability report.

3. Emoji and text shaping evidence
   - Current status: Web can rely on browser font rasterization. Native WGPU can
     carry RGBA color glyph payloads through the provider protocol, atlas
     upload path, and text vertex shader marker. Cosmic now loads platform
     emoji fallback font candidates when available, while full native emoji
     font fallback across all providers, ZWJ/color emoji conformance, and full bidi/line
     breaking/typography conformance remain
     follow-up work. Diagnostic checks cover representative emoji measurement
     and caret invariants, including single-codepoint, variation-selector, and
     ZWJ samples; Cosmic tests also assert platform emoji fallback
     loading/resolution plus run-layout glyph output and caret coverage through
     the provider-safe mapped layout path, but they document invariants and known gaps rather than
     claiming full Unicode shaping parity.
   - Done when: deterministic coverage keeps improving without claiming full
     Unicode shaping parity before it exists.
   - Evidence: text conformance commands, renderer tests, and text-system docs.

### Text Providers

1. Windows DirectWrite provider
   - Current status: scaffold composed with Cosmic fallback.
   - Done when: the provider returns validated platform layout/raster data or
     the scaffold documentation continues to describe fallback behavior
     honestly.
   - Evidence: provider tests, platform notes, text-system docs, and renderer
     capability notes.

2. Linux fontconfig/HarfBuzz/FreeType provider
   - Current status: scaffold for a future Linux host path.
   - Done when: real provider data exists behind the documented protocol, or
     the scaffold remains explicitly unavailable.
   - Evidence: scaffold/provider tests and text-system docs.

### Platform

1. Linux backend
   - Current status: minimal Wayland host core plus WGPU provider path with
     tracked service, accessibility, IME, and native font-provider gaps.
   - Done when: Showcase `linux` and `linux_cosmic` run under a real Wayland
     compositor with a usable Vulkan stack, and readiness wording continues to
     describe the remaining unsupported platform services honestly.
   - Evidence: backend tests, platform notes, readiness report wording, and the
     two Linux Showcase `moon run` commands.

2. Platform validation handoff
   - Current status: daily checks skip slow native platform examples.
   - Done when: preview handoff records the host, current-platform checks that
     ran, and native example builds intentionally left out due to setup or host
     limits.
   - Evidence: `sh scripts/dev-check.sh --platform-examples-test`, the platform
     validation matrix above, and, when configured,
     `--platform-examples-build`.

### Examples And Docs

1. Showcase capability alignment
   - Current status: Showcase lists the renderer capability report and has
     visible/app-test evidence for a focused subset of draw commands.
   - Done when: each visible renderer capability status has either Showcase
     coverage or a documented reason it is not visible there, and new visible
     framework features default to adding Showcase coverage.
   - Evidence: Showcase capability alignment matrix, Showcase app tests, Web
     wasm-gc build, capability report.

2. Release handoff checklist
   - Current status: this document defines gates; each release candidate still
     needs fresh evidence.
   - Done when: `.idea/codex-goals/checklist.md` and
     `.idea/codex-goals/evidence.md` map every requirement to a current
     artifact and command result.
   - Evidence: task ledger plus final verification summary.

### Dev Tools

1. Render inspector diagnostics
   - Current status: `RenderInspectorSnapshot` can be built from an
     `AppRuntime` or an explicit draw-command stream and reports draw command
     counts, max clip/layer/filter depths, open scope depths, unbalanced pop
     count, path count, and shader count.
   - Done when: inspector data is surfaced through a developer UI or capture
     artifact and connected to golden/benchmark handoffs.
   - Evidence: `moon test moui/core --target native`, generated public API review
     after inspector changes, and testing docs.

## Known Non-Goals

- Do not make compatibility shims for removed APIs unless explicitly requested.
- Do not move platform or renderer implementation details into `core/`.
- Do not describe Linux platform support as complete while service, IME,
  AT-SPI, and native font-provider gaps remain; do not describe DirectWrite or
  fontconfig providers as complete while their packages are scaffolds.
- Do not make broad all-target tests the default inner loop.
- Do not treat a green narrow test as evidence for a broader release claim.

## Handoff Template

Use this shape for preview-readiness handoffs:

```text
Changed files:
- ...

Validation:
- command: result
- command: result

Readiness impact:
- Which checklist items moved forward.
- Which known gaps remain.

Guidance freshness:
- AGENTS.md: checked / updated
- skills/: checked / updated

Risks:
- ...
```
