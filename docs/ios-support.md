# iOS Support

iOS support is currently an experimental embedded native scaffold. MoUI does
not own a UIKit application loop yet. The UIKit layer owns the app shell,
supplies a raw `UIView` handle, and forwards lifecycle, resize, touch, and
redraw callbacks into MoUI.

## Status

| Area | Current state | Evidence boundary |
| --- | --- | --- |
| Host contract | Scaffolded in `moui/backend/ios` | Package tests prove protocol behavior only. |
| Skia provider | Scaffolded in `moui/backend/ios/skia` | Provider/preflight checks prove wiring, not simulator/device pixels. |
| Counter entrypoint | `examples/counter/ios_skia` exports thin native hooks | Compile/check evidence only. |
| UIKit app shell | `examples/counter/ios_app` plus `scripts/build-counter-ios-app.sh` | Packaging evidence; fallback `.app` is not runtime proof. |
| Runtime support claim | Pending | Requires a non-fallback app plus matching simulator/device smoke. |

## Ownership

- `moui/backend/ios` owns `IosViewHandle`, `IosRendererProvider`, readiness
  summaries, and `IosRuntimeSession`.
- `moui/backend/ios/skia` wraps `moui/render/skia` in a `HostWindowRenderer`
  and presents copied RGBA frames to a UIKit `UIImageView` child when compiled
  for iOS or iOS Simulator.
- `examples/counter/ios_skia` is the thin MoonBit entrypoint for native
  app-shell wiring. Its attach/resize/pointer/render/detach exports stay small
  so a UIKit shell can own `UIApplicationDelegate` and `UIViewController`
  lifecycle.
- `examples/counter/ios_app` owns the experimental app delegate, view
  controller, layout, touch forwarding, runtime compatibility shim,
  MoonBit-generated C, MoonBit runtime, iOS presenter, and `moui_skia/native`
  stubs.

## Focused Checks

Use fallback-safe checks for routine scaffold work:

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/ios --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/ios/skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/ios_skia --target native
scripts/build-counter-ios-app.sh --fallback-skia
```

These checks are useful before handoff, but none of them prove iOS runtime
presentation.

## Skia Cross-Build

Use explicit Skia prebuild variables when cross-building the real native route:

```sh
MOUI_SKIA_PLATFORM=iosSim \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=static \
moon check examples/counter/ios_skia --target native
```

`MOUI_SKIA_PLATFORM=iosSim` selects the iOS Simulator asset from
`moui_skia/skia-provider-lock.json`; use `ios` for device builds.
`MOUI_SKIA_ARCH` accepts `arm64` or `x64` for the locked simulator artifacts.
The Counter app script defaults to static Skia because the first simulator app
scaffold does not need to package a separate `libskia.dylib`.

## Xcode Setup

The direct iOS builder uses Xcode command-line tools, not a checked-in Xcode
project. Install Xcode from the Mac App Store or Apple Developer downloads,
then select it:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

No repository-private SDK directory is required.
`scripts/build-counter-ios-app.sh` uses `xcrun --sdk <sdk> clang/clang++` and
the selected SDK path.

## Mobile Xcode Builds

iOS builds now use minimal Xcode projects as the primary entrypoint. The
repository examples keep checked-in legacy targets under `examples/*/ios_app`;
the reusable UIKit shell, native build script, copyable Xcode template, and
compatibility contracts live under the package-published `moui/mobile` and
`moui/scripts/mobile` directories. The builder consumes app-facing metadata
from `examples/<app>/mobile.json` for repository examples, or the external
app's own `mobile.json`, then generates MoonBit C plus Skia response files,
compiles the shared UIKit shell, and writes a Simulator `.app` bundle.

Build the experimental Counter iOS Simulator app from the repository root:

```sh
scripts/build-mobile-ios-app.sh --app counter
```

Build Component Gallery with the same route:

```sh
scripts/build-mobile-ios-app.sh --app component_gallery
```

The default output is:

```text
artifacts/ios/counter/MoUICounter.app
artifacts/ios/component_gallery/ComponentGallery.app
```

Useful options:

```sh
scripts/build-mobile-ios-app.sh --app counter --arch x86_64
scripts/build-mobile-ios-app.sh --app counter --deployment-target 15.0
scripts/build-mobile-ios-app.sh --app counter --sdk iphoneos --arch arm64
```

`--sdk iphoneos` only builds an unsigned device bundle. Real-device install
still requires provisioning and signing, which is outside the first iOS
scaffold.

For packaging-only smoke, use:

```sh
scripts/build-counter-ios-app.sh --fallback-skia
scripts/build-component-gallery-ios-app.sh --fallback-skia
```

`--fallback-skia` validates MoonBit C generation, UIKit shell compilation,
runtime compatibility, native-stub compilation, bundle layout, and ad-hoc
simulator signing. It reports native Skia unavailable and must not be used as
first-frame runtime evidence.

The old app-specific build scripts remain compatibility wrappers over
`scripts/build-mobile-ios-app.sh --app ...`.

For an external app, copy `moui/mobile/ios/template` to `ios_app`, copy
`moui/mobile/template.mobile.json` to `mobile.json`, fill in the bundle id,
Info.plist, and `ios.native` export contract, then run the package-published
script from the app workspace:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --xcode-project "$PWD/ios_app/MoUIMobileApp.xcodeproj" \
  --scheme MoUIMobileApp \
  --product-name MoUIMobileApp
```

## Simulator Smoke

After building the non-fallback app, install and launch it in a booted
simulator:

```sh
xcrun simctl install booted artifacts/ios/counter/MoUICounter.app
xcrun simctl launch booted dev.wzzc.moui.counter
```

Record screenshot and log evidence before promoting any runtime claim. The
catalog-backed recorder automates the local evidence shape:

```sh
node scripts/record-mobile-runtime-smoke.mjs --platform ios --app counter --require-passed
node scripts/record-mobile-runtime-smoke.mjs --platform ios --app component_gallery --require-passed
```

## Runtime Evidence Required

A passed iOS runtime claim requires a non-fallback simulator/device app plus
matching evidence for at least:

- UIKit lifecycle creating and disposing an `IosRuntimeSession`.
- UIKit `UIView` presentation with nonblank first-frame pixels.
- Resize and touch callbacks reaching `HostRuntimeDriver`.
- Text input/IME observations or explicit pending status.
- Clipboard, accessibility, async image, real-device signing, and packaging
  observations or explicit pending status.

Until those observations exist, describe iOS as an experimental embedded
scaffold, not as a passed platform.
