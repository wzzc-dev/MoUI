# iOS Support

iOS uses the **embedded runtime backend** route and is currently
`runtime_partial`. `wzzc-dev/window/ios` owns UIKit lifecycle, surface, and
input callbacks; `moui/backend/ios` assembles the MoUI runtime session and
`moui/backend/ios/skia` provides presentation.

## Entry Points

| Piece | Location |
|---|---|
| App logic | `examples/<app>/app` |
| Mobile metadata | `examples/<app>/moui.mobile.json` |
| MoonBit entrypoint | `examples/<app>/ios_window_hosted` |
| iOS host template | `wzzc-dev/window/ios/template` |
| MoUI embedded runtime backend | `moui/backend/ios/window_hosted.mbt` |

The entrypoint constructs `IosEmbeddedRuntimeBackend` and calls
`window/ios::EventLoop.run_app`. UIKit must feed lifecycle, surface, and touch
events through this path only.

## Toolchain

- Xcode 15.4 or newer
- Swift 5 or newer
- iOS deployment target 15.0 or newer
- `UILaunchScreen` and `UIApplicationSupportsMultipleScenes=false` remain in
  the template Info.plist

## Xcode And Simulator Setup

Install Xcode from Apple, select the active developer directory, and verify the
Simulator SDK before building:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

Create or select a simulator in Xcode's Devices and Simulators window, then
boot it before running an app. Use its UDID rather than assuming a device name.

```sh
xcrun simctl list devices available
xcrun simctl boot <simulator-udid>
xcrun simctl bootstatus <simulator-udid> -b
open -a Simulator
```

Run `moui doctor --platform ios` before a native build.

## Build And Run

```sh
moon check examples/showcase/ios_window_hosted --target native
moui build ios showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui run ios showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```

`--prepare-only` stops after input generation. `--fallback-skia` is useful for
packaging diagnostics only and cannot promote iOS runtime readiness.

## Validation And Evidence

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/ios --target native
```

Simulator or device evidence must cover first frame, touch/input, surface
detach/recreate, IME, clipboard, accessibility, and async-image behavior.
Update `checks/platforms/ios.json` only when the actual presenter route is
verified by matching-host evidence.

## Status

The route is available for development and template integration, but remains
`runtime_partial`. See `docs/platform-readiness-declaration.md` and
`docs/window-hosted-moui.md` for the promotion criteria.
