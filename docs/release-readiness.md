# Release Readiness

This page turns the 2026 roadmap into an auditable preview-release checklist.
It does not replace `docs/roadmap-2026.md`; it records the current evidence,
known gaps, and next implementation slices needed before MoUI can be presented
as a preview baseline for real MoonBit app development.

## Preview Baseline Definition

MoUI is preview-ready when the repository can demonstrate all of these claims
with current files and validation output:

- The platform-neutral runtime pipeline remains explicit:
  `ViewSpec -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer`.
- Public view constructors return `@core.ViewSpec` and app code can use shared
  logic through Web wasm-gc, macOS native, and Windows native entrypoints where
  those platforms are supported.
- Renderer capability status is synchronized between
  `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
  `docs/renderer-capability-report.md`.
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
| Public view model | `views/` constructors are documented as returning `@core.ViewSpec`; public API edits require `moon info`. | ready |
| Example shape | Showcase and Markdown Editor keep shared app logic under `examples/*/app/` with platform entrypoints as wiring. | ready |
| Renderer capability tracking | Capability status is recorded in code, tests, and `docs/renderer-capability-report.md`. | ready with tracked gaps |
| Platform contracts | `backend/host` owns shared events, services, windows, redraw, and request/completion contracts. | ready with Linux scaffold |
| Text system | `docs/text-system.md` documents `TextSystem`, provider composition, embedded fonts, and shaping gaps; stable and diagnostic text conformance checks pass. | ready with tracked gaps |
| Guidance surface | `docs/ai-collaboration.md`, `AGENTS.md`, and `skills/` define focused agent workflows. | ready |

## Required Gates

Before calling a preview-release handoff complete, collect fresh evidence for:

| Gate | Required Evidence | Command Or Artifact |
| --- | --- | --- |
| Daily baseline | Bounded package checks and Web wasm-gc example builds pass. | `sh scripts/dev-check.sh` |
| Public API audit | Generated interfaces reviewed after public API changes. | `moon info` plus `pkg.generated.mbti` diff review |
| Renderer sync | Capability code, tests, docs, and visible Showcase coverage agree. | `moon test render --target native`, `moon test render/wgpu --target native`, `moon test render/webgpu_adapter --target wasm-gc`, Showcase Web build |
| Text conformance | Stable text contracts and diagnostic gaps are current. | `sh scripts/conformance-check.sh --text`, `sh scripts/conformance-check.sh --text-diagnostic` |
| Platform contracts | Shared host and active backend behavior stay covered. | `moon test backend/host --target native`, `moon test backend/web --target wasm-gc`, `sh scripts/dev-check.sh --platform-examples-test` when platform behavior changes |
| Examples | Showcase and Markdown Editor remain runnable docs; new user-facing features have visible Showcase coverage or a recorded reason to skip it. | App package tests plus Web wasm-gc builds |
| Guidance freshness | Docs, `AGENTS.md`, and repo-local skills agree after guidance-affecting changes. | Manual audit recorded in the handoff |

## Current Evidence Snapshot

This snapshot records the current preview-readiness evidence gathered on
2026-05-25. Refresh it before a release candidate handoff.

| Gate | Current evidence | Status |
| --- | --- | --- |
| Daily baseline | `sh scripts/dev-check.sh` passed after the Windows Showcase unused import cleanup. | current |
| Public API audit | No public API change has been made in the latest release-readiness documentation slices. Earlier public API slices recorded `moon info` evidence in the task ledger. | not required for latest docs-only slices |
| Renderer sync | `render/capabilities.mbt`, `render/capabilities_test.mbt`, and `docs/renderer-capability-report.md` remain the source of truth. Path/vector is explicitly marked `gap`; Web rounded clip submit now maps to the browser layer-mask path instead of no-op. | current with tracked renderer gaps |
| Text conformance | `sh scripts/conformance-check.sh --text` and `sh scripts/conformance-check.sh --text-diagnostic` both passed. | current with shaping/emoji gaps documented |
| Platform contracts | `sh scripts/dev-check.sh --platform-examples-test` passed on macOS/Darwin and included `backend/macos` native backend tests. | current for macOS host; Windows/Linux runtime evidence remains host-limited |
| Examples | `moon test examples/showcase/app --target native` and `moon build examples/showcase/web_wasm --target wasm-gc` passed for Showcase capability alignment; daily checks also cover Markdown Editor app and Web build. | current |
| Guidance freshness | `AGENTS.md`, framework skill, and app skill were checked after release-readiness, platform validation, Showcase alignment, and text evidence updates. | current |

## Platform Validation Matrix

Preview handoffs must say which host produced platform evidence. Platform
claims should be scoped to the host that ran them; do not use a macOS check as
runtime evidence for Windows or Linux native behavior.

| Host | Routine command | What it proves | What remains out of scope |
| --- | --- | --- | --- |
| macOS / Darwin | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/macos` native backend tests on the current macOS host. | Windows native backend/runtime behavior, Windows packaging helper runtime behavior, Linux runtime backend behavior, and slow native example builds unless `--platform-examples-build` is also run. |
| Windows / MSYS/UCRT64 | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/windows` native backend tests on a Windows toolchain with Windows headers and runtime dependencies. | macOS AppKit behavior, Linux backend behavior, and slow Windows example builds unless `--platform-examples-build` is also run. |
| Linux | `sh scripts/dev-check.sh --platform-examples-test` | Daily package checks plus `backend/linux` scaffold tests. | Real Linux window runtime support; Linux remains an explicit scaffold until a `window/linux` package, native surface path, input normalization, and accessibility bridge exist. |

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
  users can inspect the current status data.
- The visual cards and app tests provide stronger evidence only for the draw
  commands they actually emit.

Current alignment:

| Renderer feature | Showcase visibility | Current app-level evidence | Release-readiness note |
| --- | --- | --- | --- |
| Rect / rounded rect | Visual panels and layout tiles. | Showcase app tests inspect rounded-rect marker output. | Covered as ordinary surface/control drawing. |
| Gradient | Visual styling and sparkline/card brushes. | Showcase app tests assert `FillRoundedRectBrush` with `LinearGradient`. | Covered by visible demo plus command-level app test. |
| Shadow | Theme/renderer cards and panels. | Showcase app tests assert `DrawShadow`. | Covered by visible demo plus command-level app test. |
| Text | Most catalog sections. | Showcase app tests assert many section labels and renderer report text. | Covered broadly as view output, while shaping conformance remains tracked in text tests. |
| Image | Text/media and visual correctness cards. | Showcase app tests assert `DrawImage`. | Covered for visible image commands; async diagnostics remain a renderer gap. |
| Clip | Scroll/capability card and clipped image demos. | Showcase app tests assert `PushClip` and clipped long renderer content; Web adapter tests preserve rounded clip host calls. | Covered for visible clipping; Web rounded clip submit uses the browser layer-mask path. |
| Transform | Visual correctness image uses scale/offset. | No dedicated Showcase test for transform semantics beyond generated commands. | Keep capability status `partial` until renderer tests cover layer-level transform state. |
| Opacity | Visual correctness image and state-driven visuals. | Showcase app tests assert `PushOpacity`. | Covered for view-level opacity emission; renderer-specific blending remains renderer evidence. |
| Layer compositing | Used indirectly by advanced renderer scopes where applicable. | Capability report card lists status; no dedicated Showcase assertion. | Keep primary evidence in renderer tests/report unless a visible layer demo is added. |
| Blend mode | Capability card lists status. | No dedicated Showcase visual assertion. | Renderer tests/report are primary evidence; add Showcase only if a visible comparison demo is useful. |
| Filter effect | Capability card lists status. | No dedicated Showcase visual assertion. | Renderer tests/report are primary evidence; add Showcase only if a visible comparison demo is useful. |
| Path/vector | Layout demos can emit custom draw commands, but there is no visible path gallery. | Renderer tests prove `PathSpec` tessellation only; renderer fallback planning now records `DrawPath` as a planned visible-renderer fallback. | Capability status remains `gap` until native/Web adapters execute path meshes visibly. |
| Shader effect | Capability card lists status. | No dedicated Showcase visual assertion. | Renderer tests/report are primary evidence; add Showcase only for user-inspectable built-ins. |
| Text shaping | Capability card lists status; text/media section exercises text views. | Text conformance tests are primary evidence. | Do not use Showcase labels as proof of bidi/line-breaking/typography parity. |
| Emoji text | Capability card lists status. | No deterministic Showcase assertion. | Keep native `gap` and Web `partial` until deterministic emoji coverage exists. |
| Async image | Capability card lists status; image demos render ordinary images. | No app-visible async diagnostic evidence yet. | Release-readiness work queue tracks app-visible diagnostics separately. |

If renderer support changes, update this alignment only when Showcase coverage
or its evidence level changes. Otherwise keep the authoritative support status
in `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
`docs/renderer-capability-report.md`.

## Work Queue

These slices are intentionally scoped so each can land with focused tests and
documentation evidence.

### Renderer

1. Layer-level transform state
   - Current status: affine transforms are folded into visual, image, and text
     vertices; layer-level transform state remains follow-up work.
   - Done when: native and Web behavior are explicit, tests cover the chosen
     semantics, and the capability report no longer overstates or understates
     support.
   - Evidence: renderer tests, `render/capabilities.mbt`,
     `render/capabilities_test.mbt`, `docs/renderer-capability-report.md`, and
     Showcase if visible.

2. Async image diagnostics
   - Current status: renderer-neutral lifecycle records model loading, ready,
     failed, disposed, and eviction; app-visible diagnostics still need adapter
     wiring.
   - Done when: native/Web adapters expose useful cache/load diagnostics to
     app-visible renderer state without changing the app model into a
     renderer-specific API.
   - Evidence: focused renderer/Web adapter tests, docs, and capability report.

3. Emoji and text shaping evidence
   - Current status: Web can rely on browser font rasterization, native color
     emoji is a gap, and full bidi/line breaking/typography conformance remains
     follow-up work. Stable and diagnostic conformance checks currently pass,
     but they document invariants and known gaps rather than claiming full
     Unicode shaping parity.
   - Done when: deterministic coverage improves without claiming full Unicode
     shaping parity before it exists.
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
   - Current status: explicit scaffold.
   - Done when: a real `window/linux` package, native surface path, input
     normalization, and accessibility bridge exist, or release notes clearly
     exclude Linux runtime support.
   - Evidence: backend tests, platform notes, and readiness report wording.

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

## Known Non-Goals

- Do not make compatibility shims for removed APIs unless explicitly requested.
- Do not move platform or renderer implementation details into `core/`.
- Do not describe Linux, DirectWrite, or fontconfig support as complete while
  their packages are scaffolds.
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
