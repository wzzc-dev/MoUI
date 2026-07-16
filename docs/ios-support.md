# iOS Support

iOS is a **runtime_partial** embedded native route: the managed shell and host
session are **usable for development and demos** (`backend` reports
`ready=true`, `status=runtime_partial`), but the platform is **not**
product-complete until managed SwiftUI matching-simulator L3 and
presenter/GPU promotion close remaining gaps.

The canonical shell is a package-owned SwiftUI `App` with a
`UIViewRepresentable` host. Its render view explicitly uses `CAMetalLayer`,
drives frames with `CADisplayLink`, and forwards lifecycle, resize, touch, IME,
pasteboard, accessibility, PlatformView, and Host Service traffic into MoUI. A
narrow Objective-C++ bridge only negotiates Mobile Runtime ABI v1, dispatches
its function table, and owns copied boundary data.

## Status

Three evidence layers stay separate: **product GPU default** (source/`auto`),
**mobile runtime smoke** (`artifacts/mobile-runtime/...`), and **seven-gate GPU
promotion claim** (`gpuPromotionEvidence` / `artifacts/gpu-promotion/...`).

| Area | Current state | Evidence boundary |
| --- | --- | --- |
| Product class | `runtime_partial` (see platform-readiness-declaration) | Not `committed`; not “Counter-only scaffold.” |
| Host contract | Usable embedded session in `moui/backend/ios` (`ready=true`) | Package tests + managed shell wiring; L3 promotion separate. |
| Platform services | Swift adapters own text proxy, pasteboard, a11y container, PlatformView, Host Service channels over `MobileHostChannel` | Capability flags reflect **code wiring**; full managed-shell VoiceOver/device evidence still pending. |
| Frame pacing | Input/resize request redraw; presentation runs from `CADisplayLink` ticks | 60/120 Hz device pacing evidence pending. |
| Skia provider | `moui/backend/ios/skia` preflight `runtime_status=runtime_partial` | Provider checks prove wiring; presenter route still unverified in checks JSON. |
| Product GPU default | `auto` → `SkiaGpuNative` / `metal-gpu` when available (`gpu_promoted=true`) | Source + rebuild `mobile-build.json`; not a seven-gate claim. |
| Canonical SwiftUI shell | `moui/mobile/ios` + real `PBXNativeTarget` in the framework-staged template | Managed fallback builds prove Swift/ObjC++/ABI/native packaging only; they are not runtime proof. |
| First-frame runtime evidence | Nonblank screenshots and the simulator smoke below were collected against the Release N UIKit shell | Historical pixels remain valid for that artifact, not for the replacement managed shell. |
| Runtime smoke (simulator, 2026-07-15 re-verify) | Component Gallery **`status=passed`** under the frozen UIKit shell at `artifacts/mobile-runtime/ios/component_gallery/` | Managed SwiftUI lifecycle, pixels, input, IME, clipboard, accessibility, PlatformView, and async-image evidence must be recollected without a production-shell smoke probe. |
| GPU promotion claim | Scaffold only: `artifacts/gpu-promotion/ios/scaffold-latest/` (`gpuPromoted=false`) | No matching-device seven-gate claim; product default already on. Runtime smoke pass ≠ seven-gate promotion claim. |
| Runtime support claim | Release N UIKit simulator service smoke passed; canonical SwiftUI runtime claim pending | Re-run the managed shell on Simulator, then add physical-device signing and live VoiceOver evidence. |

## Ownership

- `moui/backend/ios` owns `IosViewHandle`, `IosRendererProvider`, readiness
  summaries, and `IosRuntimeSession`.
- `moui/backend/ios/skia` wraps `moui/render/skia` in a `HostWindowRenderer`
  and presents copied RGBA frames to a UIKit `UIImageView` child when compiled
  for iOS or iOS Simulator.
- `examples/counter/ios_skia` and `examples/component_gallery/ios` are thin
  MoonBit entrypoints. Schema v2 builds expose the fixed Mobile Runtime ABI v1
  symbols; app-specific symbol maps are confined to the Release N legacy path.
- `moui/mobile/ios` owns the canonical Swift package, SwiftUI scene lifecycle,
  `CAMetalLayer` view, display link, UIKit host adapters, plugin registry, ABI
  bridge, and canonical Xcode template.
- `examples/*/ios_app` are repository-only native target fixtures. Normal
  managed applications keep identity in `mobile.json` and do not own an Xcode
  project.
- `moui/mobile/ios/legacy/moui_mobile_app.mm` is the frozen Release N
  UIKit/Objective-C++ compatibility fixture and is selected only by
  `--legacy-uikit-shell`.

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
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/component_gallery/ios --target native
sh moui/mobile/ios/tests/run-ios-managed-shell-tests.sh
scripts/build-mobile-ios-app.sh --app counter --fallback-skia
scripts/build-mobile-ios-app.sh --app component_gallery --fallback-skia
scripts/build-mobile-ios-app.sh --app counter --fallback-skia --legacy-uikit-shell
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

The managed shell requires Xcode 15.4 or newer. The package builder stages its
canonical real `PBXNativeTarget` under the artifact directory; that target's
build phase invokes the core builder and writes the complete executable bundle.
Install Xcode from the Mac App Store or Apple Developer downloads, then select
it:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

