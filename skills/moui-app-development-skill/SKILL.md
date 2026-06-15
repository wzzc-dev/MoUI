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
- Create or extend the root `website/` homepage app workspace.
- Compose views from `views/` and `core/` public APIs.
- Add app state, event handling, layout, styling, text input, lists, scrolling,
  or navigation behavior.
- Add or adjust shared app logic under `examples/<name>/app`.
- Add or adjust platform entrypoints under `examples/<name>/web_wasm`,
  `examples/<name>/macos`, `examples/<name>/windows`, or
  `examples/<name>/linux` when that example has a runnable host package.
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
2. `README.md`
3. `docs/development.md`
4. `docs/view-catalog.md`
5. `docs/examples.md`
6. `docs/app-templates.md` when starting a new shared app package
7. `docs/non-render-component-cookbook.md` when composing common app workflows
8. `docs/markdown-editor.md` when using or extending the Markdown Editor
9. `docs/text-system.md` when app behavior depends on text metrics, fonts, or
   native/Web text differences
10. `docs/platform-notes.md` when platform setup matters
11. The closest existing app under `examples/*/app`, especially
    `examples/counter/app` for the smallest TEA shape
12. The app's `moon.pkg` and platform entrypoint `moon.pkg` files

## App Shape

- Shared app logic usually lives in `examples/<name>/app`; the root
  `website/` workspace is the MoUI homepage exception and keeps shared homepage
  and runtime docs logic in `website/app`.
- Platform packages stay thin and only wire the shared app to the host.
- `website/web_wasm` is Web-only and should stay a thin homepage/docs
  entrypoint. Website Docs read same-origin static Markdown from `docs/*.md` at
  runtime through the Web text-file service; do not compile those Markdown files
  into wasm for the normal website path.
- Counter has `web_wasm`, `macos_wgpu`, `windows_wgpu`, `linux_wgpu`, and
  `windows_wgpu_cosmic` entrypoints and is the smallest runnable app shape.
- Some examples are shared-app only. Settings, Data Table, File Importer, and
  Command Palette intentionally exercise app patterns without platform
  entrypoints. Data Table covers operational table state such as filtering,
  sorting, column visibility, app-owned column width/order, selection, and
  pagination.
- App UI should be built from public view constructors returning opaque
  `@moui.View[Msg]` / `@core.View[Msg]` compatible values. Ordinary shared app
  packages should default to importing `wzzc-dev/moui` and
  `wzzc-dev/moui/views`; add `core` only for low-level framework contracts that
  do not belong in the root facade or `views`.
- Keep state, reducers, data models, and view composition in the shared app
  package when the behavior should work across platforms.
- Keep route and deep-link history in shared app state with
  `@core.RouteHistoryState` when the app needs a serializable back/forward
  shadow stack. Use `@host.HostRouteSource` when a host or platform publishes
  typed route/deep-link events through `Subscription::route_event`, then update
  the app-owned history in the reducer. Use `View::transition` with app-owned
  progress when a route preview needs controlled fade/slide/scale motion.
  Web entrypoints can wire `backend/web` browser history helpers to abstract
  app route commands and pass a `HostRouteSource` through `WebAppOptions`.
  Native URL/deep-link dispatch and automatic transition scheduling remain
  explicit app/host work rather than automatic platform behavior.
- Prefer the TEA helpers from the root facade: use `@moui.Program::simple` for
  pure model/update/view apps, `@moui.Program::simple_with_environment` when
  the view needs `ViewEnvironment`, and `@moui.Program::new` when `update`
  returns `@moui.Effect[Msg]` follow-up work. Synchronous clicks, effects, tasks, and
  subscription callbacks enter the same bounded runtime message queue; avoid
  relying on an intentional synchronous self-loop to finish all work in one
  host callback.
- Use `subscriptions=model => ...` on `Program` when an app has ongoing typed
  event sources such as ticks, route/deep-link streams, or service completions
  that should be reused by stable key and canceled when the model no longer
  declares them. Prefer `Subscription::timer`,
  `Subscription::animation_tick`, `Subscription::window_event`,
  `Subscription::host_event`, `Subscription::route_event`, or
  `Subscription::service_completion` when a source matches those standard
  descriptor categories; use `Subscription::listen` / `Subscription::run` for
  custom kinds. Keep concrete timer or host adapters outside `core`.
- Keep host-service calls out of pure reducers. For app-owned clipboard, file
  dialog, text-file, URL, theme, or menu work, return `@moui.Effect::host_service` with a
  stable diagnostic key that is unique within the returned effect batch, call
  `@host.HostAppServices` inside the effect runner, and dispatch a typed
  completion message back into the model. Use `@moui.Effect::run` for custom
  structured effect kinds, `@moui.Effect::service_task` for service-like
  one-shot async tasks that need runtime-owned cancellation, completion, and
  stale-dispatch diagnostics, or `@moui.Effect::task` for custom task
  descriptor kinds. When a service returns
  `HostServiceResponse::Pending(id)`, store the id in app model state and
  declare `HostAppServices::completion_subscription` from
  `subscriptions=model => ...` so the later host callback re-enters the same
  typed message loop and is canceled when the model no longer declares it.
  Lift child service-completion subscriptions with `Subscription::map` when
  composing child features.
