# iOS Support

iOS support is currently an experimental embedded native route. The shared
UIKit shell supplies a raw `UIView` handle, drives frames with `CADisplayLink`,
and forwards lifecycle, resize, touch, IME, pasteboard, and accessibility
traffic into MoUI.

## Status

Three evidence layers stay separate: **product GPU default** (source/`auto`),
**mobile runtime smoke** (`artifacts/mobile-runtime/...`), and **seven-gate GPU
promotion claim** (`gpuPromotionEvidence` / `artifacts/gpu-promotion/...`).

| Area | Current state | Evidence boundary |
| --- | --- | --- |
| Host contract | Scaffolded in `moui/backend/ios` | Package tests prove protocol behavior only. |
| Platform services | UIKit text proxy, text/image `UIPasteboard`, and `UIAccessibilityElement` container are wired through `MobileHostChannel` | Full composition/candidate, cross-app PNG, and VoiceOver tree/focus/action evidence pending. |
| Frame pacing | Input/resize request redraw; presentation runs from `CADisplayLink` ticks | 60/120 Hz device pacing evidence pending. |
| Skia provider | Scaffolded in `moui/backend/ios/skia` | Provider/preflight checks prove wiring, not simulator/device pixels. |
| Product GPU default | `auto` → `SkiaGpuNative` / `metal-gpu` when available (`gpu_promoted=true`) | Source + rebuild `mobile-build.json`; not a seven-gate claim. |
| UIKit app shell | `examples/counter/ios_app` / Component Gallery + `scripts/build-mobile-ios-app.sh` | Packaging evidence; fallback `.app` is not runtime proof. |
| First-frame runtime evidence | Nonblank screenshots: `resource/screenshots/ios-componentgallery.png` (2026-07-09) and simulator smokes below | First-frame pixels proven. |
| Runtime smoke (simulator, 2026-07-15 re-verify) | Component Gallery **`status=passed`** at `artifacts/mobile-runtime/ios/component_gallery/` (`--require-passed` ok) | Lifecycle, nonblank first frame, resize, input/scroll, IME, clipboard write/read, a11y tree/focus/action, async-image, clean shutdown; shell-side service smoke + broader background detach hooks. Metal GPU configure with pending seven-gate skeleton (`claimed=false`). `realDeviceSigning` pending on Simulator. Re-run via `scripts/ios-mobile-runtime-evidence.sh`. |
| GPU promotion claim | Scaffold only: `artifacts/gpu-promotion/ios/scaffold-latest/` (`gpuPromoted=false`) | No matching-device seven-gate claim; product default already on. Runtime smoke pass ≠ seven-gate promotion claim. |
| Runtime support claim | **Simulator service smoke passed** (Component Gallery) | Physical-device signing + live device VoiceOver matrix still pending for release-device claims. |

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
  controller, layout, display link, text proxy, pasteboard/accessibility
  adapters, touch forwarding, runtime compatibility shim,
  MoonBit-generated C, MoonBit runtime, iOS presenter, and `moui_skia/native`
  stubs.

iOS 15 remains the deployment floor. Product `auto` prefers the Metal
`CAMetalLayer` / worker-owned GPU path when available; the raster compatibility
path still presents via `NSData -> CGImage -> UIImage -> UIImageView` for
explicit `skia-raster` and sticky recovery fallback.

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
scripts/build-mobile-ios-app.sh --app counter --renderer auto
```

The allowed renderer modes are `auto`, `skia-gpu`, and `skia-raster`.
Generated build metadata and startup logs record requested and selected modes.
For real Skia packages, `auto` and `skia-gpu` select GPU; fallback-Skia builds
and explicit `skia-raster` stay on the CPU presenter.

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

Keep the template's empty `UILaunchScreen` dictionary. Without a modern launch
screen declaration, iOS may run the app in legacy `320x480` compatibility mode,
which letterboxes presentation and changes touch-coordinate mapping.

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

The iOS recorder uses Meta `idb` because stock Apple `simctl` has no tap or
swipe subcommand. Install the client and companion before running iOS smoke:

```sh
brew tap facebook/fb
brew trust --formula facebook/fb/idb-companion
brew install idb-companion
pipx install fb-idb
```

The recorder connects the companion, waits for a non-empty accessibility tree,
selects the first enabled button with a valid frame, taps its center, and sends
a real HOME event for lifecycle detach. Input passes only when the current
launched PID logs pointer receipt and the before/after pixels change.

Component Gallery opens `Mobile Service Probe` directly on iOS. The recorder
finds `Service probe text` and `Activate service probe` by accessibility label,
uses `idb ui text`, drives the native Select/Copy/Paste menu, seeds and reads the
Simulator pasteboard with `simctl pbcopy`/`pbpaste`, scrolls the page, and waits
for deferred-image loading/ready logs. Add `--assistive-tech` only when a live
VoiceOver session is available.

Xcode 26.3 does not expose rotation through `simctl io`; the recorder uses the
Simulator Device menu through `osascript`. macOS must grant Accessibility
permission to that automation process. Without it the app cannot produce a
second surface size, so `resize` remains `no`. A preference write that does not
activate VoiceOver does not satisfy accessibility focus/action evidence.

The 2026-07-14 local iPhone 17 Pro Simulator Component Gallery smoke is
schema-valid **`status=passed`** at
`artifacts/mobile-runtime/ios/component_gallery/mobile-runtime-smoke.json`
(validated with `--require-passed`).

It records lifecycle attach/detach, nonblank first frame, resize, representative
input + scroll, IME, clipboard write/read, accessibility tree/focus/action,
async-image loading/ready, clean shutdown, and Metal GPU configure
(`SkiaGpuNative` / `metal-gpu` / `gpuPromoted=true`) with a **pending** seven-gate
skeleton (`gpuPromotionEvidence.claimed=false`). Simulator `realDeviceSigning`
stays `pending`.

Recorder improvements that made this pass possible:

- continuous `log stream` (so attach/IME/clipboard are not drowned by scroll)
- service-probe-first idb planning
- deterministic `MOUI_MOBILE_A11Y_SMOKE=1` focus/activate once-fire on the iOS shell
- seven-gate thresholds only enforced when a promotion claim is asserted

## Physical Device Acceptance

Build the device artifact first:

```sh
scripts/build-mobile-ios-app.sh \
  --app component_gallery --sdk iphoneos --arch arm64
```

The current builder intentionally emits an unsigned bundle. Provision and sign
it with the app's real team/profile before install, then run the same probe on
the device with VoiceOver enabled and collect app logs/screenshots. Acceptance
requires Chinese composition and emoji/ZWJ editing, system text and PNG
clipboard round trips, VoiceOver tree/focus/activate, portrait-landscape-
portrait resize, async-image loading/ready, background detach, and clean
relaunch. Record `realDeviceSigning=yes` only from that signed installed run.

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