No repository-private SDK directory is required. The core builder uses
`xcrun --sdk <sdk>` to select Clang, Swift, and the SDK path, compiles in Swift
5 language mode, and enforces the iOS 15 deployment floor.

## Mobile Xcode Builds

iOS builds use a package-owned minimal `PBXNativeTarget` as the primary
entrypoint. Applications do not keep a managed Xcode project in their source
tree.
The reusable SwiftUI shell, native build script, canonical Xcode template, and
compatibility contracts live under the package-published `moui/mobile` and
`moui/scripts/mobile` directories. The builder consumes app-facing metadata
from `examples/<app>/mobile.json` for repository examples, or the external
app's own `mobile.json`, then generates MoonBit C plus Skia response files,
compiles the ABI adapter, narrow Objective-C++ bridge, Swift package module,
generated app configuration, and plugin sources, then writes a Simulator
`.app` bundle.

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

`--fallback-skia` validates MoonBit C generation, SwiftUI/UIKit host-adapter
and ABI bridge compilation, runtime compatibility, native-stub compilation,
bundle layout, and ad-hoc simulator signing. It reports native Skia unavailable
and must not be used as first-frame runtime evidence.

The managed SwiftUI shell is the default. Use
`--legacy-uikit-shell` only to build the frozen Release N fixture. The output
bundle records the selected route in `MOUIShellMode`.

The old app-specific build scripts remain compatibility wrappers over
`scripts/build-mobile-ios-app.sh --app ...`.

For an external schema v2 app, keep only `mobile.json`, resources, plugins, and
the MoonBit mobile entrypoint in the application workspace. The
package-published script stages the canonical Xcode project automatically:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-ios-app.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json"
```

Use `moui mobile eject ios --output <dir>` only when the app needs to own and
version the native project. `--xcode-project` is reserved for repository
fixtures and ejected shells; it is not required by the managed path.

Keep the template's empty `UILaunchScreen` dictionary. Without a modern launch
screen declaration, iOS may run the app in legacy `320x480` compatibility mode,
which letterboxes presentation and changes touch-coordinate mapping.

## Scene And Extension Contract

Mobile Runtime ABI v1 supports one active iOS scene. Every managed `Info.plist`
sets `UIApplicationSupportsMultipleScenes` to false, and the Swift scene lease
returns `-1001` if a second concurrent scene is nevertheless requested. Surface
detach preserves the application session for background/foreground and view
recreation; `destroy_application` is process-terminal and is called separately.

The canonical shell accepts app-owned configuration through `mobile.json` and
source-based `moui.plugin.json` manifests. Shell API v1 plugins may register
native PlatformView factories and named Host Service channel handlers. The
resolver compiles declared Swift/Objective-C++ sources, copies declared
resources, rejects reserved `moui.*` names, and keeps package managers, build
scripts, frameworks, and prebuilt native libraries out of the managed route.

An app that needs custom Xcode build phases, binary frameworks, entitlements
outside the managed manifest, or a different scene architecture must eject by
owning its native project and shell. The stable boundary after eject is
`moui_mobile_runtime_v1.h`; the application must retain ABI compatibility,
length-driven data ownership, session-generation checks, and detach/destroy
separation. `--legacy-uikit-shell` is a compatibility fixture, not an eject
workflow.

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

The 2026-07-14 local iPhone 17 Pro Simulator Component Gallery smoke for the
Release N UIKit shell is schema-valid **`status=passed`** at
`artifacts/mobile-runtime/ios/component_gallery/mobile-runtime-smoke.json`
(validated with `--require-passed`).

It records lifecycle attach/detach, nonblank first frame, resize, representative
input + scroll, IME, clipboard write/read, accessibility tree/focus/action,
async-image loading/ready, clean shutdown, and Metal GPU configure
(`SkiaGpuNative` / `metal-gpu` / `gpuPromoted=true`) with a **pending** seven-gate
skeleton (`gpuPromotionEvidence.claimed=false`). Simulator `realDeviceSigning`
stays `pending`.

That artifact remains historical evidence for the legacy shell. It cannot be
used to promote the canonical SwiftUI shell. Re-run the same recorder against a
non-fallback managed build and collect real interactions externally. Production
Swift and Objective-C++ shell sources intentionally contain no environment-
driven accessibility or service smoke probe.

Recorder behavior that remains relevant:

- continuous `log stream` (so attach/IME/clipboard are not drowned by scroll)
- service-probe-first idb planning
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

- SwiftUI scene lifecycle attaching/detaching one `IosRuntimeSession`, with a
  separate terminal application destroy.
- The managed `CAMetalLayer`-backed `UIView` presenting nonblank first-frame
  pixels without its PlatformView overlay swallowing MoUI input.
- Resize and touch callbacks reaching `HostRuntimeDriver`.
- Text input/IME observations or explicit pending status.
- Clipboard, accessibility, async image, real-device signing, and packaging
  observations or explicit pending status.

Until those observations exist, describe iOS as an experimental embedded
scaffold, not as a passed platform.
