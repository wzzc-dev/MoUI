---
name: moui-app-development
description: Build and maintain MoUI application packages and examples. Use when working in examples/*/app, app-specific service packages, platform entrypoints such as web_wasm/macos_skia/windows_skia/linux_skia/android_skia/ios_skia, app views built with wzzc-dev/moui/views, model/update/view logic, host-service integration from app code, or app-focused tests and smoke runs.
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
examples/<name>/android_skia/   # experimental embedded-session route
examples/<name>/android_app/    # app-owned APK/JNI/CMake shell when present
examples/<name>/ios_skia/       # experimental embedded-session route
examples/<name>/ios_app/        # app-owned UIKit .app shell when present
```

Default shared app imports:

```moonbit
import {
  "wzzc-dev/moui",
  "wzzc-dev/moui/geometry",
  "wzzc-dev/moui/graphics",
  "wzzc-dev/moui/animation",
  "wzzc-dev/moui/text",
  "wzzc-dev/moui/state",
  "wzzc-dev/moui/views",
}
```

Import only the domain facades an app actually uses. Use `wzzc-dev/moui/core`
only for advanced kernel/diagnostic types not exposed by a domain facade or
`moui/views`; drawing and paint types belong behind `@graphics`, transition
types behind `@animation`, text types behind `@text`, and focus scope types
behind `@state`. Use `wzzc-dev/moui/backend/host` only for host service
protocols. Do not import `runtime`, concrete platform backends, renderer
packages, or `moui_theme` from ordinary apps unless the app is explicitly a
showcase, diagnostic, or design-system preview.

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
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/android_skia --target native
scripts/build-counter-android-apk.sh --fallback-skia
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/ios_skia --target native
scripts/build-counter-ios-app.sh --fallback-skia
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

Before handoff, prefer:

```sh
sh scripts/check.sh --profile daily
```

Run `sh scripts/check.sh --profile theme` for `moui_theme` or
`examples/design_systems`. Use `sh scripts/check.sh --profile platform` for
current-host backend/provider coverage; the shared platform service checks stay
separate from host-specific steps. Run platform smoke only when
the change claims real platform/browser/renderer behavior.
For Android, the fallback APK command only validates packaging/JNI/CMake; a
non-fallback APK plus matching device/emulator smoke is still required for
first-frame or input/lifecycle runtime claims. Use
`scripts/setup-android-sdk.sh --accept-licenses` followed by
`eval "$(scripts/setup-android-sdk.sh --print-env)"` to install and expose the
official SDK/NDK/CMake toolchain when the local machine does not already have
one. The setup helper requires a JDK on `PATH`; the APK builder also uses
`javac` and `keytool`.
For iOS, the fallback `.app` command only validates MoonBit C generation, UIKit
shell compilation, native-stub compilation, bundle layout, and ad-hoc simulator
signing; a non-fallback `.app` plus matching simulator/device smoke is still
required for first-frame or input/lifecycle runtime claims. Use Xcode command
line tools (`xcrun --sdk iphonesimulator clang/clang++`) rather than a checked-in
Xcode project for the current Counter shell.

## Docs

Update `docs/examples.md` when adding examples, changing commands, or changing
which app owns a workflow. Update `docs/app-templates.md` or `docs/tutorials.md`
when a reusable app pattern changes. Run:

```sh
node scripts/sync-website-docs.mjs
```
