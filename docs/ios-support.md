# iOS Support

iOS uses the **embedded runtime backend** route and is currently
**experimental** (product_class `experimental`, `ready=false`): the code paths
compile and host-sim tests pass, but no development/demonstration usability or
product commitment is made without matching-simulator/device evidence. `wzzc-dev/window/ios` owns UIKit lifecycle, surface, and
input callbacks; `moui/backend/ios` assembles the MoUI runtime session and
exposes the neutral UIKit/Metal presenter surface. The entrypoint supplies
`moui_skia_renderer` providers with an explicit iOS platform policy; the
backend has no Skia dependency.

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

## Simulator Build (2026-11-07, unblocked)

`moui build ios showcase --sdk iphonesimulator` now builds and links a
runnable simulator .app end to end. Two repairs landed the same day:

1. `moui_cli/build_ios.mbt` prefers the 0.10.20 toolchain's split runtime
   (`lib/runtime/*.c`, one object per subsystem) over the removed
   `lib/runtime.c` and compiles every split source for the iOS target.
2. `moui/backend/ios/runtime_compat/` provides simulator SDK shims for the
   four runtime sources whose `__MACH__` branches assume the full macOS
   SDK: `sys/vnode.h` (file-type enum; the Simulator SDK omits the header
   but `sys/attr.h` types cover it), `sys/random.h` (getentropy declaration;
   the symbol exists in libSystem), and a posix_spawn addchdir remap to an
   ENOSYS stub (Apple marks the API unavailable on iOS; the hosted apps
   never spawn with a cwd).

The shim is applied only to the Moon runtime sources compiled by
`moui build ios` via `-I` + `-include` — the same pattern the Android
CMakeLists uses with `mbw_android_compat.h`. A moonbitlang/runtime upstream
port of the four sources remains the clean long-term fix; the shim is the
MoUI-side unblock.

The built .app installs, launches, and renders the Mobile Service Probe on
the iPhone 17 simulator (iOS 26.3) — real Skia pixels, viewport 402 x 874,
async image rendered.

## Matching-simulator evidence (2026-11-08, idb pass)

With `idb` installed (CLI + `idb_companion`), the pointer/IME flows are
drivable from the host, and the clipboard channel landed the same day:

- **Build trap (mandatory flag)**: `moui build ios` without
  `--sdk iphonesimulator` silently links a **device-platform** binary
  (`LC_BUILD_VERSION platform=IOS`). The simulator's SpringBoard rejects it
  with "not valid application" / launch error 163 ("Security policy issue").
  The recorded matrixCommand pins the flag.
- **Template plist**: the packaged .app was rejected until `UIDeviceFamily`
  (iPhone), `CFBundleInfoDictionaryVersion 6.0`, and landscape orientations
  were added to the template `Info.plist` (window `moui-support` `a0ee0ff`).
- **Pointer**: `idb ui tap` on "Activate service probe" -> Action count
  0 -> 1.
- **IME text + delete**: `idb ui text` inserts at the caret through the
  hidden-UITextView diff adapter (`mobile-servicea-probebc-probe`);
  `idb ui key 42` backspaces shorten it.
- **Clipboard write + read** (`aedd44897`): Host services write -> "Last:
  Clipboard written"; host-side `simctl pbpaste` prints
  "showcase-platform ticks=0"; read -> "Last: Clipboard read:
  showcase-platform ticks=0" through the general UIPasteboard bridge
  (`moui/backend/ios/ios_clipboard.{mm,mbt}` + `app_environment()`
  ClipboardServices + `service_handler`).
- **Surface detach/recreate**: terminate + relaunch -> fresh probe session.
- **Cross-extent**: the same .app installs and runs on the iPad simulator.

Still pending for `committed` (mirrors `checks/platforms/ios.json`):

- Live rotation/resize automation — the Simulator "Device > Rotate" menu is
  not scriptable from this host's accessibility stack; the template now
  declares landscape orientations, so a scriptable rotation completes the
  live-resize observation.
- Named-key channel — hardware Enter/submit/arrows are not routed (the iOS
  template forwards only IME text diffs); the probe submit count cannot be
  driven by keyboard yet.
- Accessibility node publishing — no UIAccessibility element bridge yet
  (the Android route's AccessibilityNodeProvider bridge is the pattern).
- Metal direct-present log marker (rendererL2 stays `partial`).

## Status

The route compiles and is usable for template integration, and now carries
matching-simulator evidence for pixels, pointer, IME text + delete,
clipboard write/read, surface lifecycle, and cross-extent install, but it
remains **experimental** (product_class `experimental`, `ready=false`) until
the pending list above closes. See
`docs/platform-readiness-declaration.md` and
`docs/window-hosted-moui.md` for the promotion criteria.
