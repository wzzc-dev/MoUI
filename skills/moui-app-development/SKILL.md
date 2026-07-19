---
name: moui-app-development
description: Build and maintain MoUI application packages and examples. Use when working in examples/*/app, app-specific service packages, platform entrypoints such as web_wasm/macos_skia/windows_skia/linux_skia/android_skia/ios_skia/harmonyos_skia, app views built with wzzc-dev/moui/views, model/update/view logic, host-service integration from app code, or app-focused tests and smoke runs.
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
dependency resolved from mooncakes.io. Do not add `./window` to `moon.work` for
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
examples/<name>/android_skia/   # experimental embedded-session route
examples/<name>/ios_skia/       # experimental embedded-session route
examples/<name>/harmonyos_skia/ # experimental embedded-session route
```

Standard examples stage managed native projects from `moui_shell`. App-owned
native projects are explicit `moui shell eject` outputs rather than checked-in
example fixtures.

Showcase uses the standard `web_wasm`, `<platform>_skia`, and explicit
renderer-diagnostic entrypoint names. Its mobile entrypoints open the Platform
workspace's Mobile Service Probe route.

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
scripts/build-shell-android-apk.sh --app counter --fallback-skia
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/ios_skia --target native
scripts/build-shell-ios-app.sh --app counter --fallback-skia
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/harmonyos_demo/harmonyos_skia --target native
scripts/build-shell-harmonyos-hap.sh --app harmonyos_demo --fallback-skia
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
For Android, the canonical build command is
`scripts/build-shell-android-apk.sh --app <counter|showcase>`. The default is the
package-owned Kotlin/AndroidX managed shell with registered JNI and a native
PlatformView overlay. The fallback APK command only validates packaging/JNI/CMake; a
non-fallback APK plus matching device/emulator smoke is still required for
first-frame or input/lifecycle runtime claims. Use
`--renderer auto|skia-gpu|skia-raster` to record the requested and selected
mobile renderer. Real Skia packages use the GPU route for `auto` and
`skia-gpu`; fallback-Skia builds, explicit `skia-raster`, and sticky terminal
recovery use the raster route. Use
`scripts/setup-android-sdk.sh --accept-licenses` followed by
`eval "$(scripts/setup-android-sdk.sh --print-env)"` to install and expose the
official SDK/NDK/CMake toolchain when the local machine does not already have
one. The setup helper requires a JDK on `PATH`; the APK builder also uses
`javac`, `jlink`, and `keytool`. Use Java 17 or newer for Android Gradle Plugin
9.x; Java 21 is the recommended local default. Install compile SDK 36 for
AndroidX Activity 1.13.0; the product target remains SDK 35 and minSdk 23.
For iOS, the canonical build command is
`scripts/build-shell-ios-app.sh --app <counter|showcase>` through a
staged canonical Xcode project. The fallback `.app` command only validates MoonBit C
generation, canonical SwiftUI/UIKit adapter and ABI bridge compilation,
native-stub compilation, bundle layout, and ad-hoc simulator signing; a
non-fallback `.app` plus matching
simulator/device smoke is still required for first-frame or input/lifecycle
runtime claims.
The managed route requires Xcode 15.4+, Swift 5, iOS 15+, and one active scene.
Keep the iOS template's `UILaunchScreen` entry to avoid legacy `320x480`
compatibility mode. iOS Simulator smoke requires `idb`/`idb-companion`; stock
`simctl` does not inject tap/swipe events. The recorder chooses a control from
the accessibility tree and filters receipt logs by the current launch PID.
The iOS and HarmonyOS mobile build entrypoints use the same `--renderer`
contract and evidence boundary.
Repository example mobile metadata lives in `examples/<app>/shell.json`.
Reusable canonical shells and scripts live in the published `moui_shell`
directories. Applications use schema v1 `shell.json` with the fixed Embedding
API v1 and must not put native symbols or project paths in configuration. Run
`node scripts/check-shell-app-config.mjs` after changing repository example
shell metadata.
For HarmonyOS, the fallback HAP command only validates MoonBit C generation,
the package-owned ArkTS Stage Ability/XComponent managed shell, native glue
compilation, native-stub compilation, and staged package layout; a
non-fallback HAP plus matching device/emulator smoke is still required for
first-frame or input/lifecycle runtime claims. Use `HARMONYOS_SDK_HOME` as the
canonical SDK environment variable, with `OHOS_SDK_HOME` accepted as fallback.
Use `node scripts/record-shell-runtime-smoke.mjs --platform
<android|ios|harmonyos> --app <id> --require-passed` for release evidence.
Successful input injection is insufficient: the recorder requires app receipt,
before/after pixel change, actual detach, IME state/edit, clipboard completion,
accessibility tree/focus/action, and async image. HarmonyOS uses API 20 and
native XComponent as the only input/lifecycle source.
Use Showcase Platform's dedicated `Mobile Service Probe` for mobile service
acceptance. Clipboard evidence requires system text write and read completion;
resize evidence requires two distinct physical sizes; async-image evidence
requires loading and ready frames. Assistive-technology focus/action must come
from a live TalkBack, VoiceOver, or HarmonyOS screen-reader session.
Shell runtime manifests use `passed`, `partial`, and `failed`: incomplete but
useful matching-host evidence is `partial`, while `--require-passed` accepts
only complete `passed` evidence.

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
