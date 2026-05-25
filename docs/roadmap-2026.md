# MoUI 2026 Roadmap

MoUI is evolving from a MoonBit multi-platform GUI prototype into a usable,
maintainable, cross-platform declarative UI framework. This roadmap keeps the
project focused on practical application building, explicit platform contracts,
and clear engineering quality gates.

## 2026 Goals

- Provide a stable platform-neutral app/runtime/view model for MoonBit UI apps.
- Keep public view constructors simple and spec-first by returning
  `@core.ViewSpec`.
- Run the same shared app logic through Web wasm-gc, macOS native, and Windows
  native entrypoints.
- Make examples useful as runnable documentation, not only smoke tests.
- Keep renderer capabilities transparent, tested, and documented.
- Maintain a predictable development loop with bounded checks and focused tests.
- Document AI collaboration workflows so generated changes remain reviewable and
  consistent with the architecture.

## Architectural Commitments

MoUI keeps the runtime pipeline explicit:

```text
ViewSpec -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
```

The package boundaries follow that pipeline:

- `core/` owns platform-neutral runtime, state, layout, input, semantics, and the
  draw command model.
- `views/` exposes public view constructors that return `@core.ViewSpec`.
- `backend/host/` defines shared host contracts.
- `backend/web/`, `backend/macos/`, and `backend/windows/` normalize platform
  events into `HostEvent`.
- `backend/linux/` remains an explicit scaffold until the platform path is ready.
- `render/` owns renderer facades and capability reporting.
- `render/wgpu/` implements the native wgpu renderer.
- `render/webgpu_adapter/` bridges wasm-gc apps to browser WebGPU host imports.
- `examples/*/app/` packages contain shared app logic; platform subpackages are
  entrypoints only.

## Workstream 1: Runtime And Public API

Focus areas:

- Stabilize `AppRuntime::new_spec` and `AppRuntime::new_component` usage.
- Keep `BuildContext::watch` and `ctx.binding` as the preferred state access
  patterns during component builds.
- Use `BuildContext::run_effect` for component-scoped effects with cleanup, and
  the scoped save/restore helpers for small saveable string state.
- Preserve ordered modifier semantics through `ModifiedSpec` wrappers.
- Keep `ViewSpec::custom_layout` as the advanced child layout delegate for
  package-local custom controls and layout experiments.
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
moon test core --target native
moon check --warn-list +unnecessary_annotation
moon info
```

## Workstream 2: Views And Application Usability

Focus areas:

- Keep Text, Button, TextField, Checkbox, Container/Surface, Row/Column/Flex,
  Stack, Scroll, List, Grid, Navigation, and Markdown Editor usable in real apps.
- Prefer MoonBit-style labeled and optional parameters for public constructors.
- Add semantics for interactive controls where possible.
- Maintain a view catalog that records API examples, theme support, semantics,
  tests, and example coverage.
- Use Showcase as the visual index for controls, layout, theme, and renderer
  capability status.

Validation:

```sh
moon test views --target native
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

When image, clip, opacity, transform, or other draw command support changes,
update all three files together.

Current priorities:

1. Keep transform behavior explicit and consistent between native wgpu and Web
   wasm-gc renderers, especially the remaining layer-level transform state.
2. Finish text shaping conformance across bidi, line breaking, fallback font
   runs, and native provider behavior.
3. Add deterministic emoji text coverage, with native color emoji still a known
   gap.
4. Surface async image cache and load diagnostics to app-visible renderer state.
5. Keep Showcase capability status aligned with
   `docs/renderer-capability-report.md` so visual behavior is easy to verify.

Validation:

```sh
moon test render --target native
moon test render/wgpu --target native
moon test render/webgpu_adapter --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
```

## Workstream 5: Platform Contracts

MoUI treats platform backends as adapters around a shared host contract.

Focus areas:

- Keep `backend/host/` as the source of truth for `HostEvent`, surface, input,
  text input, file drag/drop, window event, metrics, and redraw contracts.