- Keep platform-specific setup in profile entrypoints such as `web_wasm`,
  `macos_wgpu`, `windows_skia`, or `linux_wgpu_cosmic`.
- Showcase and Markdown Editor use `macos_skia`, `windows_skia`, and
  `linux_skia` for the recommended native Skia renderer entrypoints. Showcase
  also has `macos_wgpu_cosmic`, `windows_wgpu_cosmic`, and `linux_wgpu_cosmic` entrypoints
  when an app task needs explicit Moon Cosmic text-provider comparison on the
  native WGPU diagnostic route.
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
moon test examples/counter/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/design_systems/app --target native
moon test examples/settings/app --target native
moon test examples/data_table/app --target native
moon test examples/file_importer/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
node scripts/pdf-workbench-native-smoke.mjs
scripts/pdf-workbench-macos-smoke.sh
moon test examples/command_palette/app --target native
```

Prefix app-only tests with `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` when the change
does not need real native Skia and the local Skia release artifact is not
already cached. For PDF Workbench app-only, protocol,
`pdflite_service_native_transport`, or `pdflite_adapter` checks, also set
`MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1` unless the native PDFium raster adapter
is under test.

Web app builds:

```sh
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/design_systems/web_wasm --target wasm-gc
```

Native example builds:

```sh
moon build examples/showcase/macos_skia --target native
moon build examples/showcase/windows_skia --target native
moon build examples/showcase/linux_skia --target native
moon build examples/markdown_editor/macos_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/pdf_workbench/windows_skia --target native
moon build examples/pdf_workbench/linux_skia --target native
moon build examples/markdown_editor/windows_skia --target native
moon build examples/markdown_editor/linux_skia --target native
```

Build native WGPU profiles such as `macos_wgpu`, `windows_wgpu`, and
`linux_wgpu_cosmic` only when explicitly validating the experimental WGPU
diagnostic route.

macOS Skia entrypoints use the renderer's system `FontMgr` path by default.
Tester-owned first-frame smoke runs select `EmptyTypeface`, so app runs and
smoke logs keep distinct text-resolution intent. Use
`scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke`
for a local real-Skia renderer smoke plus tester-owned first-frame checks.
Direct local `moon run` commands use the `moui_skia` prebuild hook
for real Skia; set `MOUI_SKIA_LINK_MODE=dynamic|static|auto` to choose the
library mode. Helper smoke runs can pass `--link-mode dynamic|static|auto` to
override the environment for that invocation.

Native packaging helpers:

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
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
- Use `Program::new` plus `Effect::host_service` for app-level host-service
  bridge work that should appear in diagnostics but does not need runtime-owned
  cancellation. Use `Effect::service_task` for service-like one-shot async tasks
  that should stay active until their first typed dispatch, be canceled when
  replaced by the same key or when the runtime is destroyed, and report
  active/completed/cancelled lifecycle diagnostics with a stable `service` kind.
  Use `Effect::run` for custom structured effect kinds and `Effect::task` for
  custom task descriptor kinds. Give structured effects stable key/label values
  and keep keys unique within the returned batch; custom `Effect::run` and
  `Effect::task` calls should also use stable kind values because replacing an
  active task with the same key but a different kind is reported as a kind
  change in lifecycle diagnostics. `Effect::run` and task effects are reported
  separately from anonymous dispatch in runtime diagnostics; `Effect::dispatch`
  remains available for anonymous one-off runners. When composing child features, lift child follow-up work with
  `Effect::map`; structured descriptors are preserved for parent diagnostics.
- Use the standard `Subscription::timer`,
  `Subscription::animation_tick`, `Subscription::window_event`,
  `Subscription::host_event`, `Subscription::route_event`, and
  `Subscription::service_completion` helpers for common ongoing source kinds
  that need lifecycle reuse and cleanup; use `Subscription::listen` /
  `Subscription::run` when a source needs a custom diagnostic kind. Use
  `Subscription::map` when a parent app embeds a child feature and wants to
  preserve typed message composition and planned/active
  descriptor identity. Give sources stable key/label values because
  subscription plan diagnostics expose planned descriptors before runtime
  reuse/cancel decisions, while active descriptors report sources kept by the
  runtime. Do not retain and reuse old dispatchers after a subscription key
  changes or the runtime is destroyed; stale callbacks are ignored and counted
  in runtime diagnostics.
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
