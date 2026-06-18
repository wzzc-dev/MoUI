---
name: moui-app-development
description: Build and maintain MoUI application packages and examples. Use when working in examples/*/app, app-specific service packages, platform entrypoints such as web_wasm/macos_skia/windows_skia/linux_skia, app views built with wzzc-dev/moui/views, model/update/view logic, host-service integration from app code, or app-focused tests and smoke runs.
---

# MoUI App Development

Use this skill for app-layer work. Keep app logic platform-neutral by default
and keep platform entrypoints thin.

## Start Here

Read only the smallest useful set:

- `docs/architecture.md` for package roles and target routes.
- `docs/moui-app-package-boundary.md` before adding imports to an app package.
- `docs/development.md` for local commands and preview loops.
- `docs/testing.md` for focused app checks and manual smoke.
- `docs/examples.md` when changing example coverage or commands.

## Package Shape

Shared app package:

```text
examples/<name>/app/
  moon.pkg
  app.mbt
  *_test.mbt or *_wbtest.mbt
```

Platform entrypoints:

```text
examples/<name>/web_wasm/
examples/<name>/macos_skia/
examples/<name>/windows_skia/
examples/<name>/linux_skia/
```

Default shared app imports:

```moonbit
import {
  "wzzc-dev/moui",
  "wzzc-dev/moui/views",
}
```

Use `wzzc-dev/moui/core` only for neutral protocol types not re-exported by the
root facade. Use `wzzc-dev/moui/backend/host` only for host service protocols.
Do not import `runtime`, concrete platform backends, renderer packages, or
`moui_theme` from ordinary apps unless the app is explicitly a showcase,
diagnostic, or design-system preview.

## App Pattern

Prefer a typed TEA shape:

```moonbit
pub struct Model {
  count : Int
}

pub(all) enum Msg {
  Increment
  Decrement
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
  }
}

pub fn view(model : Model) -> @moui.View[Msg] {
  @views.column([
    @views.text("Count: \{model.count}"),
    @views.button("+", on_click=Increment),
  ])
}

pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
```

Use `Program::new` when `update` returns effects. Use `Subscription` for
ongoing model-driven sources. Lift child messages with `View::map` and child
effects with `Effect::map`.

## UI Construction

- Prefer constructors from `@views`: layout, controls, forms, data displays,
  dialogs, sheets, popovers, navigation, and WebView wrappers.
- Keep component-local state explicit through app model fields, bindings, cells,
  or package-owned helper state.
- Add app-specific helper views in the app package before adding framework API.
- Keep display text and workflows in the shared app package. Platform packages
  should wire runtime/backend/renderer only.
- If a missing control API seems generally useful, switch to the framework
  skill and add it to `moui/views` with tests and docs.

## App Services

App-specific services such as PDF adapters, native transports, file import, or
WebView command queues may live in sibling app packages. Treat them as private
to the app unless multiple apps need them.

Rules:

- Do not push app-specific types into `moui/core` or `moui/views`.
- Keep protocol packages small and tested.
- Convert host-service results into app messages at the app boundary.
- Keep service tasks cancelable when using runtime effect helpers.

## Validation

Use the smallest relevant checks while editing:

```sh
moon test examples/<name>/app --target native
moon build examples/<name>/web_wasm --target wasm-gc
moon test moui/views --target native
```

Common examples:

```sh
moon test examples/counter/app --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Before handoff, prefer:

```sh
sh scripts/dev-check.sh
```

Run `sh scripts/dev-check.sh --theme-diagnostics` for `moui_theme` or
`examples/design_systems`. Run platform smoke only when the change claims real
platform/browser/renderer behavior.

## Docs

Update `docs/examples.md` when adding examples, changing commands, or changing
which app owns a workflow. Update `docs/app-templates.md` or `docs/tutorials.md`
when a reusable app pattern changes. Run:

```sh
node scripts/sync-website-docs.mjs
```