- Keep Web on the single `wasm-gc + window/web + browser WebGPU host imports`
  path.
- Keep macOS native host documentation aligned with AppKit, CAMetalLayer, and
  wgpu-native requirements.
- Keep Windows native setup reproducible with MSYS2 UCRT64 and the expected
  static GNU `wgpu-native` release.
- Keep Linux clearly marked as scaffold until a minimal backend is implemented.
- Use `HostServiceBridge` as the typed host-service boundary for clipboard,
  menus, file dialogs, URL opening, and system-theme queries.
- Use `HostServiceAsyncQueue` for browser or platform services that require
  permission prompts, picker callbacks, or other async completion before the
  runtime can safely apply the result.
- Keep Web clipboard behavior honest: copy/cut write selected text through a
  browser host import, focused browser text input can still paste through input
  events, and app-level clipboard reads/file dialogs flow through
  `HostServiceAsyncQueue` into browser permission or picker callbacks.
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
  flow through `HostEvent::ThemeChanged`.
- Keep window lifecycle state flowing through `HostWindowRegistry`; current
  Web, macOS, and Windows entrypoints remain single-window but already allocate
  primary window records, register the current runtime/driver as primary
  runtime slots, bind platform window ids to host ids, route incoming platform
  window events through that map, and sync those slots from the shared
  lifecycle path. Web also stores its active browser `Window` and `WebRenderer`
  in a per-window platform slot collection and routes redraw/event/context-menu
  paths through the matching runtime driver slot, preparing the platform side
  for multiple canvases. Their active loops now expose
  `run_app_with_window_requests` and drain `HostWindowRequestQueue` for
  current-window focus, close, resize, minimize, show, and set-primary requests.
  Drained request completions are recorded back onto the queue through a shared
  host helper so request outcomes stay observable while the active hosts remain
  single-window. `OpenWindow` requests already carry a platform-neutral scene id
  and payload so future hosts can
  resolve the new window's runtime/content without inventing a platform-local
  convention. `HostWindowSceneResolver` is the shared scene-to-`AppRuntime`
  contract for that resolution step, and `HostWindowRegistry::resolve_open_request`
  pairs successful resolutions with window records. `HostWindowRuntimeSlot`
  wraps those records with per-window `HostRuntimeDriver` instances, while
  `HostWindowRuntimeSlots` manages lookup, focused/primary slot selection, and
  registry-backed insert/sync/request/lifecycle helpers plus closed-slot
  cleanup. Full `OpenWindow` support remains a follow-up because it requires
  wiring that path into multiple platform windows, renderer instances, and
  platform-window bindings, not just extra registry records.
- Keep Linux readiness explicit through its backend readiness report until a
  real `window/linux` package, native surface path, and accessibility bridge are
  available.

Validation:

```sh
moon test backend/host --target native
moon test backend/web --target wasm-gc
sh scripts/dev-check.sh --platform-examples-test
```

## Workstream 6: Documentation And AI Collaboration

Documentation should help users and maintainers move from overview to running
code to extending the framework.

Planned documentation set:

- `README.mbt.md`: short entry point, quick start, example commands, docs index.
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
sh scripts/dev-check.sh
```

Public API review:

```sh
moon info
```

Platform validation when needed:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
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
  collaboration, text-system, Markdown Editor, and view catalog docs are linked
  from the README.
- Showcase and Markdown Editor keep shared app logic under `examples/*/app/`
  with platform packages as thin entrypoints; Counter and Todo live inside
  Showcase as built-in interaction patterns.
- Showcase surfaces renderer capability status for visual review.
- Daily validation is centralized in `sh scripts/dev-check.sh` and includes core,
  views, render, native wgpu, backend host/web, example app tests, and Web
  wasm-gc example builds.
- Platform validation remains opt-in through `--platform-examples-test` and
  `--platform-examples-build` because native executable builds depend on the
  current host setup.
- Linux remains an explicit scaffold until a real backend is implemented.
- `AGENTS.md` and repo-local skills have been checked against the current docs,
  examples, validation commands, and text/rendering architecture.
