# iOS Support

iOS support is currently an experimental embedded native scaffold. It mirrors
the Android route: MoUI does not own a UIKit application loop yet. The UIKit
layer supplies a raw `UIView` handle and forwards lifecycle, resize, touch, and
redraw callbacks into MoUI.

## Packages

- `moui/backend/ios` owns the iOS host contract: `IosViewHandle`,
  `IosRendererProvider`, capability/readiness summaries, and
  `IosRuntimeSession`.
- `moui/backend/ios/skia` owns the iOS Skia provider. It wraps
  `moui/render/skia` in a `HostWindowRenderer` and presents RGBA frames to a
  UIKit `UIImageView` child when compiled for iOS or iOS Simulator.
- `examples/counter/ios_skia` is a thin Counter MoonBit entrypoint for native
  app-shell wiring. Its exported attach/resize/pointer/render/detach functions
  are small so a UIKit shell can own `UIApplicationDelegate` and
  `UIViewController` lifecycle.
- `examples/counter/ios_app` is the experimental Counter UIKit shell. It owns
  the app delegate, view controller, layout, touch forwarding, and a small iOS
  runtime compatibility shim while the build script compiles the
  MoonBit-generated C, MoonBit runtime, iOS presenter, and `moui_skia/native`
  stubs into one simulator app executable.

## Skia Prebuild

Use explicit Skia prebuild variables when cross-building the native route:

```sh
MOUI_SKIA_PLATFORM=iosSim \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=static \
moon check examples/counter/ios_skia --target native
```

`MOUI_SKIA_PLATFORM=iosSim` selects the iOS Simulator asset from
`moui_skia/skia-provider-lock.json`; use `ios` for device builds.
`MOUI_SKIA_ARCH` accepts `arm64` or `x64` for the locked simulator artifacts.
The Counter app script defaults to static Skia because simulator `.app` bundles
do not need to package a separate `libskia.dylib` in the first scaffold.

## Xcode Command Line Tools

The direct iOS builder uses Xcode command-line tools, not a checked-in Xcode
project. Install Xcode from the Mac App Store or Apple Developer downloads,
then select it:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

No repository-private SDK directory is required. `scripts/build-counter-ios-app.sh`
uses `xcrun --sdk <sdk> clang/clang++` and the selected SDK path.

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
still requires a provisioning and signing flow, which is outside the first iOS
scaffold.

Use this fast smoke when you only need to validate MoonBit C generation, UIKit
shell compilation, runtime compatibility, native-stub compilation, bundle
layout, and ad-hoc simulator signing without downloading or linking real Skia:

```sh
scripts/build-counter-ios-app.sh --fallback-skia
```

`--fallback-skia` can produce a `.app`, but that app is packaging evidence
only: the native Skia renderer reports unavailable and it should not be used as
first-frame runtime evidence.

## Simulator Smoke

After building the non-fallback app, install and launch it in a booted
simulator:

```sh
xcrun simctl install booted artifacts/ios/counter/MoUICounter.app
xcrun simctl launch booted dev.wzzc.moui.counter
```

Record screenshot and log evidence before promoting any runtime claim. A passed
iOS claim still needs a matching simulator or device smoke that proves at
least:

- UIKit lifecycle creates and disposes an `IosRuntimeSession`.
- UIKit `UIView` presentation shows a nonblank first frame.
- Resize and touch callbacks reach `HostRuntimeDriver`.
- Text input/IME, clipboard, accessibility, async image, real-device signing,
  and packaging gaps are either implemented or explicitly recorded as pending.

Until those observations exist, iOS should be described as an experimental
scaffold, not as a passed platform.
