---
name: moui-skill
description: Use this skill when working on the MoUI MoonBit GUI framework, including architecture, ViewSpec/runtime/layout/state/rendering/backends, platform hosts, examples, renderer capability tracking, documentation, validation commands, or project-specific deliverables.
version: 0.1.0
---

# MoUI Skill

## Purpose

This skill is for MoUI-specific work. It complements general MoonBit guidance by
pinning MoUI's package boundaries, runtime invariants, renderer capability rules,
platform contract, and validation commands.

## When To Use

Use this skill when editing or reviewing:

- `core/` runtime, state, layout, input, semantics, or draw commands.
- `views/` public constructors and modifiers.
- `backend/host`, `backend/web`, `backend/macos`, `backend/windows`, or
  `backend/linux`.
- `render/`, `render/wgpu`, or `render/webgpu_adapter`.
- `examples/*/app` shared app logic or platform example entrypoints.
- `docs/*`, README, roadmap, testing docs, or AI collaboration materials.
- Renderer capability status, Showcase capability display, or validation scripts.

## First Files To Read

1. `AGENTS.md`
2. `README.mbt.md`
3. `docs/architecture.md`
4. `docs/development.md`
5. `docs/platform-notes.md`
6. `docs/renderer-capability-report.md`
7. `docs/testing.md` when validation scope matters
8. `docs/view-catalog.md` when touching `views/`
9. `docs/examples.md` when touching examples

## Project Invariants

- Public view constructors return `@core.ViewSpec`.
- Runtime pipeline:

  ```text
  ViewSpec -> ElementNode -> MeasuredNode/PlacedNode -> RenderNode -> DrawCommand -> renderer
  ```

- `core/` stays platform-neutral.
- Platform packages normalize native events into `@host.HostEvent`.
- Backends do not mutate element or render trees directly.
- Renderers consume platform-neutral `@core.DrawCommand` values.
- `examples/*/app` packages own shared app logic.
- Platform example packages should stay thin entrypoints.
- Web is `wasm-gc + window/web + browser WebGPU host imports`; there is no
  JS-target fallback.
- Linux is a scaffold until a real window backend exists.
- Public API changes require `moon info` and review of `pkg.generated.mbti` diffs.
- Renderer capability changes require synchronized updates to code, tests, docs,
  and Showcase when visible.

## Package Map

- `core/`: platform-neutral runtime, view specs, state, layout, input, semantics,
  rich text editing, draw commands, styles, and theme tokens.
- `style/`: visual token and style compatibility aliases.
- `views/`: public view constructors returning `@core.ViewSpec`.
- `backend/host/`: shared `HostEvent`, surface metrics, input contracts,
  text-input session, window-event conversion, and redraw driver.
- `backend/web/`: wasm-gc Web host, canvas constraints, browser runtime bridge,
  and accessibility adapter.
- `backend/macos/`: AppKit/window host and CAMetalLayer WGPU surface creation.
- `backend/windows/`: Win32/window host and HWND WGPU surface creation.
- `backend/linux/`: explicit scaffold with host contract shape but no real window
  backend yet.
- `render/`: renderer facade, shared draw helpers, and capability report API.
- `render/wgpu/`: native wgpu renderer.
- `render/webgpu_adapter/`: wasm-gc bridge to browser WebGPU host imports.
- `examples/*/app`: shared application logic.
- `examples/*/{web_wasm,macos,windows}`: platform entrypoints.

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
10. Report changed files, validation commands, and remaining risks.

## Validation Commands

Daily check:

```sh
sh scripts/dev-check.sh
```

Focused checks:

```sh
moon test core --target native
moon test views --target native
moon test backend/host --target native
moon test backend/web --target wasm-gc
moon test render --target native
moon test render/wgpu --target native
moon test render/webgpu_adapter --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Platform validation:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
```

Public API review:

```sh
moon info
```

## Playbooks

### Add A View

- Implement in `views/` using existing `@core.ViewSpec` variants, modifiers,
  styles, and bindings.
- Add focused tests in `views/views_test.mbt`.
- Add Showcase coverage if the view is user-facing and visual.
- Update `docs/view-catalog.md`.
- Run `moon test views --target native`, `moon fmt`, and `moon info` if public.

### Change Renderer Capability

- Keep the boundary at `@core.DrawCommand`.
- Update renderer implementation and tests.
- Update `render/capabilities.mbt`.
- Update `render/capabilities_test.mbt`.
- Update `docs/renderer-capability-report.md`.
- Update Showcase if the capability is visible.
- Run renderer tests and a Showcase Web wasm-gc build.

### Change Backend Event Handling

- Keep platform-specific code inside the platform backend.
- Normalize through `backend/host` and `HostEvent`.
- Add or update `backend/host` tests when shared behavior changes.
- Run the affected backend package tests.
- Update `docs/platform-notes.md` when constraints or setup change.

### Update Examples

- Keep shared behavior under `examples/<name>/app`.
- Keep platform packages as entrypoints.
- Add app-package tests for model or runtime behavior.
- Build the affected Web wasm-gc entrypoint when browser output changes.
- Update `docs/examples.md` when commands, paths, or coverage change.

### Update Documentation

- Keep `README.mbt.md` short.
- Put architecture in `docs/architecture.md`.
- Put setup and command loops in `docs/development.md`.
- Put platform caveats in `docs/platform-notes.md`.
- Put example scope in `docs/examples.md`.
- Put validation policy in `docs/testing.md`.
- Put renderer status in `docs/renderer-capability-report.md`.

## Common Mistakes

- Adding platform logic to `core/`.
- Returning anything other than `@core.ViewSpec` from public view constructors.
- Skipping `moon info` after public API changes.
- Updating renderer support without updating capability docs and tests.
- Treating Linux as complete instead of scaffold.
- Moving shared example logic into platform entrypoints.
- Running broad native checks before focused package validation.
