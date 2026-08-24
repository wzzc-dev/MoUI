# MoUI 2026 Roadmap

MoUI is evolving from a MoonBit multi-platform GUI prototype into a usable,
maintainable, cross-platform declarative UI framework. This roadmap keeps the
project focused on practical application building, explicit platform contracts,
and clear engineering quality gates.

## 2026 Goals

- Provide a stable platform-neutral app/runtime/view model for MoonBit UI apps.
- Keep public view constructors simple and typed by returning opaque
  `@moui.View[Msg]`.
- Run the same shared app logic through Web wasm-gc/browser WebGPU, and native
  Skia raster entrypoints on macOS and Windows where those platforms are
  supported.
- Make examples useful as runnable documentation, not only smoke tests.
- Keep renderer capabilities transparent, tested, and documented.
- Maintain a predictable development loop with bounded checks and focused tests.
- Document AI collaboration workflows so generated changes remain reviewable and
  consistent with the architecture.

## Architectural Commitments

MoUI keeps the runtime pipeline explicit:

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

The package boundaries follow that pipeline:

- `core/` owns platform-neutral contracts, opaque `View[Msg]`, typed events,
  effects, subscriptions, layout/input/semantics/draw contracts, and the public
  message-independent `ViewNode` extension protocol wrapped by typed adapters.
- `runtime/` owns opaque `AppRuntime`, runtime state, tree/layout/paint,
  event dispatch, program message drain, effect-task lifecycle, subscription
  lifecycle, and runtime diagnostics.
- `views/` exposes public facade constructors that return `@moui.View[Msg]`.
- `backend/` defines shared host contracts.
- `backend/web/` is the browser wasm-gc host.
- `backend/macos/`, `backend/windows/`, and `backend/linux/` are native host
  cores that normalize platform events into `Event` and expose neutral
  host surfaces.
- `moui_skia_renderer` owns the native Skia mainline providers; `moui_wgpu_renderer` remains
  available for explicit native WGPU diagnostics. Applications compose either
  with one platform backend.
- `backend/linux/` is a Wayland host core with runtime-evidence, IME,
  clipboard, file dialog, directory listing, accessibility, and async image
  loading all wired through matching-host CI providers.
- `render/` owns renderer facades and capability reporting.
- `moui_skia_renderer/` implements the native Skia raster renderer facade.
- `moui_wgpu_renderer/` implements the experimental native wgpu renderer.
- `moui_web_renderer/` bridges wasm-gc apps to browser WebGPU host imports.
- `examples/*/app/` packages contain shared app logic; platform subpackages are
  entrypoints only.

## Workstream 1: Runtime And Public API

Focus areas:

- Stabilize `AppRuntime::new_view` for direct static views and
  `AppRuntime::new_program` as the default typed app runtime.
- Keep `ComponentContext::watch` and `ctx.binding` as the preferred state access
  patterns during component builds.
- Use `ComponentContext::run_effect` for component-scoped effects with cleanup, and
  the scoped save/restore helpers for small saveable string state.
- Preserve ordered modifier semantics through public `View[Msg]` modifiers.
- Keep `@views.custom_children_layout` as the advanced child layout delegate
  for package-local custom controls and layout experiments.
- Keep input, focus, text editing, layout, paint, and semantics behavior in
  platform-neutral packages.
- Review public API changes with `moon info` and generated `pkg.generated.mbti`
  diffs.

First P0 foundations now exist for component effects, saveable string/bool/int
state, custom child layout delegates, and keyed effect reuse. Follow-up work
should broaden saveable state into a general codec model, add richer lifecycle
coverage beyond the current `on_mount`/`on_dispose` helpers, and extend the
custom layout protocol with layout cache and alignment guides. Custom layouts
already receive child baseline and layout priority signals.

Validation:

```sh
moon test moui/core --target native
moon check --warn-list +unnecessary_annotation
moon info
```

## Workstream 2: Views And Application Usability

Focus areas:

- Keep Text, Button, TextField, Checkbox, Container, Row/Column/Flex,
  Stack, Scroll, List, Grid, Navigation, and Markdown Editor usable in real apps.
- Prefer MoonBit-style labeled and optional parameters for public constructors.
- Add semantics for interactive controls where possible.
- Maintain a view catalog that records API examples, theme support, semantics,
  tests, and example coverage.
- Use Showcase as the visual index for controls, layout, theme, and renderer
  capability status.
- Prefer Showcase coverage for new user-facing framework features. When a new
  view, renderer capability, host-service interaction, or inspectable platform
  behavior lands, add a visible Showcase example and app-level assertion unless
  the feature is better validated only by focused tests or platform docs.

Validation:

```sh
moon test moui/views --target native
moon test examples/showcase/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
```

## Workstream 3: Practical Examples

The examples should demonstrate progressively larger slices of the framework:

