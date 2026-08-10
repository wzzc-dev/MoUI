---
name: moui-app-development
description: Build and maintain MoUI application packages and examples. Use when working in examples/*/app, app-specific service packages, platform entrypoints such as web_wasm/macos_skia/windows_skia/linux_skia/android_window_hosted/ios_window_hosted/harmonyos_window_hosted, app views built with wzzc-dev/moui/views, model/update/view logic, host-service integration from app code, or app-focused tests and smoke runs.
---

# MoUI App Development

Use this skill for app-layer work. Keep app logic platform-neutral by default
and keep platform entrypoints thin.

## Start Here

### First 10 minutes (standalone app)

```sh
moon install wzzc-dev/moui_cli/cmd/moui
moui new my_app                 # or: moui new my_app --template hello
cd my_app && moon update
moon run macos_skia --target native   # or windows_skia / linux_skia
```

See `docs/getting-started.md` section B. Do not clone the monorepo for ordinary
app work. For host Effect/Subscription recipes, open `examples/showcase/app/platform`
and `docs/non-render-component-cookbook.md`.

Read only the smallest useful set:

- `docs/architecture.md` for package roles and target routes.
- `docs/moui-app-package-boundary.md` before adding imports to an app package.
- `docs/development.md` for local commands and preview loops.
- `docs/testing.md` for focused app checks and manual smoke.
- `docs/examples.md` when changing example coverage or commands.
- `docs/canvas-and-custom-paint.md` for canvas / custom paint.

Ordinary app and example work should use the published `wzzc-dev/window`
dependency resolved from mooncakes.io. Do not add local `./window/modules/window*`
members to `moon.work` for
app fixes; if a task truly requires editing window source locally, switch to the
framework skill and follow the `window` local-source workflow in
`docs/development.md`.

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
examples/<name>/android_window_hosted/
examples/<name>/ios_window_hosted/
examples/<name>/harmonyos_window_hosted/
```

Mobile entrypoints use `wzzc-dev/window`; its platform template owns lifecycle,
surface, and input callbacks. App code remains in `examples/<name>/app`.

The Moon wasm linker exports executable-owned definitions, not `pub using`
aliases. Keep Web/WeChat `abi.mbt` as the only permitted second production file:
it contains the fixed direct backend delegations enforced by P1 and no app or
platform logic.

Showcase uses the standard `web_wasm`, `<platform>_skia`, and explicit
renderer-diagnostic entrypoint names. Its embedded-runtime routes use the matching
`*_window_hosted` entrypoint.

Linux RISC-V64 is the `linux-skia-riscv64` architecture variant of the existing
`examples/showcase/linux_skia` composition root. Do not add a RISC-V-specific
app package or entrypoint; cross-build and QEMU evidence belong to the framework
helper documented in `docs/platform-notes-linux.md`.

Default shared app imports:

```moonbit
import {
  "wzzc-dev/moui",
  "wzzc-dev/moui/geometry",
  "wzzc-dev/moui/graphics",
  "wzzc-dev/moui/animation",
  "wzzc-dev/moui/text",
  "wzzc-dev/moui/state",
  "wzzc-dev/moui/services",
  "wzzc-dev/moui/views",
}
```

Import only the domain facades an app actually uses. Use `wzzc-dev/moui/core`
only for advanced kernel/diagnostic types not exposed by a domain facade or
`moui/views`; drawing and paint types belong behind `@graphics`, transition
types behind `@animation`, text types behind `@text`, and focus scope types
behind `@state`. Use `wzzc-dev/moui/services` for files, clipboard, URLs,
settings, menus, timers, and routes. Production app imports must not include
`runtime`, `backend`, concrete platform backends, or renderer packages.
Design-system preview apps may depend on `moui_theme`; Showcase runtime/render
inspection belongs in its module-root integration package and passes neutral
DTOs into the app.

Executable composition roots depend on `wzzc-dev/moui` plus exactly the
selected renderer publication module (`moui_skia_renderer`,
`moui_web_renderer`, `moui_wgpu_renderer`, or `moui_sun_renderer`). Keep these
module dependencies out of the shared `examples/<name>/app` package.

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

Business models contain plain data. Capture `AppEnvironment` in the Program
closure, convert `ServiceTaskResult`, timer ticks, routes, shortcuts, system
menus, and context-menu actions to `Msg`, and declare typed shortcuts with
`Program::with_commands`. Keep `State`/`Cell`/`ScrollState` for local rich-text,
focus, and scroll transients only.

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
- Use typed `ServiceTask[T]` and keep host request ids, bridges, and queues out
  of app code and Model data.

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
moon check examples/showcase/android_window_hosted --target native
moon check examples/showcase/ios_window_hosted --target native
moon test examples/harmonyos_demo/app --target native
moon check examples/showcase/harmonyos_window_hosted --target native
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/pdf_workbench/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
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
Mobile apps use `moui.mobile.json` and one `*_window_hosted` package per target.
Build through `moui build <android|ios|harmonyos> <app> --mobile-config <path>`;
the matching `wzzc-dev/window` template is the only lifecycle, surface, and
input owner. `--fallback-skia` proves packaging only. Record matching-device
before/after pixel change, input, detach, IME, clipboard, accessibility, and
async-image evidence before changing the corresponding `checks/platforms/*.json`
status. See
`docs/window-hosted-moui.md` and the platform support page for toolchain setup.

## Docs

Update `docs/examples.md` when adding examples, changing commands, or changing
which app owns a workflow. Update `docs/app-templates.md` or `docs/tutorials.md`
when a reusable app pattern changes. Run:

```sh
node scripts/sync-website-docs.mjs
```

For Web apps, keep large runtime resources out of MoonBit source. Put large
images, Markdown, JSON, and fixtures under the Web entrypoint's `assets/`
directory, reference them with relative URLs, and use
`scripts/package-web-app.mjs <web-package> --out <dir>` for release-style output
with copied assets plus gzip/brotli siblings.
