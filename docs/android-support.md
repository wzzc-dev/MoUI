# Android Support

Android uses the **embedded runtime backend** route and is currently
**experimental** (product_class `experimental`, `ready=false`): the code paths
compile and host-sim tests pass, but no development/demonstration usability or
product commitment is made without matching-device evidence. `wzzc-dev/window/android` owns the Android lifecycle,
surface, and input queue; `moui/backend/android` converts those callbacks into
the MoUI runtime session, exposes neutral CPU/GPU surface capabilities, and
owns the platform presenter. The entrypoint supplies `moui_skia_renderer`
providers with an explicit Android platform policy; the backend has no Skia
dependency.

## Entry Points

| Piece | Location |
|---|---|
| App logic | `examples/<app>/app` |
| Mobile metadata | `examples/<app>/moui.mobile.json` |
| MoonBit entrypoint | `examples/<app>/android_window_hosted` |
| Android host template | `wzzc-dev/window/android/template` |
| MoUI embedded runtime backend | `moui/backend/android/window_hosted.mbt` |

The entrypoint constructs `AndroidEmbeddedRuntimeBackend` and runs it through
`window/android::EventLoop`. Do not add another lifecycle, surface, or input
bridge beside the window event loop.

Android status-bar layout is an application-owned host option. It defaults to
the normal inset layout; set `status_bar_immersive=true` to draw the MoUI
surface edge-to-edge behind the visible status bar. The option does not hide
the status bar or navigation bar:

```moonbit
.backend(
  @android_host.entry(
    options=@android_host.AndroidHostAppOptions::new(
      status_bar_immersive=true,
    ),
  ),
)
```

## Toolchain

- JDK 17 or newer (JDK 21 recommended)
- Android SDK compile API 36 and target API 35
- NDK `28.2.13676358` and CMake `3.22.1`
- Gradle `9.6.1` or compatible wrapper
- Application minimum SDK 23

## SDK, NDK, And Emulator Setup

Use a full JDK installation. Set the SDK root to the location chosen on the
local machine; the repository does not require a machine-specific path.

```sh
export JAVA_HOME=/path/to/full-jdk
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

scripts/setup-android-sdk.sh --accept-licenses --ndk 28.2.13676358
eval "$(scripts/setup-android-sdk.sh --print-env)"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

The helper installs platform tools, API 36, Build-Tools 35.0.0, CMake 3.22.1,
and the pinned NDK. It does not install an emulator image. On Apple Silicon use
an `arm64-v8a` image; on x86_64 hosts use the matching `x86_64` image.

```sh
sdkmanager --install \
  "emulator" \
  "system-images;android-34;google_apis;arm64-v8a"
echo no | avdmanager create avd \
  -n moui_api34 \
  -k "system-images;android-34;google_apis;arm64-v8a" \
  -d pixel_6 \
  --force

emulator -avd moui_api34 -gpu host -no-snapshot-save &
adb wait-for-device
adb shell getprop sys.boot_completed
```

Run `moui doctor --platform android` before a native build.

## Build And Run

From the repository root:

```sh
moon check examples/showcase/android_window_hosted --target native
moui build android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui run android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```

Use `--prepare-only` to inspect generated native inputs without invoking
Gradle. `--fallback-skia` verifies packaging only; it does not establish
renderer or runtime support.

## Validation And Evidence

Host-sim validation does not require an emulator:

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/android --target native
```

For a runtime claim, use a matching device or emulator and record first frame,
input, surface detach/recreate, IME, clipboard, accessibility, and async-image
observations. Keep `checks/platforms/android.json` at `partial` until that
evidence verifies the actual presenter route.

## Matching-Emulator Evidence (2026-11-07)

A matching-emulator pass was recorded on `emulator-5554` (Pixel 6 AVD
`moui_api34`, API 34, arm64) with a debug APK built from HEAD via
`moui build android showcase --mobile-config examples/showcase/moui.mobile.json`
(Gradle 9.6.1 / AGP 9.2.1; set `local.properties` `sdk.dir` or export
`ANDROID_HOME` for the Gradle step). Screenshots:
`artifacts/android/emulator-evidence/`.

Observed: first frame (HostedActivity displayed 1.374s, Skia-rendered probe
UI), pointer (tap focused the probe field; tap activated the probe button —
Action count 0 -> 1, "Last: Probe action 1"), resize/rotation (landscape
responsive two-column reflow with the route header, no ghosting; portrait
restored), surface detach/recreate (force-stop + relaunch into a fresh
`MoUIWindow` init in a new process), and the app-visible viewport (411 x 914
reported by the probe).

The keyboard/IME text channel was fixed the same day (2026-11-07): the
window-hosted template now provides an `InputConnection` (IME commits and
deletions forwarded to the native `KeyboardText`/`KeyboardKey` channels) and
`dispatchKeyEvent` routes named keys (Backspace/Delete/Enter/arrows). The
evidence pass verified insert ("abc" at the caret), delete (Backspace), and
submit (Enter -> "Last: Probe submit 1") through the runtime.

Still pending for `committed`:

- Clipboard write and read: the Host services page reports "Unavailable:
  clipboard write is unavailable" and "Unavailable: clipboard read is
  unavailable" — the window embedder's clipboard platform-channel service is
  unwired in `wzzc-dev/window/android`.
- Accessibility node publishing: the window embedder's a11y adaptation is
  declared but uiautomator showed no text nodes from the MoUI surface.

The earlier "root layout resize" suspicion was a misdiagnosis, resolved on
2026-11-08 by measured card-border evidence: the resize chain works (the
runtime rebuilds at 411x914 and the probe reports that viewport). The
narrow-content appearance came from the Showcase platform `view_body`
ignoring the shell's content width, so page columns fell back to their
intrinsic width (~292 logical) instead of the 375-wide detail column.
Fixed by pinning the matched page with `.frame(width=width)` (probe card
border now 24..399 logical, full content width).

These are the remaining R6 capabilities blocking the `committed` promotion.
The keyboard/IME text channel was fixed and verified the same day (see
above).

## Status

The route is usable for development and template integration, and now carries
matching-emulator runtime evidence for pixels, pointer, resize, viewport, and
surface lifecycle, but it is not a product-complete Android claim: keyboard
text, clipboard, accessibility, and async-image evidence are still open. See
`docs/platform-readiness-declaration.md` and `docs/window-hosted-moui.md` for
the evidence boundary.