| Example | Purpose | Shared app package | Primary capabilities |
| --- | --- | --- | --- |
| Showcase | Visual system index | `examples/showcase/app/` | Controls, layout, theme, renderer features, Counter/Todo patterns |
| Markdown Editor | Practical editing demo | `examples/markdown_editor/app/` | Rich text editing, styled runs, app-level parsing |

Example work should keep business logic in `examples/*/app/` and leave platform
packages as thin entrypoints.

Showcase is the default visible verification surface for framework additions.
New functionality that affects what an app author can see or exercise should be
represented there where practical, so release handoffs can pair focused tests
with an inspectable example.

Validation:

```sh
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

## Workstream 4: Renderer Capability Tracking

Renderer feature status is tracked in code and documentation:

- `render/capabilities.mbt`
- `render/capabilities_test.mbt`
- `docs/renderer-capability-report.md`
- `docs/feature-proof-matrix.md` (feature-to-CI proof mapping)
- `docs/feature-status-dashboard.md` (proof coverage dashboard)

When image, clip, opacity, transform, or other draw command support changes,
update all five files together.

Current priorities:

1. Keep transform behavior explicit and consistent between the native Skia
   raster mainline and Web wasm-gc/WebGPU renderer, while keeping native WGPU
   transform diagnostics available under the explicit experimental path.
2. Finish text shaping conformance across bidi, line breaking, fallback font
   runs, and native provider behavior.
3. Keep improving deterministic emoji text coverage; Cosmic now loads platform
   emoji fallback font candidates when available and carries caret coverage
   through a provider-safe mapped native layout path for representative emoji
   clusters, while full native emoji font fallback across all providers and
   ZWJ/color emoji conformance remain known gaps.
4. Surface async image cache and load diagnostics to app-visible renderer state.
5. Keep Showcase capability status aligned with
   `docs/renderer-capability-report.md` so visual behavior is easy to verify.
   Add Showcase coverage for renderer improvements when the behavior is
   inspectable, and document why renderer tests/report are the primary observation
   when it is not.

Validation:

```sh
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_web_renderer --target wasm-gc
sh scripts/check.sh --profile full
moon build examples/showcase/web_wasm --target wasm-gc
```

Run `sh scripts/check.sh --profile full` or
`moon test moui_wgpu_renderer --target native` only when touching the native WGPU
diagnostic renderer.

## Workstream 5: Platform Contracts

MoUI treats platform backends as adapters around a shared host contract.

Focus areas:

- Keep `backend/` as the source of truth for `Event`, surface, input,
  text input, file drag/drop, window event, metrics, and redraw contracts.
- Keep Web on the single `wasm-gc + window/web + browser WebGPU host imports`
  path.
- Keep macOS native host documentation aligned with AppKit and the native Skia
  provider setup; keep CAMetalLayer/wgpu-native requirements scoped to WGPU
  diagnostics.
- Keep Windows native setup reproducible with Visual Studio C++ build tools,
  vcpkg `zlib:x64-windows`, and renderer-aware build/package helpers. Native
  Skia packages should not download or bundle `wgpu_native.dll`; explicit WGPU
  diagnostic packages keep the existing `wgpu_mbt` dynamic route.
- Keep Linux supported on Ubuntu 24.04+ Wayland with matching-host runtime
  evidence and font-provider coverage (fonts-noto-core, fonts-dejavu-core).
- Use `HostServiceBridge` as the typed host-service boundary for clipboard,
  menus, file dialogs, URL opening, and system-theme queries.
- Use `ServiceAsyncQueue` for browser or platform services that require
  permission prompts, picker callbacks, or other async completion before the
  runtime can safely apply the result.
- Keep Web clipboard behavior honest: copy/cut write selected text through a
  browser host import, focused browser text input can still paste through input
  events, and app-level clipboard reads/file dialogs flow through
  `ServiceAsyncQueue` into browser permission or picker callbacks. The app
  sees only `ServiceTaskResult` messages; request ids and completion queues stay
  behind the host adapter.
- Keep URL opening honest across active hosts: macOS uses `NSWorkspace`, Windows
  uses `ShellExecuteW`, and Web uses a browser host import that calls
  `window.open` and can report popup-blocked failures.
- Keep file drag/drop on the shared host path: macOS and Windows forward native
  file paths, while Web forwards browser-exposed file names from canvas drop
  events.
- Keep system theme propagation on the host-service path: native macOS and
  Windows startup now installs the queried light/dark scheme into runtime
  environment before the first layout/redraw pass. Web startup uses the browser
  `prefers-color-scheme` query, and Web/macOS/Windows theme-change window events
  flow through `Event::ThemeChanged`.
- Keep window lifecycle state flowing through `WindowRegistry`; active
  entrypoints allocate primary window records, register the current
  runtime/driver as primary runtime slots, bind platform window ids to host ids,
  route incoming platform window events through that map, and sync those slots
  from the shared lifecycle path. Options-bearing runners drain
  `WindowRequestQueue` for focus, close, resize, minimize, show, and
  set-primary requests. Drained request completions are recorded back onto the
  queue through a shared host helper so request outcomes stay observable.
  `OpenWindow` requests carry a platform-neutral scene id and payload.
  `WindowSceneResolver` is the shared scene-to-`AppRuntime` contract for
  that resolution step, and `@backend_common.resolve_open_request` pairs
  successful resolutions with window records. `WindowRuntimeSlot` wraps
  those records with per-window `HostRuntimeDriver` instances, while
  `WindowRuntimeSlots` manages lookup, focused/primary slot selection, and
  registry-backed insert/sync/request/lifecycle helpers plus closed-slot
  cleanup. Web creates another browser canvas and `WebRenderer`; native hosts
  create another platform window and ask their renderer provider for a
  renderer-neutral `RendererSession`, then attach platform-window bindings,
  platform slots, and per-window drivers before routing redraw/event/
  context-menu/IME/dispose paths through `WindowId`.
- Keep Linux readiness explicit through its backend readiness report until
  matching-host runtime evidence and native font provider support are available.

Validation:

```sh
moon test moui/backend --target native
moon test moui/backend/web --target wasm-gc
sh scripts/check.sh --profile platform
```

## Workstream 6: Documentation And AI Collaboration

Documentation should help users and maintainers move from overview to running
code to extending the framework.

Planned documentation set:

- `README.md`: short entry point, quick start, example commands, and docs index.
- `docs/architecture.md`: package model and runtime mental model.
- `docs/development.md`: setup, focused checks, platform validation commands.
- `docs/platform-notes.md`: platform-specific requirements and troubleshooting.
- `docs/text-system.md`: text measurement, provider composition, embedded
  fonts, and shaping gaps.
- `docs/renderer-capability-report.md`: renderer status and update rule.
- `docs/roadmap-2026.md`: project direction and quality gates.
- `docs/view-catalog.md`: view APIs and support matrix.
- `docs/examples.md`: example purposes, commands, and validation.
- `docs/markdown-editor.md`: WYSIWYG Markdown Editor model and workflows.
- `docs/testing.md`: testing layers and release checks.
- `docs/ai-collaboration.md`: AI workflow, prompt templates, and review
  checklist.
- `docs/release-readiness.md`: preview-release gates, current observation, known
  gaps, and next implementation slices.

The project also includes MoUI-specific skills at:

```text
skills/moui-framework-development-skill/SKILL.md
skills/moui-app-development-skill/SKILL.md
```

The framework skill should guide agents to read `AGENTS.md`, respect package
boundaries, preserve the runtime pipeline, use focused validation, and update
renderer capability files together. The app skill should keep application work
focused on shared app packages, public view APIs, and thin platform entrypoints.
Both skills and `AGENTS.md` should be reviewed whenever docs placement,
validation commands, platform behavior, example structure, renderer capability
status, or text architecture changes.

## Quality Gates

Daily development check:

```sh
sh scripts/check.sh --profile daily
```

Public API review:

```sh
moon info
```

Platform validation when needed:

```sh
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile full
```

Before a release, the project should have:

- Passing bounded development checks.
- Reviewed `pkg.generated.mbti` changes after public API edits.
- Runnable Web wasm-gc examples.
- Current-platform native example validation.
- Renderer capability report synchronized with tests and code.
- Updated docs for changed commands, package layout, platform behavior, or
  user-facing APIs.

## Release Readiness Snapshot

Use this snapshot as the final handoff checklist for the current project shape:

- README explains the project value, package map, and Web/native example entrypoints.
- Architecture, development, platform, examples, testing, renderer capability, AI
  collaboration, release-readiness, text-system, Markdown Editor, and view
  catalog docs are linked from the README.
- Showcase and Markdown Editor keep shared app logic under `examples/*/app/`
  with platform packages as thin entrypoints; Counter and Todo live inside
  Showcase as built-in interaction patterns.
- Showcase surfaces renderer capability status for visual review.
- Daily validation is centralized in `sh scripts/check.sh --profile daily` and includes
  core, views, render facade, native Skia, backend host/Web, example app tests,
  and Web wasm-gc example builds. Native WGPU diagnostics run only with
  `--wgpu-experimental`.
- Platform validation remains opt-in through `--profile platform` and
  `--profile full` because native executable builds depend on the
  current host setup.
- Linux backend is fully wired: clipboard (text + image), file dialog (portal +
  zenity fallback), directory listing, text/binary file I/O, open URL, system
  theme, native menus (zenity + kdialog), IME, drag-drop, AT-SPI accessibility,
  GLib timer host, client-side decorations, multi-window, platform view
  plugins, and async image loading (pthread + Skia decode). Keep runtime
  evidence current on matching Wayland hosts.
- `AGENTS.md` and repo-local skills have been checked against the current docs,
  examples, validation commands, and text/rendering architecture.
