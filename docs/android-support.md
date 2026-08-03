# Android Support

Android uses the **embedded runtime backend** route and is currently
**experimental** (product_class `experimental`, `ready=false`): the code paths
compile and host-sim tests pass, but no development/demonstration usability or
product commitment is made without matching-device evidence. `wzzc-dev/window/android` owns the Android lifecycle,
surface, and input queue; `moui/backend/android` converts those callbacks into
the MoUI runtime session, exposes neutral CPU/GPU surface capabilities, and
owns the platform presenter. The entrypoint supplies `moui/render/skia`
factories; the backend has no Skia dependency.

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

## Status

The route is usable for development and template integration, but it is not a
product-complete Android claim. See `docs/platform-readiness-declaration.md`
and `docs/window-hosted-moui.md` for the evidence boundary.
