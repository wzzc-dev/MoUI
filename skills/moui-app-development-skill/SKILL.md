---
name: moui-app-development-skill
description: Use this skill when building applications with MoUI rather than changing the MoUI framework itself, including app package structure, view composition, state, layout, styles, event handling, text input, platform entrypoints, example apps, and app-focused validation commands.
version: 0.1.0
---

# MoUI App Development Skill

## Purpose

This skill is for using MoUI to build applications. It keeps app work focused on
application packages, existing public view APIs, shared app logic, and thin
platform entrypoints. It is intentionally separate from framework maintenance.

## When To Use

Use this skill when the user asks to:

- Create or extend a MoUI app, demo, prototype, editor, tool, or example.
- Compose views from `views/` and `core/` public APIs.
- Add app state, event handling, layout, styling, text input, lists, scrolling,
  or navigation behavior.
- Add or adjust shared app logic under `examples/<name>/app`.
- Add or adjust platform entrypoints under `examples/<name>/web_wasm`,
  `examples/<name>/macos`, `examples/<name>/windows`, or
  `examples/<name>/linux`.
- Validate an application build or app-level tests.

## Non-Goals

- Do not change `core/`, `render/`, or `backend/` unless the user explicitly
  asks for framework work or an app task exposes a real framework defect.
- Do not add compatibility shims to the framework just to make one app easier.
- Do not run broad platform or all-repository checks before app-focused checks.
- Do not move shared app logic into platform entrypoints.

If an app needs a missing framework capability, describe the gap and propose a
separate framework task using `moui-framework-development-skill`.

## First Files To Read

1. `AGENTS.md`
2. `README.mbt.md`
3. `docs/development.md`
4. `docs/view-catalog.md`
5. `docs/examples.md`
6. `docs/app-templates.md` when starting a new shared app package
7. `docs/non-render-component-cookbook.md` when composing common app workflows
8. `docs/markdown-editor.md` when using or extending the Markdown Editor
9. `docs/text-system.md` when app behavior depends on text metrics, fonts, or
   native/Web text differences
10. `docs/platform-notes.md` when platform setup matters
11. The closest existing app under `examples/*/app`
12. The app's `moon.pkg` and platform entrypoint `moon.pkg` files

## App Shape

- Shared app logic lives in `examples/<name>/app`.
- Platform packages stay thin and only wire the shared app to the host.
- App UI should be built from public view constructors returning
  opaque `@core.View[Msg]`.
- Keep state, reducers, data models, and view composition in the shared app
  package when the behavior should work across platforms.
- Keep platform-specific setup in `web_wasm`, `macos`, `windows`, or `linux`
  entrypoints.
- Showcase also has `macos_cosmic`, `windows_cosmic`, and `linux_cosmic`
  entrypoints when an app task needs explicit Moon Cosmic text-provider
  comparison, plus `macos_skia` when it needs explicit native Skia renderer
  selection.
- Treat Linux as a scaffold until the framework has a real Linux backend.

## Development Workflow

1. Identify the target app and platform output.
2. Read the closest existing example before inventing a structure.
3. Inspect `moon.pkg` boundaries and imports.
4. Implement app behavior in the shared app package first.
5. Keep platform entrypoint changes minimal.
6. Add focused app-package tests for model, state, reducer, or pure behavior.
7. Build the affected Web wasm-gc entrypoint when browser output changes.
8. Use platform builds only when the task requires that platform.
9. Run `moon fmt`.
10. Update `docs/examples.md`, `docs/markdown-editor.md`, `AGENTS.md`, or
    repo-local skills when app-facing guidance changes.
11. Report app paths changed, validation commands, and any framework gaps.

## Useful Commands

App package tests:

```sh
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
```

Web app builds:

```sh
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Native example builds:

```sh
moon build examples/showcase/macos --target native
moon build examples/showcase/macos_cosmic --target native
moon build examples/showcase/macos_skia --target native
moon build examples/showcase/windows --target native
moon build examples/showcase/windows_cosmic --target native
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
moon build examples/markdown_editor/macos --target native
moon build examples/markdown_editor/windows --target native
```

Native packaging helpers:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

Routine repo check when the app change is broad:

```sh
sh scripts/dev-check.sh
```

Platform checks only when needed:

```sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
```

## App Playbooks

### Create Or Extend An Example App

- Put reusable logic in `examples/<name>/app`.
- Start from `docs/app-templates.md` when the app does not have an established
  local shape yet.
- Copy platform wiring patterns from the closest existing example.
- Add app-level tests for pure behavior.
- Update `docs/examples.md` and `docs/app-templates.md` when adding a new
  reusable app shape, command, or purpose.
  Update `docs/markdown-editor.md` when changing that editor's model,
  commands, or platform behavior.
- Build the Web wasm-gc entrypoint if the app has Web output.

### Build UI With Existing Views

- Prefer public constructors from `views/`.
- Keep layout decisions local to the app view tree.
- Keep reusable style choices in app helpers only after duplication appears.
- If a public view is missing, first check `docs/view-catalog.md` and existing
  examples before adding framework APIs.

### Handle State And Events

- Keep app state transitions testable without platform hosts.
- Route user actions through existing MoUI event APIs and app reducers/helpers.
- Keep host-specific input conversion in backend packages out of app code.

### Add Platform Entry Points

- Keep entrypoints as wiring only.
- Import the shared app package and pass the root view to the platform host.
- Do not duplicate app state or view composition in each platform package.
- Check `docs/platform-notes.md` before changing platform setup.

## Common Mistakes

- Editing framework packages for app-only convenience.
- Duplicating shared UI or state in platform entrypoints.
- Treating Web as a JS-target app instead of wasm-gc browser host imports.
- Running slow native platform builds when app-package tests or Web builds are
  enough.
- Forgetting to update `docs/examples.md` after adding or reshaping examples.
- Forgetting that app-facing docs, `AGENTS.md`, and repo-local skills may need
  updates after example, validation, platform, or text-behavior changes.
