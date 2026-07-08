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

## Counter Simulator App

Build the experimental Counter iOS Simulator app from the repository root:

```sh
scripts/build-counter-ios-app.sh
```

The default output is:

```text
artifacts/ios/counter/MoUICounter.app
```

Useful options:

```sh
scripts/build-counter-ios-app.sh --arch x86_64
scripts/build-counter-ios-app.sh --deployment-target 15.0
scripts/build-counter-ios-app.sh --sdk iphoneos --arch arm64
```

`--sdk iphoneos` only builds an unsigned device bundle. Real-device install
still requires provisioning and signing, which is outside the first iOS
scaffold.

For packaging-only smoke, use:

```sh
scripts/build-counter-ios-app.sh --fallback-skia
```

`--fallback-skia` validates MoonBit C generation, UIKit shell compilation,
runtime compatibility, native-stub compilation, bundle layout, and ad-hoc
simulator signing. It reports native Skia unavailable and must not be used as
first-frame runtime evidence.

## Simulator Smoke

After building the non-fallback app, install and launch it in a booted
simulator:

```sh
xcrun simctl install booted artifacts/ios/counter/MoUICounter.app
xcrun simctl launch booted dev.wzzc.moui.counter
```

Record screenshot and log evidence before promoting any runtime claim.

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
